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
	ID       string `json:"id"`
	Username string `json:"username"`
	RoleKey  string `json:"roleKey"`
}

type Project struct {
	ID          string   `json:"id"`
	Name        string   `json:"name"`
	Description string   `json:"description"`
	OwnerId     string   `json:"owner_id"`
	Members     []Member `json:"members"`
	Tasks       []Task   `json:"tasks"`
	IsPinned    bool     `json:"is_pinned"`
	SortIndex   int      `json:"sort_index"`
}

type EditProjectDetail struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

// ========= Requests =========
type createProjectReq struct {
	Name        string `json:"name"`
	Description string `json:"description"`
}

type editProjectDetailsReq struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
}

type reorderProjectsReq struct {
	ProjectIDs []string `json:"project_ids"`
}

// Helper function to extract and validate user ID from context
func getAuthUID(c *gin.Context) (string, bool) {
	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return "", false
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return "", false
	}
	return userID, true
}

func (h *Handler) GetProjects(c *gin.Context) {
	userID, ok := getAuthUID(c)
	if !ok {
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

	rows, err := h.DB.Query(ctx, `
		select
			p.id::text,
			p.name,
			p.description,
			p.owner_id::text,
			p.is_pinned,
			p.sort_index
		from projects_members pm
		join projects p on p.id = pm.project_id
		where pm.user_id = $1
		order by p.sort_index asc, p.created_at desc, lower(p.name) asc
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
		if err := rows.Scan(&p.ID, &p.Name, &p.Description, &p.OwnerId, &p.IsPinned, &p.SortIndex); err != nil {
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

	ownerID, ok := getAuthUID(c)
	if !ok {
		return
	}

	usrAny, _ := c.Get("usr")
	usr, ok := usrAny.(string)
	if !ok || usr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

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
	var sortIndex int
	if err := h.DB.QueryRow(ctx,
		`insert into projects (name, description, owner_id, sort_index)
		values (
			$1,
			$2,
			$3,
			coalesce((select max(sort_index) + 1 from projects where owner_id = $3), 0)
			)
		returning id::text, sort_index
	`, name, req.Description, ownerID).Scan(&projectID, &sortIndex); err != nil {
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
		ID:          projectID,
		Name:        name,
		Description: req.Description,
		OwnerId:     ownerID,
		Members:     []Member{members},
		Tasks:       []Task{},
		IsPinned:    false,
		SortIndex:   sortIndex,
	})
}

func (h *Handler) EditProjectDetails(c *gin.Context) {
	ownerID, ok := getAuthUID(c)
	if !ok {
		return
	}

	var req editProjectDetailsReq
	if err := c.ShouldBindJSON(&req); err != nil {
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
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (h *Handler) DeleteProject(c *gin.Context) {
	ownerID, ok := getAuthUID(c)
	if !ok {
		return
	}

	id := strings.TrimSpace(c.Param("projectId"))
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
	`, id, ownerID)
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

func (h *Handler) PinProject(c *gin.Context) {
	ownerIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
	}
	ownerID, ok := ownerIDAny.(string)
	if !ok || ownerID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
	}

	id := strings.TrimSpace(c.Param("projectId"))
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}

	pin := strings.TrimSpace(c.Param("pin"))
	if pin == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}
	if pin != "true" && pin != "false" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid pin"})
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
		`update projects 
		set is_pinned = $1::boolean
		where id = $2::uuid and owner_id = $3
	`, pin, id, ownerID)
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

func (h *Handler) ReorderProjects(c *gin.Context) {
	ownerID, ok := getAuthUID(c)
	if !ok {
		return
	}

	var req reorderProjectsReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	if len(req.ProjectIDs) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing project_ids"})
		return
	}

	// Normalize + validate IDs (no empty strings)
	ids := make([]string, 0, len(req.ProjectIDs))
	seen := make(map[string]struct{}, len(req.ProjectIDs))
	for _, raw := range req.ProjectIDs {
		id := strings.ToLower(strings.TrimSpace(raw))
		if id == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid project id"})
			return
		}
		if _, exists := seen[id]; exists {
			continue
		}
		seen[id] = struct{}{}
		ids = append(ids, id)
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer tx.Rollback(ctx)

	// Ensure all provided projects belong to this owner
	var count int
	if err := tx.QueryRow(ctx,
		`select count(*) 
		from projects 
		where owner_id = $1::uuid 
			and id::text = any($2)
		`, ownerID, ids,
	).Scan(&count); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if count != len(ids) {
		c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
		return
	}

	// Update sort_index based on the provided order
	cmd, err := tx.Exec(ctx, `
        with ord(pid, ord) as (
			select * from unnest($1::uuid[]) with ordinality
        )
        update projects p
        set sort_index = (ord.ord - 1)
        from ord
        where p.id = ord.pid
			and p.owner_id = $2::uuid
    `, ids, ownerID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if int(cmd.RowsAffected()) != len(ids) {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}
