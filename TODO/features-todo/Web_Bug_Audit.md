# Web Bug Audit — Findings Report

Audit of the PHP web app (non-security, functional bugs only) — "page won't show" / "shows an error when I do this" class.

## Scope & method
- `php -l` on all 96 PHP files — all parse cleanly.
- POST field contracts (form `name=` vs handler `$_POST` reads) — all match.
- All `require`/`include` targets exist; all redirect paths resolve per folder depth.
- `app/reports/update-status.php` status machine — verified guarded (allowlists, role gates).
- Live MySQL schema diff — see "Live DB pass" section at the bottom.

## Implementation status (2026-10-03)
- **Fixed:** findings #1, #2, #3, #4, #5, #6, #7, #8, #9, #10, #11, #12, #13, #14, #15, #16, #17.
- **Board/ledger "Still Needed" display** (`center-needs.php`, `get_assistance_board.php`) was deliberately left on its documented Sent/Delivered rule — a different surface than the dashboard conflict covered by #9.

## HIGH — page-break / 500-class
1. `public/dashboard.php:53,57,61,65,76,85,88,255` — `mysqli_fetch_assoc()` called on unguarded `mysqli_query()`/`get_result()` results. Any failed query passes `false` → PHP 8 `TypeError` → blank white HTTP 500 (error display off). Every other query in the file is guarded; these aren't.
2. `public/assistance.php:115-119` — donations-ledger query has `LEFT JOIN evac_center_needs n ON n.id = a.need_id AND ec.municipality = ?` with **no `WHERE`** before the scope fragment. The MDR municipality filter is absorbed into the JOIN `ON`, so the scope is **silently dropped**: MDR-Kalibo user sees Ibajay donations in the ledger. (`api/get_assistance_board.php` does it correctly with `WHERE 1 = 1`.)

## MEDIUM — wrong data / misleading UI
3. `public/dashboard.php:40 + :56` — PCF/MDR "Pending" stat box is permanently **0**: `$V_where` excludes `'Pending'` but the box query adds `AND status = 'Pending'`. Total also counts `Dismissed`, so "Total Reports" disagrees with every panel below.
4. `public/incident-reports.php:41,72-76` — MDR status dropdown offers `Pending`/`Reviewed`, but the query WHERE excludes them → **"No matching incident reports."** MDR also can't filter by `Under MDR Review`/`Under PHO Review`.
5. `public/health-reports.php:398` — JS reads `#healthNoMatch`, which **does not exist** → when filters match nothing the tbody goes **blank with no message** (PHO page).
6. `public/edit-incident-report.php:244` — stray `</div>` closes `.panel-body` early → bottom two-thirds of the edit form (map, casualties, evacuation, Save) renders **padding-less and misaligned**. `:91` also rounds the stored minute to nearest 5 → `18:12` reopens as `18:10`, and saving rewrites it.
7. `public/barangay-alerts.php:61-65` — read flag comes from `alert_barangays.is_read`, which nothing in the web sets (mobile writes `alert_reads` instead) → **every alert always shows "Unread"**.
8. `public/dashboard.php:82,307` — barangay evac-center count matches `barangays.name` + `LIMIT 1`; duplicate `Poblacion` rows tie → 0/other-town count for Poblacion users. Secretary's center table lacks the municipality filter → mixes both towns.
9. `public/dashboard.php:348-353` vs `api/get_dashboard_summary.php` — different "Still Needed" formulas → same center shows **different numbers on web vs app**.

## LOW
10. `edit-incident-report.php:91` — minute rounding (see #6).
11. `app/reports/save-report.php:313` — upload-warning redirect to blank form; report already saved → re-submit duplicates.
12. `app/reports/update-report.php:259-264` — "Pending → Pending" log on every edit.
13. `public/health-reports.php:43` — hardcoded types miss `Typhoon`/`Storm Surge`/`Landslide`/`Drought / El Niño`/`Disease Outbreak`/`Others`; `Medical` always zero.
14. `public/alert.php` / `barangay-alerts.php` — no Active/Upcoming/Expired filter (mobile has it).
15. Dashboard/incident pages read `$_SESSION['role']` without `??` in spots.
16. `health-reports.php` / `incident-reports.php` `colspan` off by one vs `<th>` count.
17. `public/dashboard.php:811` — "Active Alerts" box shows PHO-referral count, not alerts.

## Suggested fix order (demo-criticality)
1. Dashboard PCF Pending=0 (#3) — demoed as `mdr_ibajay`.
2. Assistance ledger scope drop (#2).
3. Barangay alerts "Unread forever" (#7).
4. Unguarded `mysqli_fetch_assoc` set (#1).
5. Incident/health filter dead-ends + edit-form `</div>` (#4/#5/#6).

## Live DB pass
- Ran against live MySQL (`capstone`). All columns referenced by the audited queries exist in the live schema — **no unknown-column / schema-drift 500s**.
- `alert_barangays.is_read/read_at` exist but are never written from the web (confirming finding #7 as a data bug, not a crash).