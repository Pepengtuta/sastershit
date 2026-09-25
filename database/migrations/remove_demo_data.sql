-- ============================================================
-- OBILAK - REMOVE DEMO DATA (Evacuation Center Needs & Assistance)
-- ------------------------------------------------------------
-- Deletes ALL demo rows (is_demo = 1) and the two demo evac centers.
-- Real/user-entered data is untouched. Run only when you want to
-- clear the professor-demo dataset.
-- ============================================================

DELETE FROM evac_assistance     WHERE is_demo = 1;
DELETE FROM evac_center_needs   WHERE is_demo = 1;
DELETE FROM evac_center_profile WHERE is_demo = 1;
-- Demo incidents carry child rows in incident_attachments / incident_status_logs,
-- both with ON DELETE CASCADE against incident_reports, so deleting the parent
-- cleans those automatically.
DELETE FROM incident_reports    WHERE is_demo = 1;

-- Take the demo centers out of circulation (restore Agbago Mall's old status).
DELETE FROM evacuation_centers WHERE is_demo = 1;
UPDATE evacuation_centers SET status = 'Available' WHERE id = 8;