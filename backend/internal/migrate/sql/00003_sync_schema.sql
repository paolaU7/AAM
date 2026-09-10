-- +goose Up
ALTER TABLE school_settings 
  ADD COLUMN IF NOT EXISTS current_academic_year SMALLINT NOT NULL DEFAULT 2026,
  ADD COLUMN IF NOT EXISTS lunch_start TIME NOT NULL DEFAULT '11:50',
  ADD COLUMN IF NOT EXISTS lunch_start_fifth_module TIME NOT NULL DEFAULT '12:50',
  ADD COLUMN IF NOT EXISTS lunch_end TIME NOT NULL DEFAULT '13:10',
  DROP COLUMN IF EXISTS max_division;

-- +goose Down
ALTER TABLE school_settings
  DROP COLUMN IF EXISTS current_academic_year,
  DROP COLUMN IF EXISTS lunch_start,
  DROP COLUMN IF EXISTS lunch_start_fifth_module,
  DROP COLUMN IF EXISTS lunch_end,
  ADD COLUMN IF NOT EXISTS max_division SMALLINT NOT NULL DEFAULT 4;
