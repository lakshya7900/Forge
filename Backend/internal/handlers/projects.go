package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// ========= Project DTOs (responses) =========
type Member struct {
	ID string 		`json:"id"`
	Username string `json:"username"`
	RoleKey string 	`json:"roleKey"`
}

type Project struct {
    ID string 				`json:"id"`
    Name string 			`json:"name"`
    Description string 		`json:"description"`
	OwnerId string 			`json:"owner_id"`
	Members []Member 		`json:"members"`
	Tasks []Task 			`json:"tasks"`
}

type EditProjectDetail struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

// ========= Requests =========
type createProjectReq struct {
    Name string 		`json:"name"`
	Description string	`json:"description"`
}

type editProjectDetailsReq struct {
	ID string 			`json:"id"`
	Name string 		`json:"name"`
	Description string	`json:"description"`
}

func (h *Handler) GetProjects(c *gin.Context) {
	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer tx.Rollback(ctx)

	rows, err := h.DB.Query(ctx, `
		select
			p.id::text,
			p.name,
			p.description,
			p.owner_id::text
		from projects_members pm
		join projects p on p.id = pm.project_id
		where pm.user_id = $1
		order by p.created_at desc, lower(p.name) asc
	`, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer rows.Close()

	projects := make([]Project, 0)
	projectIDs := make([]string, 0)

	for rows.Next() {
		var p Project
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.OwnerId); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		p.Members = []Member{}
		projects = append(projects, p)
		projectIDs = append(projectIDs, p.ID)
	}

	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	// No projects -> return empty list
	if len(projectIDs) == 0 {
		c.JSON(http.StatusOK, gin.H{"projects": projects})
		return
	}

	// 2) Fetch all members for those project IDs
	// We'll use ANY($1) with text[] and compare to project_id::text
	memRows, err := h.DB.Query(ctx, `
		select
			pm.project_id::text,
			pm.user_id::text,
			pm.username,
			pm.rolekey
		from projects_members pm
		where pm.project_id::text = any($1)
		order by lower(pm.username) asc
	`, projectIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer memRows.Close()

	// Build map projectID -> []members
	memberMap := make(map[string][]Member, len(projectIDs))

	for memRows.Next() {
		var pid string
		var m Member
		if err := memRows.Scan(&pid, &m.ID, &m.Username, &m.RoleKey); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		memberMap[pid] = append(memberMap[pid], m)
	}

	if err := memRows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	// Attach members to each project
	for i := range projects {
		projects[i].Members = memberMap[projects[i].ID]
	}

	// 3) Fetch all tasks for those project IDs
	taskRows, err := h.DB.Query(ctx, `
		select
			t.project_id::text,
			t.id::text,
			t.title,
			coalesce(t.details, ''),
			t.status,
			coalesce(t.assignee_id::text, ''),
			coalesce(u.username, ''),
			t.difficulty,
			t.sort_index,
			t.created_at
		from tasks t
		left join users u on u.id = t.assignee_id
		where t.project_id::text = any($1)
		order by
			t.project_id::text asc,
			case t.status
				when 'backlog' then 1
				when 'inProgress' then 2
				when 'blocked' then 3
				when 'done' then 4
				else 9
			end,
			t.sort_index asc,
			t.created_at asc
	`, projectIDs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer taskRows.Close()

	// projectID -> []Task
	taskMap := make(map[string][]Task, len(projectIDs))

	for taskRows.Next() {
		var pid string
		var t Task
		var assigneeID string
		var assigneeUsername string
		var createdAt time.Time

		if err := taskRows.Scan(
			&pid,
			&t.ID,
			&t.Title,
			&t.Details,
			&t.Status,
			&assigneeID,
			&assigneeUsername,
			&t.Difficulty,
			&t.SortIndex,
			&createdAt,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}

		t.ProjectID = pid
		if assigneeID != "" {
			t.AssigneeID = &assigneeID
		}
		if assigneeUsername != "" {
			t.AssigneeUsername = &assigneeUsername
		}
		t.CreatedAt = createdAt.UTC().Format(time.RFC3339)

		taskMap[pid] = append(taskMap[pid], t)
	}

	if err := taskRows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	// Attach tasks to each project
	for i := range projects {
		projects[i].Tasks = taskMap[projects[i].ID]
		if projects[i].Tasks == nil {
			projects[i].Tasks = []Task{}
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, projects)
}

func (h *Handler) CreateProject(c *gin.Context) {
	var req createProjectReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	ownerIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	ownerID, ok := ownerIDAny.(string)
	if !ok || ownerID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}
	
	usrAny, _ := c.Get("usr")
	usr := usrAny.(string)

	name := strings.TrimSpace(req.Name)
	if name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing name"})
		return
	}

	// description := strings.TrimSpace(req.Description)
	// if description == "" {
	// 	c.JSON(http.StatusBadRequest, gin.H{"error": "missing description"})
	// 	return
	// }

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer tx.Rollback(ctx)

	var projectID string
	if err := h.DB.QueryRow(ctx,
		`insert into projects (name, description, owner_id)
		values ($1, $2, $3)
		returning id::text
	`, name, req.Description, ownerID).Scan(&projectID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	var members Member
	if err := h.DB.QueryRow(ctx,
		`insert into projects_members (project_id, user_id, username, roleKey)
		values ($1, $2, $3, $4)
		returning user_id::text, username, roleKey
	`, projectID, ownerID, usr, "frontend").Scan(&members.ID, &members.Username, &members.RoleKey); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, Project{
		ID: projectID,
		Name: name,
		Description: req.Description,
		OwnerId: ownerID,
		Members: []Member{members},
	})
}

func (h *Handler) EditProjectDetails(c *gin.Context) {
	ownerIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	ownerID, ok := ownerIDAny.(string)
	if !ok || ownerID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	var req editProjectDetailsReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fmt.Print(err)
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	id := strings.TrimSpace(req.ID)
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}

	name := strings.TrimSpace(req.Name)
	if name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing name"})
		return
	}

	description := strings.TrimSpace(req.Description)
	
	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		fmt.Print(err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer tx.Rollback(ctx)

	var updated EditProjectDetail
	if err := h.DB.QueryRow(ctx,
		`update projects 
		set name = $1, 
		description = $2
		where id = $3::uuid 
		and owner_id = $4
		returning id::text, name, description
	`, name, description, id, ownerID).Scan(&updated.ID, &updated.Name, &updated.Description); err != nil {
		if err == pgx.ErrNoRows {
			fmt.Print(err)
			c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
			return
		}
		fmt.Print(err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (h *Handler) DeleteProject(c *gin.Context) {
	ownerIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
	}
	ownerID, ok := ownerIDAny.(string)
	if !ok || ownerID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
	}

	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer tx.Rollback(ctx)

	cmd, err := h.DB.Exec(ctx,
		`delete from projects 
		where id = $1::uuid and owner_id = $2
	`, id, ownerID,)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})

}