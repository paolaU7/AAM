// Package postgres implements the domain repository ports against PostgreSQL
// using pgx. SQL is written by hand — no ORM — so the deduplication semantics
// (INSERT ... ON CONFLICT DO NOTHING on the ULID) and the hand-tuned queries
// ported from the previous SQLAlchemy backend stay explicit.
package postgres

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Open builds a pgx connection pool from a DATABASE_URL. It works with a local
// Postgres and with Supabase, smoothing over the two things a raw Supabase
// connection string trips on:
//
//   - Supabase always requires TLS. pgx's default (sslmode=prefer) already
//     negotiates it, but if the URL explicitly set sslmode=disable we turn TLS
//     back on so the connection doesn't just fail.
//   - The Supabase "Transaction" pooler (Supavisor, port 6543) does not keep
//     per-connection session state, so pgx's default prepared-statement mode
//     breaks. That connection is switched to the simple protocol. The "Session"
//     pooler (port 5432) and the direct connection need none of this.
func Open(ctx context.Context, databaseURL string) (*pgxpool.Pool, error) {
	cfg, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}

	host := cfg.ConnConfig.Host
	isSupabase := strings.Contains(host, ".supabase.co") || strings.Contains(host, ".supabase.com")

	if isSupabase && cfg.ConnConfig.TLSConfig == nil {
		cfg.ConnConfig.TLSConfig = &tls.Config{ServerName: host, MinVersion: tls.VersionTLS12}
	}
	if strings.Contains(host, "pooler.supabase.com") && cfg.ConnConfig.Port == 6543 {
		cfg.ConnConfig.DefaultQueryExecMode = pgx.QueryExecModeSimpleProtocol
		cfg.ConnConfig.StatementCacheCapacity = 0
		cfg.ConnConfig.DescriptionCacheCapacity = 0
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
