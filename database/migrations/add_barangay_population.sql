-- OBILAK — Barangay Population Migration
-- Adds population column to barangays table for auto-populating affected count
-- on natural disaster incident reports
-- Run this ONCE on the capstone database

-- MySQL
ALTER TABLE barangays
  ADD COLUMN `population` INT DEFAULT 0 AFTER `longitude`;

-- Seed population values (replace with real PSA census figures):
-- UPDATE barangays SET population = 0 WHERE population = 0;
