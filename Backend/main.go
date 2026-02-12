package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"

	"roadmate-api/internal/auth"
	"roadmate-api/internal/db"
	"roadmate-api/internal/handlers"
)

func main() {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	if err := godotenv.Load(); err != nil {
		log.Fatalf("Error loading .env file: %v", err)
	}

	cfg := struct {
		DatabaseURL string
		JWTSecret   string
		Port        string
	}{
		DatabaseURL: os.Getenv("DATABASE_URL"),
		JWTSecret:   os.Getenv("JWT_SECRET"),
		Port:        os.Getenv("PORT"),
	}

	pool, err := db.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		log.Fatalf("db connect failed: %v", err)
	}
	fmt.Println("DB connected ✅", pool)

	// run init.sql like your example
	if err := db.RunSQLFile(ctx, pool, "db/init.sql"); err != nil {
		log.Fatalf("init sql failed: %v", err)
	}

	// Gin setup (this prints the [GIN-debug] startup lines in debug mode)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	// handlers
	h := handlers.New(pool, []byte(cfg.JWTSecret))

	r.GET("/", func(c *gin.Context) {
		c.JSON(200, gin.H{"ok": true})
	})

	// Auth
	r.POST("/auth/signup", h.Signup)
	r.POST("/auth/login", h.Login)
	r.GET("/auth/validUsername", h.ValidUsername)

	authed := r.Group("/me")
	authed.Use(auth.GinRequireAuth([]byte(cfg.JWTSecret)))

	// Profile APIs
	authed.GET("/profile", h.GetProfile)
	authed.PUT("/profile", h.UpdateProfile)

	// Skills APIs
	authed.POST("/skills", h.AddSkill)
	authed.PUT("/skills", h.UpdateSkill)
	authed.DELETE("/skills/:id", h.DeleteSkill)

	// Educations APIs
	authed.POST("/educations", h.AddEducation)
	authed.PUT("/educations", h.UpdateEducation)
	authed.DELETE("/educations/:id", h.DeleteEducation)

	// Projects
	authed.GET("/projects", h.GetProjects)
	authed.POST("/projects", h.CreateProject)
	authed.PUT("/projects", h.EditProjectDetails)
	authed.DELETE("/projects/:projectId", h.DeleteProject)
	authed.PATCH("/projects/:projectId/:pin", h.PinProject)
	authed.PATCH("/projects/reorder", h.ReorderProjects)

	// Project Tasks
	authed.POST("/projects/:projectId/tasks", h.AddTask)
	authed.PATCH("/projects/:projectId/tasks/:taskId", h.UpdateTask)
	authed.DELETE("/projects/:projectId/tasks/:taskId", h.DeleteTask)

	addr := fmt.Sprintf(":%s", cfg.Port)
	fmt.Printf("%s Server running on http://localhost:%s\n", time.Now().Format("2006/01/02 15:04:05"), cfg.Port)
	if err := r.Run(addr); err != nil {
		log.Fatal(err)
	}
}