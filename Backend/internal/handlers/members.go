package handlers

import (
	"database/sql"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

// ========= Requests =========
type updateMemberRole struct {
	RoleKey string `json:"role_key"`
}

func (h *Handler) UpdateMemberRole(c *gin.Context) {
	_, ok := getAuthUID(c)
	if !ok {
		return
	}

	var req updateMemberRole
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request body"})
		return
	}

	req.RoleKey = strings.TrimSpace(req.RoleKey)
	if req.RoleKey == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "role_key is required"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	projectId := strings.TrimSpace(c.Param("projectId"))
	if projectId == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing project id"})
		return
	}

	memberId := strings.TrimSpace(c.Param("memberId"))
	if memberId == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing user id"})
		return
	}

	cmd, err := h.DB.Exec(ctx,
		`update projects_members
			set role_key = $1
			where project_id = $2 and
			user_id = $3
		`, req.RoleKey, projectId, memberId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "member not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *Handler) DeleteMember(c *gin.Context) {
	myID, ok := getAuthUID(c)
	if !ok {
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	projectId := strings.TrimSpace(c.Param("projectId"))
	if projectId == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing project id"})
		return
	}

	memberId := strings.TrimSpace(c.Param("memberId"))
	if memberId == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing user id"})
		return
	}

	// Check if myID matches the owner_id of the project
	var ownerID string
	err := h.DB.QueryRow(ctx, `
		SELECT owner_id FROM projects WHERE id = $1
	`, projectId).Scan(&ownerID)
	if err != nil {
		if err == sql.ErrNoRows {
			c.JSON(http.StatusNotFound, gin.H{"error": "project not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if myID != ownerID {
		c.JSON(http.StatusForbidden, gin.H{"error": "member not owner of the project"})
		return
	}

	cmd, err := h.DB.Exec(ctx,
		`delete from projects_members
			where project_id = $1 and
			user_id = $2
		`, projectId, memberId)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "member not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}
