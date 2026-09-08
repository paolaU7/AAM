// Package migrate runs the embedded goose SQL migrations. goose keeps its own
// version table (goose_db_version), separate from the old Alembic one.
package migrate

import (
	"database/sql"
	"embed"
	"fmt"

	_ "github.com/jackc/pgx/v5/stdlib" // registers the "pgx" database/sql driver
	"github.com/pressly/goose/v3"
)

//go:embed sql/*.sql
var migrations embed.FS

func open(databaseURL string) (*sql.DB, error) {
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping db: %w", err)
	}
	return db, nil
}

func prepare() error {
	goose.SetBaseFS(migrations)
	return goose.SetDialect("postgres")
}

// Up applies all pending migrations.
func Up(databaseURL string) error {
	if err := prepare(); err != nil {
		return err
	}
	db, err := open(databaseURL)
	if err != nil {
		return err
	}
	defer db.Close()
	return goose.Up(db, "sql")
}

// Down rolls back the most recent migration.
func Down(databaseURL string) error {
	if err := prepare(); err != nil {
		return err
	}
	db, err := open(databaseURL)
	if err != nil {
		return err
	}
	defer db.Close()
	return goose.Down(db, "sql")
}

// Status prints the migration status.
func Status(databaseURL string) error {
	if err := prepare(); err != nil {
		return err
	}
	db, err := open(databaseURL)
	if err != nil {
		return err
	}
	defer db.Close()
	return goose.Status(db, "sql")
}
