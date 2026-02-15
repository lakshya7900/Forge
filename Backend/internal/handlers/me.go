package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// ========= Profile DTOs (responses) =========
type Profile struct {
	Username   string      `json:"username"`
	Name       string      `json:"name"`
	Headline   string      `json:"headline"`
	Bio        string      `json:"bio"`
	Skills     []Skill     `json:"skills"`
	Educations []Education `json:"educations"`
}

type Skill struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Proficiency int    `json:"proficiency"`
}

type Education struct {
	ID        string `json:"id"`
	School    string `json:"school"`
	Degree    string `json:"degree"`
	Major     string `json:"major"`
	StartYear int    `json:"startyear"`
	EndYear   int    `json:"endyear"`
}

// ========= Requests =========
type updateProfileReq struct {
	Name     string `json:"name"`
	Headline string `json:"headline"`
	Bio      string `json:"bio"`
}

type addSkillReq struct {
	Name        string `json:"name"`
	Proficiency int    `json:"proficiency"`
}

type updateSkillReq struct {
	ID          string `json:"id"`
	Proficiency int    `json:"proficiency"`
}

type addEducationReq struct {
	School    string `json:"school"`
	Degree    string `json:"degree"`
	Major     string `json:"major"`
	StartYear int    `json:"startyear"`
	EndYear   int    `json:"endyear"`
}

type updateEducationReq struct {
	ID        string `json:"id"`
	School    string `json:"school"`
	Degree    string `json:"degree"`
	Major     string `json:"major"`
	StartYear int    `json:"startyear"`
	EndYear   int    `json:"endyear"`
}

