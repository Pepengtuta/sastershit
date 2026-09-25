-- OBILAK — Mayor Observer Sub-Role Migration
-- Adds Mayor (Kalibo) / Mayor (Ibajay) observer sub-roles within the PCF role.
-- Mayor observers are read-only viewers locked to their own municipality.
-- Run this ONCE on the capstone database (after add_pcf_mdr_subroles.sql).

-- 1. Extend sub_role ENUM to include Mayor observer values
ALTER TABLE users
  MODIFY COLUMN `sub_role` ENUM('captain','secretary','tanod','mdr_admin','mdr_kalibo','mdr_ibajay','mayor_kalibo','mayor_ibajay') DEFAULT NULL;

-- 2. Seed Kalibo Mayor observer (password = admin123)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('Kalibo Mayor', 'mayor_kalibo', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pcf', 'mayor_kalibo', 0, NULL, 'Active', NOW());

-- 3. Seed Ibajay Mayor observer (password = admin123)
INSERT INTO users (name, username, password, role, sub_role, can_manage_users, barangay_id, status, created_at)
VALUES ('Ibajay Mayor', 'mayor_ibajay', '$2y$10$3goCCboBXJCashJQMz7f0e/rdLU0gurab3r8A1Ljw3lZiblRxDGHS',
        'pcf', 'mayor_ibajay', 0, NULL, 'Active', NOW());