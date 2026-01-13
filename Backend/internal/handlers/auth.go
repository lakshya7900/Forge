package handlers

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"roadmate-api/internal/auth"
)

type Handler struct {
	DB        *pgxpool.Pool
	JWTSecret []byte
}

func New(db *pgxpool.Pool, jwtSecret []byte) *Handler {
	return &Handler{DB: db, JWTSecret: jwtSecret}
}

type signupReq struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type loginReq struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

type authResp struct {
	Token    string `json:"token"`
	UserID   string `json:"userId"`
	Username string `json:"username"`
}

type validUsernameResp struct {
    Available bool `json:"available"`
}

func (h *Handler) Signup(c *gin.Context) {
	var req signupReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	u := strings.TrimSpace(req.Username)
	if u == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing username/password"})
		return
	}
	if len(req.Password) < 8 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "password too short"})
		return
	}

	hash, err := auth.HashPassword(req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	var userID string
	err = h.DB.QueryRow(ctx,
		`insert into users (username, password_hash) values ($1, $2) returning id`,
		u, hash,
	).Scan(&userID)

	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"error": "username taken"})
		return
	}

	_, _ = h.DB.Exec(ctx, `insert into profiles (user_id, username) values ($1, $2)`, userID, u)

	token, err := auth.SignToken(h.JWTSecret, userID, u)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, authResp{Token: token, UserID: userID, Username: u})
}

func (h *Handler) Login(c *gin.Context) {
	var req loginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	u := strings.TrimSpace(req.Username)
	if u == "" || req.Password == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing username/password"})
		return
	}

	ctx, cancel := contextTimeout(c, 8*time.Second)
	defer cancel()

	var userID, hash string
	err := h.DB.QueryRow(ctx,
		`select id, password_hash from users where username = $1`,
		u,
	).Scan(&userID, &hash)

	if err != nil {
		if err == pgx.ErrNoRows {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if err := auth.CheckPassword(hash, req.Password); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
		return
	}

	token, err := auth.SignToken(h.JWTSecret, userID, u)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, authResp{Token: token, UserID: userID, Username: u})
}

func (h *Handler) ValidUsername(c *gin.Context) {
    username := strings.TrimSpace(c.Query("username"))
    if username == "" {
        c.JSON(http.StatusBadRequest, gin.H{"error": "missing username"})
        return
    }

    // optional: enforce basic rules (so your UI doesn't accept junk)
    if len(username) < 3 {
        c.JSON(http.StatusOK, validUsernameResp{Available: false})
        return
    }

    ctx, cancel := contextTimeout(c, 5*time.Second)
    defer cancel()

    var exists bool
    err := h.DB.QueryRow(ctx,
        `select exists(select 1 from users where lower(username) = lower($1))`,
        username,
    ).Scan(&exists)

    if err != nil {
        c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
        return
    }

    c.JSON(http.StatusOK, validUsernameResp{Available: !exists})
}