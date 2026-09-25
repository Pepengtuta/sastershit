-- ============================================================
-- OBILAK - DEMO SEED: Evacuation Center Needs & Assistance
-- ------------------------------------------------------------
--  *** DEMO DATA ***  -- every row inserted here is marked is_demo = 1
--  Wipe all of it (including the two demo evac centers) with:
--     remove_demo_data.sql
--
--  Uses REAL Ibajay barangay names (Ibajay_chairman_contacts.txt).
--  Centers:
--   * Agbago Mall        (Agbago)   - already exists (id 8); gets a profile
--   * Poblacion Parish Hall (Poblacion) - NEW demo center
--   * Naisud Barangay Hall  (Naisud)    - NEW demo center, DELIBERATELY has
--                                         ZERO pledges (proves the alert works)
--  Donors (real user ids):
--   * 76 = mdr_ibajay (MDRRMO Ibajay)
--   * 3  = phoadmin   (PHO Provincial Health Office)
-- ============================================================

-- SAFE TO RE-RUN: wipe THIS seed's own demo rows first so a second
-- run never doubles quantities or stacks duplicate demo incidents.
DELETE FROM evac_assistance     WHERE is_demo = 1;
DELETE FROM evac_center_needs   WHERE is_demo = 1;
DELETE FROM evac_center_profile WHERE is_demo = 1;
DELETE FROM incident_reports    WHERE is_demo = 1;   -- cascades attachments/status logs
DELETE FROM evacuation_centers  WHERE is_demo = 1;
UPDATE evacuation_centers SET status = 'Available' WHERE id = 8;

-- Demo centers must exist before declaring needs on them.
INSERT INTO evacuation_centers
  (barangay, municipality, center_name, center_type, capacity, current_evacuees,
   status, contact_person, contact_number, latitude, longitude, is_demo)
VALUES
  ('Poblacion', 'Ibajay', 'Poblacion Parish Hall', 'Church', 150, 96,
   'Open', 'Parish Staff', '09484675060', 11.8212, 122.1676, 1),
  ('Naisud', 'Ibajay', 'Naisud Barangay Hall', 'Barangay Facility', 80, 62,
   'Open', 'Brgy. Admin', '09237473564', 11.8055, 122.1608, 1);

-- Keep Agbago Mall active so the demo Board looks live.
UPDATE evacuation_centers SET status = 'Open' WHERE id = 8;

-- ---------- Incident backing Agbago (the "clean chain") ----------
-- status = Forwarded to PCF so it also flows through the PCF board
-- (the same allowlist used for "credited" incidents elsewhere).
-- user 55 = Agbago Chairman, barangay_id 32 = Agbago (Ibajay).
INSERT INTO incident_reports
  (user_id, barangay_id, disaster_type, evacuation_needed, evacuation_center_id,
   evac_households, evac_adults, evac_children, evac_members, incident_datetime,
   exact_location, road_status, description, assistance_needed, affected_people,
   injured, dead, missing, status, referred_to_pho, is_demo)
VALUES (55, 32, 'Typhoon', 'Yes', 8,
        28, 65, 40, 140, NOW() - INTERVAL 2 DAY,
        'Agbago Barangay, Ibajay', 'Partially Passable',
        'Typhoon-induced flooding; families evacuated to Agbago Mall.',
        'Food packs, drinking water and hygiene kits for evacuees.',
        140, 2, 0, 0, 'Forwarded to PCF', 0, 1);

-- ---------- "Who's inside the center" (profiles) ----------
INSERT INTO evac_center_profile
  (evac_center_id, total_evacuees, families, pregnant, lactating_mothers,
   infants, children, older_persons, pwd, sick, injured, source, is_demo, updated_by)
VALUES
  (8, 140, 28, 4, 7, 9, 31, 18, 5, 6, 2, 'manual', 1, 41);

-- Poblacion Parish Hall profile (find its id by name).
INSERT INTO evac_center_profile
  (evac_center_id, total_evacuees, families, pregnant, lactating_mothers,
   infants, children, older_persons, pwd, sick, injured, source, is_demo, updated_by)
SELECT id, 96, 19, 2, 3, 5, 22, 12, 4, 3, 1, 'manual', 1, 41
  FROM evacuation_centers WHERE center_name = 'Poblacion Parish Hall' AND is_demo = 1 LIMIT 1;

