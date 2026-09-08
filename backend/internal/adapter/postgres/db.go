// Package postgres implements the domain repository ports against PostgreSQL
// using pgx. SQL is written by hand — no ORM — so the deduplication semantics
// (INSERT ... ON CONFLICT DO NOTHING on the ULID) and the hand-tuned queries
// ported from the previous SQLAlchemy backend stay explicit.
package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Open builds a pgx connection pool from a DATABASE_URL.
func Open(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("connect: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping: %w", err)
	}
	return pool, nil
}

// noRows reports whether err is pgx.ErrNoRows.
func noRows(err error) bool { return errors.Is(err, pgx.ErrNoRows) }

// derefStr turns a *string into an `any` suitable as a query arg: nil -> SQL
// NULL, otherwise the string value.
func derefStr(s *string) any {
	if s == nil {
		return nil
	}
	return *s
}