func (h *Handler) GetProfile(c *gin.Context) {
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

	usrAny, ok := c.Get("usr")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}

	usr, ok := usrAny.(string)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}

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

	skills := make([]Skill, 0)

	skillRows, err := h.DB.Query(ctx,
		`select id::text, name, proficiency
        from skills
        where user_id = $1
        order by proficiency desc, lower(name) asc
        `, uid)
	if err != nil {
		fmt.Print(err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	for skillRows.Next() {
		var s Skill
		if err := skillRows.Scan(&s.ID, &s.Name, &s.Proficiency); err != nil {
			fmt.Print(err)
			skillRows.Close()
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		skills = append(skills, s)
	}
	if err := skillRows.Err(); err != nil {
		fmt.Print(err)
		skillRows.Close()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	skillRows.Close()

	educations := make([]Education, 0)

	eduRows, err := h.DB.Query(ctx,
		`select id::text, school, degree, major, start_year, end_year
        from educations
        where user_id = $1
        order by start_year desc, lower(school) asc
        `, uid)
	if err != nil {
		fmt.Print(err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	for eduRows.Next() {
		var e Education
		if err := eduRows.Scan(&e.ID, &e.School, &e.Degree, &e.Major, &e.StartYear, &e.EndYear); err != nil {
			fmt.Print(err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
			return
		}
		educations = append(educations, e)
	}

	if err := eduRows.Err(); err != nil {
		fmt.Print(err)
		eduRows.Close()
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}
	eduRows.Close()

	c.JSON(http.StatusOK, Profile{
		Username:   usr,
		Name:       name,
		Headline:   headline,
		Bio:        bio,
		Skills:     skills,
		Educations: educations,
	})
}

func (h *Handler) UpdateProfile(c *gin.Context) {
	var req updateProfileReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	userIDAny, ok := c.Get("uid")
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

func (h *Handler) AddSkill(c *gin.Context) {
	var req addSkillReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	name := strings.TrimSpace(req.Name)
	if name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing name"})
		return
	}
	if req.Proficiency < 1 || req.Proficiency > 10 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid proficiency"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	var exists bool
	if err := h.DB.QueryRow(ctx,
		`select exists(
            select 1 from skills 
            where user_id = $1 and lower(name) = lower($2)
        )
    `, userID, name).Scan(&exists); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if exists {
		c.JSON(http.StatusConflict, gin.H{"error": "skill already exists"})
		return
	}

	var created Skill
	if err := h.DB.QueryRow(ctx,
		`insert into skills (user_id, name, proficiency)
        values ($1, $2, $3)
        returning id::text, name, proficiency
    `, userID, name, req.Proficiency).Scan(&created.ID, &created.Name, &created.Proficiency); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, created)
}

func (h *Handler) UpdateSkill(c *gin.Context) {
	var req updateSkillReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	if req.Proficiency < 1 || req.Proficiency > 10 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid proficiency"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	var updated Skill

	err := h.DB.QueryRow(ctx,
		`update skills set proficiency = $1
        where id = $2::uuid and user_id = $3
        returning id::text, name, proficiency
    `, req.Proficiency, req.ID, userID).Scan(&updated.ID, &updated.Name, &updated.Proficiency)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "skill not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (h *Handler) DeleteSkill(c *gin.Context) {
	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	cmd, err := h.DB.Exec(ctx,
		`delete from skills where id = $1::uuid and user_id = $2`,
		id, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "skill not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *Handler) AddEducation(c *gin.Context) {
	var req addEducationReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	school := strings.TrimSpace(req.School)
	if school == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing school"})
		return
	}

	degree := strings.TrimSpace(req.Degree)
	if degree == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing degree"})
		return
	}

	major := strings.TrimSpace(req.Major)
	if major == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing major"})
		return
	}

	startYear := req.StartYear
	if startYear == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing start year"})
		return
	}

	endYear := req.EndYear
	if endYear == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing end year"})
		return
	}

	if endYear < startYear {
		c.JSON(http.StatusBadRequest, gin.H{"error": "end year before start year"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	var exists bool
	if err := h.DB.QueryRow(ctx,
		`select exists(
            select 1 from educations 
            where user_id = $1 and 
            lower(school) = lower($2) and 
            lower(degree) = lower($3) and
            lower(major) = lower($4) and
            start_year = $5 and
            end_year = $6
        )
    `, userID, school, degree, major, startYear, endYear).Scan(&exists); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if exists {
		c.JSON(http.StatusConflict, gin.H{"error": "Education already exists"})
		return
	}

	var created Education
	err := h.DB.QueryRow(ctx,
		`insert into educations (user_id, school, degree, major, start_year, end_year)
        values ($1, $2, $3, $4, $5, $6)
        returning id::text, school, degree, major, start_year, end_year
    `, userID, school, degree, major, startYear, endYear,
	).Scan(&created.ID, &created.School, &created.Degree, &created.Major, &created.StartYear, &created.EndYear)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, created)
}

func (h *Handler) UpdateEducation(c *gin.Context) {
	var req updateEducationReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "bad json"})
		return
	}

	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	school := strings.TrimSpace(req.School)
	if school == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing school"})
		return
	}

	degree := strings.TrimSpace(req.Degree)
	if degree == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing degree"})
		return
	}

	major := strings.TrimSpace(req.Major)
	if major == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing major"})
		return
	}

	startYear := req.StartYear
	if startYear == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing start year"})
		return
	}

	endYear := req.EndYear
	if endYear == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing end year"})
		return
	}

	if endYear < startYear {
		c.JSON(http.StatusBadRequest, gin.H{"error": "end year before start year"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	var updated Education

	err := h.DB.QueryRow(ctx,
		`update educations
        set school = $1, 
        degree = $2, 
        major = $3, 
        start_year = $4, 
        end_year = $5
        where id = $6::uuid and user_id = $7
        returning id::text, school, degree, major, start_year, end_year
    `, school,
		degree,
		major,
		startYear,
		endYear,
		req.ID,
		userID).Scan(&updated.ID,
		&updated.School,
		&updated.Degree,
		&updated.Major,
		&updated.StartYear,
		&updated.EndYear)

	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "education not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	c.JSON(http.StatusOK, updated)
}

func (h *Handler) DeleteEducation(c *gin.Context) {
	userIDAny, ok := c.Get("uid")
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth"})
		return
	}
	userID, ok := userIDAny.(string)
	if !ok || userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "bad auth"})
		return
	}

	id := strings.TrimSpace(c.Param("id"))
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing id"})
		return
	}

	ctx, cancel := contextTimeout(c, 5*time.Second)
	defer cancel()

	cmd, err := h.DB.Exec(ctx,
		`delete from educations where id = $1::uuid and user_id = $2`,
		id, userID,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "server error"})
		return
	}

	if cmd.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"error": "education not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}
