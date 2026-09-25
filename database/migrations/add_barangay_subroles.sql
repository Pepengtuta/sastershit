-- OBILAK — Barangay Sub-Role Migration
-- Adds Captain/Secretary/Tanod sub-roles within the barangay role
-- Run this ONCE on the capstone database

-- 1. Add sub_role column (ENUM: captain, secretary, tanod)
ALTER TABLE users
  ADD COLUMN `sub_role` ENUM('captain','secretary','tanod') DEFAULT NULL
    AFTER `role`;

-- 2. Add can_manage_users flag
ALTER TABLE users
  ADD COLUMN `can_manage_users` TINYINT(1) DEFAULT 0
    AFTER `sub_role`;

-- 3. Migrate existing 16 barangay accounts → Captain
UPDATE users
SET sub_role = 'captain', can_manage_users = 1
WHERE role = 'barangay' AND sub_role IS NULL;
