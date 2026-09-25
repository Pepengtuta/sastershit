-- OBILAK — Evacuation Headcount Migration
-- Adds optional evacuation headcount fields to incident_reports
-- Used by Tanod/BHERT when reporting from an evacuation center
-- Run this ONCE on the capstone database

-- MySQL
ALTER TABLE incident_reports
  ADD COLUMN `evac_households` INT DEFAULT 0 AFTER `evacuation_center_id`,
  ADD COLUMN `evac_adults` INT DEFAULT 0 AFTER `evac_households`,
  ADD COLUMN `evac_children` INT DEFAULT 0 AFTER `evac_adults`,
  ADD COLUMN `evac_members` INT DEFAULT 0 AFTER `evac_children`;

-- PostgreSQL equivalent (for Node.js project):
-- ALTER TABLE incident_reports
--   ADD COLUMN evac_households INTEGER DEFAULT 0,
--   ADD COLUMN evac_adults INTEGER DEFAULT 0,
--   ADD COLUMN evac_children INTEGER DEFAULT 0,
--   ADD COLUMN evac_members INTEGER DEFAULT 0;
