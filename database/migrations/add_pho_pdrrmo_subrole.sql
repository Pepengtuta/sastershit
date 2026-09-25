-- OBILAK — PHO PDRRMO Sub-Role Migration
-- Makes the default Provincial account an admin (can manage users)
-- and adds the PDRRMO operational sub-role (province-wide rescue team).
-- Run this ONCE on the capstone database

-- 1. Extend sub_role ENUM to include PDRRMO
ALTER TABLE users
  MODIFY COLUMN `sub_role` ENUM('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay','pdrrmo') DEFAULT NULL;

-- 2. Upgrade the default Provincial account to PHO Admin.
--    login stays 'phoadmin', displays as 'Provincial Admin', password = admin123
UPDATE users
SET sub_role = NULL,
    can_manage_users = 1
WHERE username = 'phoadmin' AND role = 'pho';

-- 3. Safety: PDRRMO accounts are never user admins.
UPDATE users
SET can_manage_users = 0
WHERE role = 'pho' AND sub_role = 'pdrrmo';

-- 4. Seed a PDRRMO account (password = admin123)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('PDRRMO', 'pdrrmo', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pho', 'pdrrmo', 0, NULL, 'Active', NOW());