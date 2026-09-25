Affected Auto-Population + Barangay Population Management
1. Database
Add one column to the existing barangays table (no new table):
ALTER TABLE barangays ADD COLUMN population INTEGER DEFAULT 0;
​
Seed real population figures per barangay via a one-time UPDATE script (migration + seed data), no admin page needed for initial setup.
2. Disaster type list (Aklan-specific, per professor)
Typhoon
Flood
Flash Flood
Storm Surge
Earthquake
Landslide
Fire
Drought / El Niño
Disease Outbreak
Accident / Mass Casualty Incident   ← excluded (man-made)
Others                              ← excluded (not population-wide)
​
Add Flash Flood and Volcanic Eruption to the disaster type options wherever they're currently defined (Create Incident form, dashboard disaster-summary grouping, etc.) — currently missing from the codebase.
3. Create Incident Report — auto-fill "Affected"
On disaster_type change: if it's one of the 10 natural types above, auto-set the affected_people field to the reporting barangay's population.
If it's Accident/MCI or Others, leave affected_people untouched.
The field stays fully editable in all cases — auto-fill is a smart default, not a lock.
4. Population editing UI — no new admin page
Instead of manage-barangay-population.php, extend the existing Manage Users page:
Barangay Captain/Secretary view: show Barangay Population: 123,456 [][] (or editable number field) scoped to their own barangay, near the page header.
Superadmin view: add a barangay dropdown next to the population field (reusing the same barangay list/data source as the existing "Select barangay" dropdown in the Add/Edit User modal) so superadmin can pick any barangay and edit its population directly — no municipality-filter dependency required.
Backend: one small update endpoint (e.g. update_barangay_population) permission-gated to Captain/Secretary (own barangay only) and Superadmin (any barangay).
get_barangays.js (or wherever barangay rows are fetched) must include population in its response.