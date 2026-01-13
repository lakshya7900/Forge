package config

import (
	"log"
	"os"
)

type Config struct {
	Port       string
	DatabaseURL string
	JWTSecret  string
	CORSOrigin string
}

func Load() Config {
	cfg := Config{
		Port:       get("PORT", "8080"),
		DatabaseURL: must("DATABASE_URL"),
		JWTSecret:  must("JWT_SECRET"),
		CORSOrigin: get("CORS_ORIGIN", "http://localhost"),
	}
	return cfg
}

func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func must(k string) string {
	v := os.Getenv(k)
	if v == "" {
		log.Fatalf("missing required env var: %s", k)
	}
	return v
}