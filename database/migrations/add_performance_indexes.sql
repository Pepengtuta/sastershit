-- ============================================================
-- OBILAK - Performance indexes for disaster-time load
-- ------------------------------------------------------------
-- Purpose: speed up the lookups hammered when many barangay
-- officials (chairmen + BHERTs) submit reports and refresh
-- dashboards at the same time during an active disaster.
--
-- Purely additive. No schema/column/data changes. Safe to run
-- ONCE on the capstone database.
--
-- NOTE: MySQL has no "CREATE INDEX IF NOT EXISTS", so re-running
-- this file will fail on the duplicate-key error. Verify first:
--   SHOW INDEX FROM incident_reports;
--   SHOW INDEX FROM evac_assistance;
-- The columns below are NOT yet indexed:
--   incident_reports.(status, created_at)
--   evac_assistance.(need_id, status)
-- (barangay_id, user_id, evac_center_id are already indexed.)
-- ============================================================

ALTER TABLE `incident_reports`
  ADD INDEX `idx_status` (`status`),
  ADD INDEX `idx_created_at` (`created_at`);

ALTER TABLE `evac_assistance`
  ADD INDEX `idx_need_id` (`need_id`),
  ADD INDEX `idx_status` (`status`);