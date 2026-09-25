-- ============================================================
-- OBILAK - pin_outside_area soft flag on incident_reports
-- ------------------------------------------------------------
-- Set to 1 when the submitted map pin falls outside the reporting
-- barangay's boundary polygon. A soft flag (never a blocker): the
-- report is saved normally, but the mismatch is surfaced with an
-- amber badge so the municipal reviewer can double-check.
--
-- Guarded so this migration is safe to re-run.
-- ============================================================

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE incident_reports ADD COLUMN pin_outside_area tinyint(1) NOT NULL DEFAULT 0 AFTER missing',
  'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'capstone' AND TABLE_NAME = 'incident_reports' AND COLUMN_NAME = 'pin_outside_area');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;