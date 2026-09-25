# 06 — Road Status: "Impassable" → "Obstructed"

## 1. Purpose

Rename the incident-report road-status enum value **`Impassable` → `Obstructed`** so the terminology matches operational DRRM wording ("obstructed road/bridge" rather than "impassable"), everywhere: the stored enum, the write allow-lists in every backend writer, the web create/edit forms, the list filter, the badge colour mapping, and the Flutter forms/detail widgets. It is an isolated change that does not touch the assistance schema.

## 2. Before / After

| Surface | Before | After |
|---|---|---|
| `incident_reports.road_status` enum | `('Passable','Partially Passable','Impassable')` | `('Passable','Partially Passable','Obstructed')` |
| Historical rows | some `'Impassable'` | backfilled to `'Obstructed'` |
| Backend allow-lists | `Impassable` | `Obstructed` |
| Web form / filter | `Impassable` option | `Obstructed` option |
| Badge | — | Obstructed → `badge-soft-danger` (red), Partially Passable → `badge-soft-warning` |
| Flutter | `Impassable` | `Obstructed` everywhere (option + colour case) |

## 3. Related database objects

Reference migration: `database/migrations/rename_impassable_to_obstructed.sql` (two-step: widen → migrate → narrow):

```sql
ALTER TABLE `incident_reports`
  MODIFY COLUMN `road_status` ENUM('Passable','Partially Passable','Impassable','Obstructed')
  NOT NULL DEFAULT 'Passable';

UPDATE `incident_reports` SET `road_status` = 'Obstructed' WHERE `road_status` = 'Impassable';

ALTER TABLE `incident_reports`
  MODIFY COLUMN `road_status` ENUM('Passable','Partially Passable','Obstructed')
  NOT NULL DEFAULT 'Passable';
```

History/prerequisite: `add_road_access_to_incident_reports.sql` first added the column set:

```sql
-- (reference) adds, AFTER `exact_location`:
-- road_status enum('Passable','Partially Passable','Impassable') NOT NULL DEFAULT 'Passable'
-- road_blockage_causes varchar(255)
-- road_location varchar(255)
```

**Backfill note:** old dumps still contain `Impassable` rows (e.g. `database/backups/incident_pin_outside_before_20260910_122049.sql` samples). If you restored from such a dump, the UPDATE above cleans them; run `SELECT COUNT(*) FROM incident_reports WHERE road_status = 'Impassable';` afterwards — it must return **0**.

**Rollback:** run the same two-step in reverse (widen back to include `Impassable`, `UPDATE … SET 'Impassable' WHERE 'Obstructed'`, then narrow), or accept `Obstructed` permanently.

**Idempotency:** safe to re-run (the UPDATE matches nothing on a second run; MySQL 8+ accepts enum MODIFY without values being present).

## 4. Related files

Server writers / validators (allow-list `['Passable','Partially Passable','Obstructed']`, value sanitised to `'Passable'` when unknown):

- `api/create_incident.php:67`
- `api/update_incident.php:63`
- `app/reports/save-report.php:50`
- `app/reports/update-report.php:75`

Web forms / filter:

- `public/create-incident-report.php:144` (`<option value="Obstructed">Obstructed</option>`)
- `public/edit-incident-report.php:107` (validate against the same 3-value list), `:188` (option)
- `public/incident-reports.php:316` (filter `<option value="obstructed">Obstructed</option>`)

Badges/display:

- `app/includes/functions.php:51-61` `road_status_class()`: `Passable → badge-soft-success`, `Partially Passable → badge-soft-warning`, `Obstructed → badge-soft-danger`, else `badge-soft-secondary`.
- `functions.php:922-938` — incident detail modal shows the badge with the value, plus `Causes` / `Road / Bridge` lines (value rendered through `h()`).

Flutter:

- `lib/screens/barangay/create_incident_screen.dart:108` (option), `:657` (colour case)
- `lib/screens/barangay/edit_incident_screen.dart:99, 690`
- `lib/widgets/report_card.dart:63, 227`
- `lib/widgets/report_details_sheet.dart:196, 187`
- `lib/models/incident_model.dart:72` (`roadStatus … ?? 'Passable'`)
- `lib/services/incident_service.dart:52, 107` (posts `road_status`)

