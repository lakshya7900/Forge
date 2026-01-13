package handlers

import (
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

func (h *Handler) MeProfile(c *gin.Context) {
	uidAny, _ := c.Get("uid")
	usrAny, _ := c.Get("usr")
	uid := uidAny.(string)
	usr := usrAny.(string)

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	var name, headline, bio string
	if err := h.DB.QueryRow(ctx,
		`select name, headline, bio from profiles where user_id = $1`,
		uid,
	).Scan(&name, &headline, &bio); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"username": usr,
		"name":     name,
		"headline": headline,
		"bio":      bio,
	})
}

type updateProfileReq struct {
    Name     string `json:"name"`
    Headline string `json:"headline"`
    Bio      string `json:"bio"`
}

func (h *Handler) UpdateProfile(c *gin.Context) {
    var req updateProfileReq
    if err := c.ShouldBindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
        return
    }

    userIDAny, ok := c.Get("user_id")
    if !ok {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
        return
    }
    userID, ok := userIDAny.(string)
    if !ok || userID == "" {
        c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
        return
    }

    // Trim values
    name := strings.TrimSpace(req.Name)
    headline := strings.TrimSpace(req.Headline)
    bio := strings.TrimSpace(req.Bio)

    // If all empty, do nothing
    if name == "" && headline == "" && bio == "" {
        c.JSON(http.StatusOK, gin.H{"ok": true, "updated": 0})
        return
    }

    ctx, cancel := contextTimeout(c, 8*time.Second)
    defer cancel()

    // Build dynamic UPDATE only for non-empty fields
    setParts := make([]string, 0, 3)
    args := make([]any, 0, 4)
    i := 1

    if name != "" {
        setParts = append(setParts, fmt.Sprintf("name = $%d", i))
        args = append(args, name)
        i++
    }
    if headline != "" {
        setParts = append(setParts, fmt.Sprintf("headline = $%d", i))
        args = append(args, headline)
        i++
    }
    if bio != "" {
        setParts = append(setParts, fmt.Sprintf("bio = $%d", i))
        args = append(args, bio)
        i++
    }

    // always update timestamp (optional)
    setParts = append(setParts, "updated_at = now()")

    // where clause arg
    args = append(args, userID)

    q := fmt.Sprintf(
        "update profiles set %s where user_id = $%d",
        strings.Join(setParts, ", "),
        i,
    )

    cmd, err := h.DB.Exec(ctx, q, args...)
    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
        return
    }

    c.JSON(http.StatusOK, gin.H{"ok": true, "updated": cmd.RowsAffected()})
}