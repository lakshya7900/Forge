package handlers

import (
	"net/http"
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