## 5. Backend rules

- The canonical enum is exactly `enum('Passable','Partially Passable','Obstructed')`, default `'Passable'`.
- Every writer validates against `['Passable','Partially Passable','Obstructed']` and falls back to `'Passable'` on invalid input — so a stray client sending `Impassable` is coerced, never rejected with a 500 (MySQL strict mode would otherwise error on the value).
- The filter value is lowercased for the `GET` param (`obstructed`), matching the web's existing lowercase convention.
- Display uses `road_status_class()` — a single shared mapping (same pattern as `center_status_badge_class`/`status_class`).
- The Flutter colour cases use "danger" styling (red/orange) for Obstructed, matching the web badge.

## 6. Web changes

- Replace `<option value="Impassable">Impassable</option>` with `<option value="Obstructed">Obstructed</option>` in `public/create-incident-report.php`, `public/edit-incident-report.php` (keep the `selected` logic comparing against the row's value, now `'Obstructed'`), and the `incident-reports.php` filter.
- Update any display string "Impassable" in report list/detail templates (in the reference source there is none left outside backups/migrations — verify with a grep on the ported tree).
- Badge mapping already handles `Obstructed` via `road_status_class()`.

## 7. Flutter changes

- `create_incident_screen.dart` and `edit_incident_screen.dart`: dropdown options list — replace `'Impassable'` with `'Obstructed'`; colour `switch` case for `'Obstructed'` (danger colour) — reference lines in §4.
- `report_card.dart` + `report_details_sheet.dart`: colour `switch` cases for `'Obstructed'`; text rendering is automatic (the raw value is displayed).
- `incident_model.dart` default stays `'Passable'`.

## 8. Shared rules

- One enum, one allow-list, one badge map, one default (`Passable`) — shared across web + API + Flutter; keep them in sync.
- Historical data migration is a **data** concern (backfill UPDATE), independent from the code change; do the UPDATE in the same migration as the enum narrowing, before it.

## 9. Porting procedure

1. Back up DB.
2. Run `rename_impassable_to_obstructed.sql` (two-step; safe to re-run).
3. Update all backend writer allow-lists to the three-value list (reference `file:line` targets in §4 — search your tree for `Impassable` to catch extra writers).
4. Update the three web form/filter option values.
5. Update the Flutter options + colour cases.
6. `grep -ri impassable APP ROOT` — remaining hits must be only in `database/backups/` (old dumps) and the migration file itself.

## 10. Verification checklist

- [ ] `SHOW COLUMNS FROM incident_reports LIKE 'road_status'` shows enum without `Impassable`, default `Passable`.
- [ ] `SELECT COUNT(*) FROM incident_reports WHERE road_status = 'Impassable'` → 0 after backfill.
- [ ] Creating a report via web with road status `Obstructed` and `road_blockage_causes`/`road_location` saves correctly; the detail modal badge is `badge-soft-danger`; editing preserves the value.
- [ ] Creating via API with `road_status='Impassable'` (stale client) lands as `Passable` (coerced), not an error.
- [ ] `incident-reports.php` filter `obstructed` filters correctly.
- [ ] Flutter: create/edit dropdown shows Obstructed; report card/detail tints Obstructed with the danger colour; `flutter analyze` clean.

## 11. Completion evidence

Status: **Implemented** in the reference source.

- Migration `rename_impassable_to_obstructed.sql` present; live schema confirmed `enum('Passable','Partially Passable','Obstructed') NOT NULL DEFAULT 'Passable'`.
- Every writer allow-list in the reference tree already uses `Obstructed` (lines cited; `api/create_incident.php` was read directly at line 67, all others verified by grep).
- Web `Obstructed` options and the `road_status_class()` badge mapping (Obstructed → danger) verified; Flutter options/colour cases verified by line grep.
- Repo-wide grep for `Impassable` returns only `database/backups/*.sql` (old dump content) and the migration itself — zero application-code leftovers.
- Not covered: executing the migration on a ported DB (no second environment); the backfill/`SHOW COLUMNS` steps above are the porter's verification.