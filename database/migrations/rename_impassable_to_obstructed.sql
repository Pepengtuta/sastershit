-- Rename road status value "Impassable" -> "Obstructed"
-- Two-step: widen the enum first, migrate data, then narrow back.
ALTER TABLE `incident_reports`
  MODIFY COLUMN `road_status` ENUM('Passable','Partially Passable','Impassable','Obstructed')
  NOT NULL DEFAULT 'Passable';

UPDATE `incident_reports` SET `road_status` = 'Obstructed' WHERE `road_status` = 'Impassable';

ALTER TABLE `incident_reports`
  MODIFY COLUMN `road_status` ENUM('Passable','Partially Passable','Obstructed')
  NOT NULL DEFAULT 'Passable';