-- ============================================================
-- OBILAK - is_natural flag on disaster_types
-- ------------------------------------------------------------
-- Lets the mobile app know which disaster types are natural
-- disasters (affect the whole barangay population) so the
-- Create Incident form can auto-fill the affected count from
-- the server's canonical list instead of hardcoding types in
-- Dart. The server stays the authoritative source.
--
-- The migration also tags the two non-natural types
-- (Accident / Mass Casualty Incident and Others) as 0.
--
-- Guarded so this migration is safe to re-run.
-- ============================================================

SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE disaster_types ADD COLUMN is_natural tinyint(1) NOT NULL DEFAULT 1 AFTER status',
  'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'capstone' AND TABLE_NAME = 'disaster_types' AND COLUMN_NAME = 'is_natural');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE disaster_types SET is_natural = 0 WHERE id IN (9, 10);