// Package config loads runtime configuration from the environment (and an
// optional .env file), matching the previous backend/app/core/config.py.
package config

import (
	"bufio"
	"os"
	"strings"
)

type Config struct {
	DatabaseURL string
	Port        string
	JWTSecret   string
}

// Load reads .env (if present in the working dir) into the process environment,
// then builds Config. DATABASE_URL is required.
func Load() (Config, error) {
	loadDotEnv(".env")

	c := Config{
		DatabaseURL: os.Getenv("DATABASE_URL"),
		Port:        getenvDefault("PORT", "8000"),
		JWTSecret:   getenvDefault("JWT_SECRET", "dev-insecure-change-me"),
	}
	if c.DatabaseURL == "" {
		return Config{}, &missingEnvError{"DATABASE_URL"}
	}
	return c, nil
}

type missingEnvError struct{ key string }

func (e *missingEnvError) Error() string { return "falta la variable de entorno " + e.key }

func getenvDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// loadDotEnv is a tiny KEY=VALUE parser — no export, no interpolation. Existing
// process env always wins.
func loadDotEnv(path string) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		key, val, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.TrimSpace(key)
		val = strings.Trim(strings.TrimSpace(val), `"'`)
		if _, exists := os.LookupEnv(key); !exists {
			_ = os.Setenv(key, val)
		}
	}
}
