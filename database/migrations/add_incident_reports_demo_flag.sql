-- ============================================================
-- OBILAK - Demo marker on incident_reports
-- ------------------------------------------------------------
-- Lets the demo seed mark its incident (and the clean chain
-- incident -> linked evac center -> needs) as is_demo so it can
-- be wiped by remove_demo_data.sql alongside the other demo rows.
--
-- Guarded so this migration is safe to re-run.
-- ============================================================

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE incident_reports ADD COLUMN is_demo tinyint(1) NOT NULL DEFAULT 0 AFTER referred_to_pho',
  'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'capstone' AND TABLE_NAME = 'incident_reports' AND COLUMN_NAME = 'is_demo');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;