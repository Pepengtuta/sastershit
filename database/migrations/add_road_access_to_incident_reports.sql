-- Road / Bridge Accessibility on incident_reports
-- Tells MDRRMO/PDRRMO whether response teams can physically reach the barangay.
ALTER TABLE `incident_reports`
  ADD COLUMN `road_status` ENUM('Passable','Partially Passable','Impassable') NOT NULL DEFAULT 'Passable' AFTER `exact_location`,
  ADD COLUMN `road_blockage_causes` VARCHAR(255) DEFAULT NULL AFTER `road_status`,
  ADD COLUMN `road_location` VARCHAR(255) DEFAULT NULL AFTER `road_blockage_causes`;