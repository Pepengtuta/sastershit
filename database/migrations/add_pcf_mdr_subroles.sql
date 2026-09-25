-- OBILAK — PCF MDRRMO Sub-Role Migration
-- Adds MDR-Admin / MDR-Kalibo / MDR-Ibajay sub-roles within the PCF role
-- Run this ONCE on the capstone database

-- 1. Extend sub_role ENUM to include MDR values
ALTER TABLE users
  MODIFY COLUMN `sub_role` ENUM('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay') DEFAULT NULL;

-- 2. Seed MDR Admin: upgrade existing pcfadmin
--    login stays 'pcfadmin', displays as 'MDR Admin', password = admin123
UPDATE users
SET name = 'MDR Admin',
    sub_role = 'mdr_admin',
    can_manage_users = 1,
    password = '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS'
WHERE username = 'pcfadmin' AND role = 'pcf';

-- 3. Seed MDR-Kalibo admin (password = admin123)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('MDR Kalibo Admin', 'mdr_kalibo', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pcf', 'mdr_kalibo', 0, NULL, 'Active', NOW());

-- 4. Seed MDR-Ibajay admin (password = admin123)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('MDR Ibajay Admin', 'mdr_ibajay', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pcf', 'mdr_ibajay', 0, NULL, 'Active', NOW());
