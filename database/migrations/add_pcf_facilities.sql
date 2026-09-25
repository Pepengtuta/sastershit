-- OBILAK — Primary Care Facility (PCF) Map Locations
-- Adds the primary care / health care facilities from
-- TODO/pcf_names and location.txt so they can be shown as map pins.
-- Run ONCE on the capstone database.

CREATE TABLE IF NOT EXISTS `pcf_facilities` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `municipality` VARCHAR(100) NOT NULL,
  `latitude` DECIMAL(10,7) NOT NULL,
  `longitude` DECIMAL(10,7) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `pcf_facilities` (`name`, `municipality`, `latitude`, `longitude`) VALUES
('Ibajay District Hospital', 'Ibajay', 11.811574, 122.153570),
('Ibajay Primary Care Facility 1', 'Ibajay', 11.767957, 122.174224),
('Ibajay Rural Health Unit II', 'Ibajay', 11.822270, 122.161785),
('Ibajay Super Health Center', 'Ibajay', 11.817931, 122.123510),
('Kalibo Health and Birthing Center', 'Kalibo', 11.711017, 122.367165),
('Kalibo Rural Health Unit I', 'Kalibo', 11.667289, 122.352998);