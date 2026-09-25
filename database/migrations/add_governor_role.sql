-- OBILAK — Aklan Governor (PHO Read-Only Observer) Migration
-- Adds a Governor sub-role within the PHO role. The Governor is a province-wide
-- read-only observer: default municipality filter Ibajay, switchable to All/Kalibo,
-- no write access (no publishing, no hotline/evac management, no provincial actions).
-- Run this ONCE on the capstone database (after add_mayor_subroles.sql).

-- 1. Extend sub_role ENUM to include the Governor value
--    (also restores 'pdrrmo', which the mayor migration had dropped from the ENUM,
--    silently blanking the existing PDRRMO account's sub_role)
ALTER TABLE users
  MODIFY COLUMN `sub_role` ENUM('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay','pdrrmo','governor','mayor_kalibo','mayor_ibajay') DEFAULT NULL;

-- 2. Restore the PDRRMO account's sub_role (lost when the mayor migration modified the ENUM)
UPDATE users SET sub_role = 'pdrrmo' WHERE username = 'pdrrmo' AND role = 'pho' AND (sub_role = '' OR sub_role IS NULL);

-- 3. Seed Aklan Governor (password = admin123)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('Aklan Governor', 'governor', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pho', 'governor', 0, NULL, 'Active', NOW());