package handlers

import (
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// ========= Member DTOs (responses) =========
type UserMini struct {
	ID       string `json:"id"`
	Username string `json:"username"`
}

type Invite struct {
	ID        string `json:"id"`
	ProjectID string `json:"project_id"`
	InviterID string `json:"inviter_id"`
	InviteeID string `json:"invitee_id"`
	RoleKey   string `json:"role_key"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
}

// InviteWithUsers is returned for project invite lists (so the UI can show usernames).
type InviteWithUsers struct {
	ID              string `json:"id"`
	ProjectID       string `json:"project_id"`
	InviterID       string `json:"inviter_id"`
	InviterUsername string `json:"inviter_username"`
	InviteeID       string `json:"invitee_id"`
	InviteeUsername string `json:"invitee_username"`
	RoleKey         string `json:"role_key"`
	Status          string `json:"status"`
	CreatedAt       string `json:"created_at"`
}

type MyInvitations struct {
	ID          string `json:"id"`
	ProjectName string `json:"project_name"`
	InviterID   string `json:"inviter_id"`
	InviterName string `json:"inviter_name"`
	RoleKey     string `json:"role_key"`
	CreatedAt   string `json:"created_at"`
}

// ProjectInvitesResponse groups invites for the project.
type ProjectInvitesResponse struct {
	Pending  []InviteWithUsers `json:"pending"`
	Declined []InviteWithUsers `json:"declined"`
	Accepted []InviteWithUsers `json:"accepted"`
}

// ========= Requests =========
type createInviteReq struct {
	Username string `json:"username"`
	RoleKey  string `json:"role_key"`
}

func (h *Handler) SearchUsers(c *gin.Context) {
	q := strings.TrimSpace(c.Query("q"))
	if len(q) < 2 {
		c.JSON(http.StatusOK, []UserMini{})
		return
	}

	myID, ok := getAuthUID(c)
	if !ok {
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	rows, err := h.DB.Query(ctx, `
        select id::text, username
        from users
        where lower(username) like lower($1)
			and id::text <> $2
        order by lower(username)
        limit 10
    `, "%"+q+"%", myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer rows.Close()

	out := make([]UserMini, 0, 10)
	for rows.Next() {
		var u UserMini
		if err := rows.Scan(&u.ID, &u.Username); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		out = append(out, u)
	}
	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) CreateProjectInvite(c *gin.Context) {
	var req createInviteReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	projectID := strings.ToLower(strings.TrimSpace(c.Param("projectId")))
	username := strings.TrimSpace(req.Username)
	roleKey := strings.TrimSpace(req.RoleKey)
	if roleKey == "" {
		roleKey = "member"
	}

	if projectID == "" || username == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing fields"})
		return
	}

	inviterID, ok := getAuthUID(c)
	if !ok {
		return
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	// 1) Find invitee user id
	var inviteeID string
	err := h.DB.QueryRow(ctx, `
        select id::text
        from users
        where lower(username) = lower($1)
    `, username).Scan(&inviteeID)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}

		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if inviteeID == inviterID {
		c.JSON(http.StatusBadRequest, gin.H{"error": "cannot invite yourself"})
		return
	}

	// 2) Check inviter is member
	var allowed bool
	err = h.DB.QueryRow(ctx, `
        select exists(
            select 1 from projects_members where project_id::text = $1 and user_id::text = $2
        )
    `, projectID, inviterID).Scan(&allowed)
	if err != nil || !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "not allowed"})
		return
	}

	// 3) Check invitee already a member
	var isMember bool
	err = h.DB.QueryRow(ctx, `
        select exists(
            select 1 from projects_members
            where project_id::text = $1 and user_id::text = $2
        )
    `, projectID, inviteeID).Scan(&isMember)

	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			c.JSON(http.StatusConflict, gin.H{"error": "invite already exists"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	// 4) Create invite (unique (project_id, invitee_id) prevents duplicates)
	var out Invite
	var createdAt time.Time
	err = h.DB.QueryRow(ctx, `
        insert into project_invites (project_id, inviter_id, invitee_id, role_key, status)
        values ($1::uuid, $2::uuid, $3::uuid, $4, 'pending')
        returning
			id::text, project_id::text, inviter_id::text, invitee_id::text,
			role_key, status::text, created_at
    `, projectID, inviterID, inviteeID, roleKey).Scan(
		&out.ID, &out.ProjectID, &out.InviterID, &out.InviteeID,
		&out.RoleKey, &out.Status, &createdAt,
	)

	if err != nil {
		// most likely unique violation
		c.JSON(http.StatusConflict, gin.H{"error": "invite already exists"})
		return
	}

	out.CreatedAt = createdAt.UTC().Format(time.RFC3339)
	c.JSON(http.StatusOK, out)
}

func (h *Handler) ListProjectInvites(c *gin.Context) {
	// Accept project id from path OR query (for backward compatibility)
	projectID := strings.ToLower(strings.TrimSpace(c.Param("projectId")))
	if projectID == "" {
		projectID = strings.ToLower(strings.TrimSpace(c.Query("projectId")))
	}
	if projectID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing project id"})
		return
	}

	uID, ok := getAuthUID(c)
	if !ok {
		return
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	// Only project members can view invites.
	var allowed bool
	if err := h.DB.QueryRow(ctx, `
        select exists(
            select 1 from projects_members
            where project_id::text = $1 and user_id::text = $2
        )
    `, projectID, uID).Scan(&allowed); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	if !allowed {
		c.JSON(http.StatusForbidden, gin.H{"error": "not allowed"})
		return
	}

	// Pull invites + usernames for UI display.
	rows, err := h.DB.Query(ctx, `
        select
			pi.id::text,
            pi.project_id::text,
            pi.inviter_id::text,
            inv.username as inviter_username,
            pi.invitee_id::text,
            ine.username as invitee_username,
            pi.role_key,
            pi.status::text,
            pi.created_at
        from project_invites pi
		join users inv on inv.id = pi.inviter_id
        join users ine on ine.id = pi.invitee_id
        where pi.project_id::text = $1
        order by pi.created_at desc
        limit 50
    `, projectID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer rows.Close()

	resp := ProjectInvitesResponse{
		Pending:  []InviteWithUsers{},
		Declined: []InviteWithUsers{},
		Accepted: []InviteWithUsers{},
	}

	for rows.Next() {
		var r InviteWithUsers
		var createdAt time.Time
		if err := rows.Scan(
			&r.ID,
			&r.ProjectID,
			&r.InviterID,
			&r.InviterUsername,
			&r.InviteeID,
			&r.InviteeUsername,
			&r.RoleKey,
			&r.Status,
			&createdAt,
		); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}

		r.CreatedAt = createdAt.UTC().Format(time.RFC3339)

		switch r.Status {
		case "pending":
			resp.Pending = append(resp.Pending, r)
		case "declined":
			resp.Declined = append(resp.Declined, r)
		case "accepted":
			resp.Accepted = append(resp.Accepted, r)
		default:
			continue
		}
	}

	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, resp)
}

func (h *Handler) ListMyInvites(c *gin.Context) {
	myID, ok := getAuthUID(c)
	if !ok {
		return
	}

	status := strings.TrimSpace(c.Query("status"))
	if status == "" {
		status = "pending"
	} else if status != "pending" && status != "accepted" && status != "declined" && status != "cancelled" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid status"})
		return
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	rows, err := h.DB.Query(ctx, `
        select
			pi.id::text,
			p.name as project_name,
			pi.inviter_id::text,
			inv.username as inviter_username,
			pi.role_key,
			pi.created_at::text
        from project_invites pi
		join projects p on p.id = pi.project_id
		join users inv on inv.id = pi.inviter_id
        where pi.invitee_id::text = $1
			and pi.status::text = $2
        order by pi.created_at desc
        limit 50
    `, myID, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer rows.Close()

	out := []MyInvitations{}
	for rows.Next() {
		var r MyInvitations
		if err := rows.Scan(&r.ID, &r.ProjectName, &r.InviterID, &r.InviterName, &r.RoleKey, &r.CreatedAt); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		out = append(out, r)
	}
	if err := rows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	c.JSON(http.StatusOK, out)
}

func (h *Handler) AcceptInvite(c *gin.Context) {
	myID, ok := getAuthUID(c)
	if !ok {
		return
	}

	inviteID := strings.ToLower(strings.TrimSpace(c.Param("inviteId")))
	if inviteID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing invite id"})
		return
	}

	ctx, cancel := contextTimeout(c, 10*time.Second)
	defer cancel()

	tx, err := h.DB.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer tx.Rollback(ctx)

	// lock invite row so accept is idempotent
	var projectID, roleKey, status string
	err = tx.QueryRow(ctx, `
        select project_id::text, role_key, status::text
        from project_invites
        where id::text = $1 and invitee_id::text = $2
        for update
    `, inviteID, myID).Scan(&projectID, &roleKey, &status)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "invite not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		}
		return
	}
	if status != "pending" {
		c.JSON(http.StatusConflict, gin.H{"error": "invite not pending"})
		return
	}

	// insert membership
	// NOTE: use user's username from users table (or join profiles); simplest:
	var username string
	if err := tx.QueryRow(ctx, `select username from users where id::text = $1`, myID).Scan(&username); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	_, err = tx.Exec(ctx, `
        insert into projects_members (project_id, user_id, username, role_key)
        values ($1::uuid, $2::uuid, $3, $4)
        on conflict do nothing
    `, projectID, myID, username, roleKey)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	// delete when invite accepted
	_, err = tx.Exec(ctx, `
        delete from project_invites
        where id::text = $1
    `, inviteID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	// 1) Fetch the project details to return
	var project Project
	if err := h.DB.QueryRow(ctx, `
        select
			p.id::text,
			p.name,
			p.description,
			p.owner_id::text,
			p.is_pinned,
			p.sort_index
		from projects p
		where p.id::text = $1
    `, projectID).Scan(&project.ID, &project.Name, &project.Description, &project.OwnerId,  &project.IsPinned, &project.SortIndex); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	// 2) Fetch all members for the project ID
	memRows, err := h.DB.Query(ctx, `
		select
			pm.user_id::text,
			pm.username,
			pm.role_key
		from projects_members pm
		where pm.project_id::text = $1
		order by lower(pm.username) asc
	`, projectID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer memRows.Close()

	project.Members = []Member{}
	for memRows.Next() {
		var m Member
		if err := memRows.Scan(&m.ID, &m.Username, &m.RoleKey); err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		project.Members = append(project.Members, m)
	}

	// 3) Fetch all tasks for the project ID
	taskRows, err := h.DB.Query(ctx, `
		select
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
		where t.project_id::text = $1
		order by
			case t.status
				when 'backlog' then 1
				when 'inProgress' then 2
				when 'blocked' then 3
				when 'done' then 4
				else 9
			end,
			t.sort_index asc,
			t.created_at asc
	`, projectID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	defer taskRows.Close()

	project.Tasks = []Task{}
	for taskRows.Next() {
		var t Task
		var assigneeID string
		var assigneeUsername string
		var createdAt time.Time

		if err := taskRows.Scan(
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

		if assigneeID != "" {
			t.AssigneeID = &assigneeID
		}
		if assigneeUsername != "" {
			t.AssigneeUsername = &assigneeUsername
		}
		t.CreatedAt = createdAt.UTC().Format(time.RFC3339)

		project.Tasks = append(project.Tasks, t)
	}

	if err := taskRows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if err := memRows.Err(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, project)
}

func (h *Handler) DeclineInvite(c *gin.Context) {
	myID, ok := getAuthUID(c)
	if !ok {
		return
	}

	inviteID := strings.ToLower(strings.TrimSpace(c.Param("inviteId")))
	if inviteID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing invite id"})
		return
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	cmd, err := h.DB.Exec(ctx, `
        update project_invites
        set status = 'declined', responded_at = now()
        where id::text = $1
		and invitee_id::text = $2
		and status = 'pending'
    `, inviteID, myID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "invite not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *Handler) DeleteInvite(c *gin.Context) {
	myID, ok := getAuthUID(c)
	if !ok {
		return
	}

	inviteID := strings.ToLower(strings.TrimSpace(c.Param("inviteId")))
	if inviteID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing invite id"})
		return
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	// Only the inviter can delete, and only after it was declined.
	cmd, err := h.DB.Exec(ctx, `
		delete from project_invites
		where id::text = $1
			and inviter_id::text = $2
	`, inviteID, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "invite not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}