INSERT INTO evac_center_profile
  (evac_center_id, total_evacuees, families, pregnant, lactating_mothers,
   infants, children, older_persons, pwd, sick, injured, source, is_demo, updated_by)
SELECT id, 62, 12, 1, 2, 4, 14, 9, 3, 2, 0, 'manual', 1, 41
  FROM evacuation_centers WHERE center_name = 'Naisud Barangay Hall' AND is_demo = 1 LIMIT 1;

-- ---------- "What the center needs" (needs) ----------
INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Food Packs', 'packs', 140, 1, 41
  FROM evacuation_centers WHERE center_name = 'Agbago Mall' LIMIT 1;

INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Drinking Water', 'liters', 280, 1, 41
  FROM evacuation_centers WHERE center_name = 'Agbago Mall' LIMIT 1;

INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Maternity Kits', 'kits', 15, 1, 41
  FROM evacuation_centers WHERE center_name = 'Agbago Mall' LIMIT 1;

INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Hygiene Kits', 'kits', 20, 1, 41
  FROM evacuation_centers WHERE center_name = 'Agbago Mall' LIMIT 1;

INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Rice', 'sacks', 30, 1, 41
  FROM evacuation_centers WHERE center_name = 'Poblacion Parish Hall' LIMIT 1;

INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Drinking Water', 'liters', 300, 1, 41
  FROM evacuation_centers WHERE center_name = 'Poblacion Parish Hall' LIMIT 1;

INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Blankets', 'pcs', 60, 1, 41
  FROM evacuation_centers WHERE center_name = 'Naisud Barangay Hall' LIMIT 1;

INSERT INTO evac_center_needs (evac_center_id, item, unit, qty_needed, is_demo, created_by)
SELECT id, 'Medicines', 'boxes', 10, 1, 41
  FROM evacuation_centers WHERE center_name = 'Naisud Barangay Hall' LIMIT 1;

-- ---------- "Who donated what to where" (ledger) ----------
-- MDRRMO Ibajay -> Agbago Mall: food packs, DELIVERED.
INSERT INTO evac_assistance
  (evac_center_id, need_id, donor_user_id, donor_label, item, unit, qty, status,
   pledged_at, sent_at, delivered_at, remarks, is_demo)
SELECT ec.id, n.id, 76, 'MDRRMO Ibajay', 'Food Packs', 'packs', 100, 'Delivered',
       NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 1 DAY,
       'First batch, delivered via brgy. hall', 1
  FROM evacuation_centers ec
  INNER JOIN evac_center_needs n ON n.evac_center_id = ec.id AND n.item = 'Food Packs'
  WHERE ec.center_name = 'Agbago Mall' LIMIT 1;

-- PHO Provincial Health Office -> Agbago Mall: maternity kits, SENT (in transit).
INSERT INTO evac_assistance
  (evac_center_id, need_id, donor_user_id, donor_label, item, unit, qty, status,
   pledged_at, sent_at, delivered_at, remarks, is_demo)
SELECT ec.id, n.id, 3, 'PHO Provincial Health Office', 'Maternity Kits', 'kits', 10, 'Sent',
       NOW() - INTERVAL 1 DAY, NOW(), NULL, 'For the pregnant women', 1
  FROM evacuation_centers ec
  INNER JOIN evac_center_needs n ON n.evac_center_id = ec.id AND n.item = 'Maternity Kits'
  WHERE ec.center_name = 'Agbago Mall' LIMIT 1;

-- MDRRMO Ibajay -> Poblacion Parish Hall: water, PLEDGED (incoming).
INSERT INTO evac_assistance
  (evac_center_id, need_id, donor_user_id, donor_label, item, unit, qty, status,
   pledged_at, sent_at, delivered_at, remarks, is_demo)
SELECT ec.id, n.id, 76, 'MDRRMO Ibajay', 'Drinking Water', 'liters', 300, 'Pledged',
       NOW(), NULL, NULL, 'Delivery scheduled tomorrow', 1
  FROM evacuation_centers ec
  INNER JOIN evac_center_needs n ON n.evac_center_id = ec.id AND n.item = 'Drinking Water'
  WHERE ec.center_name = 'Poblacion Parish Hall' LIMIT 1;
-- Naisud Barangay Hall intentionally has ZERO evac_assistance rows (alert case).