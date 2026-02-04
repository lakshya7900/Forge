package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ========= Task DTOs (responses) =========
type Task struct {
	ID string					`json:"id"`
	ProjectID string			`json:"project_id"`
	Title string				`json:"title"`
	Details string				`json:"details"`
	Status string				`json:"status"`
	AssigneeID *string			`json:"assignee_id"`
	AssigneeUsername *string	`json:"assignee_username"`
	Difficulty int				`json:"difficulty"`
	SortIndex int				`json:"sort_index"`
	CreatedAt string			`json:"created_at"`
}

// ========= Requests =========
type createTaskReq struct {
	Title string		`json:"title"`
	Details string		`json:"details"`
	Status string		`json:"status"`
	AssigneeID *string	`json:"assignee_id"`
	Difficulty int		`json:"difficulty"`
	SortIndex *int		`json:"sort_index"`
}

type updateTaskReq struct {
    Details    *string `json:"details"`
    Status     *string `json:"status"`
    AssigneeID *string `json:"assignee_id"`
    Difficulty *int    `json:"difficulty"`
    SortIndex  *int    `json:"sort_index"`
}

func (h *Handler) AddTask(c *gin.Context) {
	uidAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	uid, ok := uidAny.(string)
	if !ok || uid == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	projectIDStr := strings.TrimSpace(c.Param("id"))
	projectID, projIdErr := uuid.Parse(projectIDStr)
	if projIdErr != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid project id"})
		return
	}

	var req createTaskReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	title := strings.TrimSpace(req.Title)
	if title == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing title"})
		return
	}

	details := strings.TrimSpace(req.Details)

	status := strings.TrimSpace(req.Status)
	if status == "" {
		status = "backlog"
	}
	if !isValidTaskStatus(status) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid status"})
		return
	}

	diff := req.Difficulty
	if diff == 0 {
		diff = 2
	}
	if diff < 1 || diff > 5 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid difficulty"})
		return
	}

	// Normalize assignee: treat missing/blank as NULL (unassigned)
	var assignee any = nil
	if req.AssigneeID != nil {
		a := strings.TrimSpace(*req.AssigneeID)
		if a != "" {
			assignee = a // UUID string; postgres will cast to uuid
		}
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	var allowed bool
	if err := h.DB.QueryRow(ctx, `
		select exists (
			select 1
			from projects_members
			where project_id = $1
			and user_id::text = $2
		)
	`, projectID, uid).Scan(&allowed); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a project member"})
		return
	}

	var out Task
	var createdAt time.Time

	var sortIndex *int
	if req.SortIndex != nil {
		si := *req.SortIndex
		if si < 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid sort_index"})
			return
		}
		sortIndex = &si
	}


	err := h.DB.QueryRow(ctx, `
	with desired as (
		select coalesce(
			$7::int,
			(select coalesce(max(sort_index), -1) + 1
			from tasks
			where project_id = $1 and status = $4)
		) as idx
	), shifted as (
		update tasks
		set sort_index = sort_index + 1
		where project_id = $1
			and status = $4
			and $7::int is not null
			and sort_index >= (select idx from desired)
	), inserted as (
		insert into tasks (project_id, title, details, status, assignee_id, difficulty, sort_index)
		values ($1, $2, $3, $4, $5, $6, (select idx from desired))
		returning *
	)
	select inserted.id::text,
		inserted.project_id::text,
		inserted.title,
		inserted.details,
		inserted.status,
		inserted.assignee_id::text,
		u.username,
		inserted.difficulty,
		inserted.sort_index,
		inserted.created_at
	from inserted
	left join users u on u.id = inserted.assignee_id
	`, projectID, title, details, status, assignee, diff, sortIndex).
	Scan(
		&out.ID,
		&out.ProjectID,
		&out.Title,
		&out.Details,
		&out.Status,
		&out.AssigneeID,
		&out.AssigneeUsername,
		&out.Difficulty,
		&out.SortIndex,
		&createdAt,
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	out.CreatedAt = createdAt.UTC().Format(time.RFC3339)
	c.JSON(http.StatusOK, out)
}

func (h *Handler) UpdateTask(c *gin.Context) {
	uidAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	uid, ok := uidAny.(string)
	if !ok || uid == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	projectID := strings.ToLower(strings.TrimSpace(c.Param("projectId")))
	taskID := strings.ToLower(strings.TrimSpace(c.Param("taskId")))
	if projectID == "" || taskID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing ids"})
		return
	}

	var req updateTaskReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

    // Nothing to update?
	if req.Details == nil && req.Status == nil && req.AssigneeID == nil && req.Difficulty == nil && req.SortIndex == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "no fields to update"})
		return
	}

    // Validate difficulty if provided
	if req.Difficulty != nil {
		if *req.Difficulty < 1 || *req.Difficulty > 5 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid difficulty"})
			return
		}
	}

    // Validate status if provided
	if req.Status != nil {
		s := strings.TrimSpace(*req.Status)
		if !isValidTaskStatus(s) {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid status"})
			return
		}
		*req.Status = s
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	var allowed bool
	if err := h.DB.QueryRow(ctx, `
		select exists (
			select 1
			from projects_members
			where project_id = $1
			and user_id::text = $2
		)
	`, projectID, uid).Scan(&allowed); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a project member"})
		return
	}

	setParts := make([]string, 0, 6)
	args := make([]any, 0, 8)
	i := 1

	if req.Details != nil {
		d := strings.TrimSpace(*req.Details)
		setParts = append(setParts, fmt.Sprintf("details = $%d", i))
		args = append(args, d)
		i++
	}
	if req.Status != nil {
		setParts = append(setParts, fmt.Sprintf("status = $%d", i))
		args = append(args, *req.Status)
		i++
	}
	if req.Difficulty != nil {
		setParts = append(setParts, fmt.Sprintf("difficulty = $%d", i))
		args = append(args, *req.Difficulty)
		i++
	}
	if req.SortIndex != nil {
		setParts = append(setParts, fmt.Sprintf("sort_index = $%d", i))
		args = append(args, *req.SortIndex)
		i++
	}

    // assignee_id: allow null (= unassigned)
    // - If field omitted => don't touch it
    // - If field present null => set NULL
    // - If field present "uuid" => set to that uuid
	if req.AssigneeID != nil {
		v := strings.TrimSpace(*req.AssigneeID)
		if v == "" {
			// treat "" as unassigned too (optional convenience)
			setParts = append(setParts, "assignee_id = NULL")
		} else {
			setParts = append(setParts, fmt.Sprintf("assignee_id = $%d::uuid", i))
			args = append(args, v)
			i++
		}
	}

    // IMPORTANT: ensure the task belongs to that project
    // also you’ll later add membership check here if needed
	args = append(args, projectID)
	args = append(args, taskID)

	q := fmt.Sprintf(`
		update tasks
		set %s
		where project_id = $%d::uuid and id = $%d::uuid
		returning
			id::text,
			title,
			details,
			status,
			assignee_id::text,
			difficulty,
			sort_index,
			created_at
	`, strings.Join(setParts, ", "), i, i+1)

	var out Task
	var createdAt time.Time
	err := h.DB.QueryRow(ctx, q, args...).Scan(
		&out.ID,
		&out.Title,
		&out.Details,
		&out.Status,
		&out.AssigneeID,
		&out.Difficulty,
		&out.SortIndex,
		&createdAt,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	out.CreatedAt = createdAt.UTC().Format(time.RFC3339)
	c.JSON(http.StatusOK, out)
}

func isValidTaskStatus(s string) bool {
	switch s {
	case "backlog", "inProgress", "blocked", "done":
		return true
	default:
		return false
	}
}