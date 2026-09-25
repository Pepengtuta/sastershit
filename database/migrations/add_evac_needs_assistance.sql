-- ============================================================
-- OBILAK - Evacuation Center Needs & Assistance
-- ------------------------------------------------------------
-- Adds the "What the center needs" + "Who donated what to where"
-- (Assistance Ledger) feature.
--
-- Plain-English terms:
--   * "Who's inside the center"  -> evac_center_profile (vulnerable sectors)
--   * "What the center needs"     -> evac_center_needs (item + unit + qty)
--   * "Who donated what to where" -> evac_assistance (ledger)
--
-- DSWD vulnerable-sector code mapping (for the future DAFAC handoff):
--   pregnant           -> expects maternity care  (DSWD Code B family)
--   lactating_mothers  -> Code B - Lactating Mother
--   older_persons      -> Code A - Older Person
--   pwd                -> Code C - PWD
--   infants/children   -> derived from ages in family records
--
-- FULFILLMENT RULE (applies to EVERY query that shows needs):
--   Only statuses 'Sent' and 'Delivered' count as fulfilled supply.
--   'Pledged' is "incoming" and NEVER reduces the unmet quantity.
--   unmet = qty_needed - SUM(qty WHERE status IN ('Sent','Delivered')), floored at 0.
--   A "zero-pledge center" = a center with a profile/needs but NO evac_assistance rows.
--
-- Run this ONCE on the capstone database. Demo data lives in
--   seed_evac_needs_demo.sql  (wipe via  remove_demo_data.sql).
-- ============================================================

-- "Who's inside the center" - one profile per evacuation center.
CREATE TABLE IF NOT EXISTS `evac_center_profile` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evac_center_id` int(11) NOT NULL,
  `total_evacuees` int(11) NOT NULL DEFAULT 0,
  `families` int(11) NOT NULL DEFAULT 0,
  `pregnant` int(11) NOT NULL DEFAULT 0,          -- pregnant women
  `lactating_mothers` int(11) NOT NULL DEFAULT 0, -- DSWD Code B
  `infants` int(11) NOT NULL DEFAULT 0,           -- 0-2 years old
  `children` int(11) NOT NULL DEFAULT 0,          -- 3-12 years old
  `older_persons` int(11) NOT NULL DEFAULT 0,     -- DSWD Code A
  `pwd` int(11) NOT NULL DEFAULT 0,               -- DSWD Code C
  `sick` int(11) NOT NULL DEFAULT 0,
  `injured` int(11) NOT NULL DEFAULT 0,
  `source` enum('manual','computed') NOT NULL DEFAULT 'manual',
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `updated_by` int(11) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_evac_center` (`evac_center_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- "What the center needs" - one or more items per center.
CREATE TABLE IF NOT EXISTS `evac_center_needs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evac_center_id` int(11) NOT NULL,
  `item` varchar(150) NOT NULL,
  `unit` enum('packs','sacks','boxes','liters','pcs','kits') NOT NULL DEFAULT 'pcs',
  `qty_needed` int(11) NOT NULL DEFAULT 0,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_evac_center` (`evac_center_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- "Who donated what to where" - the Assistance Ledger.
CREATE TABLE IF NOT EXISTS `evac_assistance` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evac_center_id` int(11) NOT NULL,
  `need_id` int(11) DEFAULT NULL,
  `donor_user_id` int(11) NOT NULL,
  `donor_label` varchar(120) NOT NULL,
  `item` varchar(150) NOT NULL,
  `unit` enum('packs','sacks','boxes','liters','pcs','kits') NOT NULL DEFAULT 'pcs',
  `qty` int(11) NOT NULL DEFAULT 0,
  `status` enum('Pledged','Sent','Delivered') NOT NULL DEFAULT 'Pledged',
  `pledged_at` timestamp NULL DEFAULT NULL,
  `sent_at` timestamp NULL DEFAULT NULL,
  `delivered_at` timestamp NULL DEFAULT NULL,
  `remarks` varchar(255) DEFAULT NULL,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_evac_center` (`evac_center_id`),
  KEY `idx_donor` (`donor_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Demo marker on evacuation_centers so seeded demo centers are wipable too.
-- (guarded so this migration is safe to re-run)
SET @sql = (SELECT IF(COUNT(*) = 0,
  'ALTER TABLE evacuation_centers ADD COLUMN is_demo tinyint(1) NOT NULL DEFAULT 0 AFTER longitude',
  'SELECT 1')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = 'capstone' AND TABLE_NAME = 'evacuation_centers' AND COLUMN_NAME = 'is_demo');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;