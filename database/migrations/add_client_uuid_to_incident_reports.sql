-- ============================================================
-- OBILAK - client_uuid idempotency key on incident_reports
-- ------------------------------------------------------------
-- Nullable client-generated UUID so an offline mobile client can
-- safely retry a report submission. On the first POST the
-- client_uuid is stored; a retry of the same UUID is detected
-- server-side and returns the existing incident id instead of
-- creating a duplicate report (and duplicate status logs).
--
-- Kept NULLABLE on purpose: existing PHP web report creation and
-- older API clients never send this column, and MySQL allows many
-- NULLs inside a unique index, so legacy inserts are unaffected.
--
-- Guarded so this migration is safe to re-run.
-- ============================================================

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE incident_reports ADD COLUMN client_uuid varchar(36) NULL AFTER created_at',
  'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'capstone' AND TABLE_NAME = 'incident_reports' AND COLUMN_NAME = 'client_uuid');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
  'CREATE UNIQUE INDEX idx_incident_reports_client_uuid ON incident_reports (client_uuid)',
  'SELECT 1')
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = 'capstone' AND TABLE_NAME = 'incident_reports' AND INDEX_NAME = 'idx_incident_reports_client_uuid');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;