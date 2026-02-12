package handlers

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
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

	projectIDStr := strings.TrimSpace(c.Param("projectId"))
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

	projectIDStr := strings.TrimSpace(c.Param("projectId"))
	taskIDStr := strings.TrimSpace(c.Param("taskId"))
	if projectIDStr == "" || taskIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing project or task id"})
		return
	}

	projectUUID, err := uuid.Parse(strings.ToLower(projectIDStr))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid project id"})
		return
	}
	taskUUID, err := uuid.Parse(strings.ToLower(taskIDStr))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid task id"})
		return
	}

	var req updateTaskReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

    // sortIndex is ALWAYS required (all edit modes provide it)
	if req.SortIndex == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing sort_index"})
		return
	}

	if *req.SortIndex < 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid sort_index"})
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

	// Must be a project member
	var allowed bool
	if err := h.DB.QueryRow(ctx, `
		select exists (
			select 1
			from projects_members
			where project_id = $1
			and user_id::text = $2
		)
	`, projectUUID, uid).Scan(&allowed); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a project member"})
		return
	}

	// Fetch current status + sort_index (needed for stable reindexing)
	var oldStatus string
	var oldIndex int
	if err := h.DB.QueryRow(ctx, `
		select status, sort_index
		from tasks
		where project_id = $1 and id = $2
	`, projectUUID, taskUUID).Scan(&oldStatus, &oldIndex); err != nil {
		if err == pgx.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "task not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	newStatus := oldStatus
	if req.Status != nil {
		newStatus = *req.Status
	}
	newIndex := *req.SortIndex


	// Normalize fields
	var newDetails *string
	if req.Details != nil {
		d := strings.TrimSpace(*req.Details)
		newDetails = &d
	}
	
	var newDiff *int
	if req.Difficulty != nil { newDiff = req.Difficulty }

    // Assignee behavior:
	// - If field omitted => keep as-is
	// - If provided as "" => set NULL (unassigned)
	// - If provided as uuid string => set that uuid
	assigneeMode := "keep" // keep | null | set
	var assigneeVal any = nil
	if req.AssigneeID != nil {
		v := strings.TrimSpace(*req.AssigneeID)
		if v == "" {
			assigneeMode = "null"
			assigneeVal = nil
		} else {
			assigneeMode = "set"
			assigneeVal = strings.ToLower(v)
		}
	}

	// Reindex + update in a single statement.
	// This keeps sort_index unique within each (project_id, status) bucket.

	var out Task
	var createdAt time.Time
	
	err = h.DB.QueryRow(ctx, `
		with cur as (
			select id, project_id, status as old_status, sort_index as old_index
			from tasks
			where project_id = $1 and id = $2
		),
		move_same as (
			-- Reorder within the same status
			update tasks t
			set sort_index = case
				when (select $4::int) > (select old_index from cur)
					and t.sort_index > (select old_index from cur)
					and t.sort_index <= (select $4::int)
					then t.sort_index - 1
				when (select $4::int) < (select old_index from cur)
					and t.sort_index >= (select $4::int)
					and t.sort_index < (select old_index from cur)
					then t.sort_index + 1
				else t.sort_index
			end
			where t.project_id = $1
				and t.status = (select old_status from cur)
				and t.id <> (select id from cur)
				and (select $3) = (select old_status from cur)
		),
		move_cross_old as (
			-- Close gap in old status when changing status
			update tasks t
			set sort_index = t.sort_index - 1
			where t.project_id = $1
				and t.status = (select old_status from cur)
				and t.sort_index > (select old_index from cur)
				and (select $3) <> (select old_status from cur)
		),
		move_cross_new as (
			-- Make room in new status when changing status
			update tasks t
			set sort_index = t.sort_index + 1
			where t.project_id = $1
				and t.status = (select $3)
				and t.sort_index >= (select $4::int)
				and (select $3) <> (select old_status from cur)
		),
		updated as (
			update tasks
			set
				details = coalesce($5, details),
				status = $3,
				sort_index = $4::int,
				difficulty = coalesce($6, difficulty),
				assignee_id = case
					when $7 = 'keep' then assignee_id
					when $7 = 'null' then null
					else $8::uuid
				end
			where project_id = $1 and id = $2
			returning *
		)
		select
			u.id::text,
			u.project_id::text,
			u.title,
			u.details,
			u.status,
			u.assignee_id::text,
			usr.username,
			u.difficulty,
			u.sort_index,
			u.created_at
		from updated u
		left join users usr on usr.id = u.assignee_id
	`,
		projectUUID,
		taskUUID,
		newStatus,
		newIndex,
		newDetails,
		newDiff,
		assigneeMode,
		assigneeVal,
	).Scan(
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
		if err == pgx.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "task not found"})
			return
		}

		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	out.CreatedAt = createdAt.UTC().Format(time.RFC3339)
	c.JSON(http.StatusOK, out)
}

func (h *Handler) DeleteTask(c *gin.Context) {
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

	projectIDStr := strings.TrimSpace(c.Param("projectId"))
	taskIDStr := strings.TrimSpace(c.Param("taskId"))
	if projectIDStr == "" || taskIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing project or task id"})
		return
	}

	projectUUID, err := uuid.Parse(strings.ToLower(projectIDStr))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid project id"})
		return
	}
	taskUUID, err := uuid.Parse(strings.ToLower(taskIDStr))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid task id"})
		return
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
	`, projectUUID, uid).Scan(&allowed); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "not a project member"})
		return
	}

	tx, err := h.DB.Begin(ctx)
    if err != nil { c.JSON(http.StatusInternalServerError, gin.H{"error":"server error"}); return }
    defer tx.Rollback(ctx)

    // 1) read the task's status + sort_index (and ensure it belongs to project)
    var status string
    var deletedSort int
    err = tx.QueryRow(ctx, `
        select status, sort_index
        from tasks
        where id::text = $1 and project_id::text = $2
    `, taskUUID, projectUUID).Scan(&status, &deletedSort)
    if err != nil {
		if err == pgx.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error":"task not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error":"server error"}); 
		return
    }

    // 2) delete the task
    cmd, err := tx.Exec(ctx, `
        delete from tasks
        where id::text = $1 and project_id::text = $2
    `, taskUUID, projectUUID)
    if err != nil { c.JSON(http.StatusInternalServerError, gin.H{"error":"server error"}); return }
    if cmd.RowsAffected() == 0 {
        c.JSON(http.StatusNotFound, gin.H{"error":"task not found"})
        return
    }

    // 3) close the gap in that column
    _, err = tx.Exec(ctx, `
        update tasks
        set sort_index = sort_index - 1
        where project_id::text = $1
			and status = $2
			and sort_index > $3
    `, projectUUID, status, deletedSort)
    if err != nil { c.JSON(http.StatusInternalServerError, gin.H{"error":"server error"}); return }

    if err := tx.Commit(ctx); err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error":"server error"}); return
    }

    c.JSON(http.StatusOK, gin.H{"ok": true, "status": status})
}

func isValidTaskStatus(s string) bool {
	switch s {
	case "backlog", "inProgress", "blocked", "done":
		return true
	default:
		return false
	}
}