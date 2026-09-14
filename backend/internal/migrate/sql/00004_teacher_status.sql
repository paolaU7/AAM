-- +goose Up
ALTER TABLE teachers
  ADD COLUMN IF NOT EXISTS status VARCHAR(30) NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS status_reason TEXT,
  ADD COLUMN IF NOT EXISTS return_date DATE;

-- +goose Down
ALTER TABLE teachers
  DROP COLUMN IF EXISTS status,
  DROP COLUMN IF EXISTS status_reason,
  DROP COLUMN IF EXISTS return_date;
