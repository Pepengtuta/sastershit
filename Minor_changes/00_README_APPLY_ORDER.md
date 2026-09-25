# 00 — Portable Implementation Package: README & Apply Order

## 1. Purpose

This package portably describes six application changes to SASTER/Obilak so that another agent can re-apply them to an older backup of the application (typically an older database dump + an older copy of the source tree running on another machine). The docs are **implementation guides**, not a diff. Each one explains the target behavior, the exact database objects, the backend/web/Flutter code that realises it, the shared calculation rules, the porting steps, the verification checklist, and how completely the change is implemented in the current reference source.

The **current working source** (Web root `C:\xampp\htdocs\vsp\sastergpt`, Flutter app under `flutter/flutter_saster`) is the source of truth. In this repository that state is commit `2de8f86`, tagged `phase-1-complete`.

## 2. Before / After

| Topic | Before | After |
|---|---|---|
| Assistance | No per-center needs board, no donation ledger | Center needs board, pledge ledger, fulfillment states |
| Delivery confirmation | Donor marks "Delivered", no check-in | Barangay countersigns with the quantity actually received |
| Fulfillment display | "Delivered but unconfirmed" looked fulfilled | Only barangay-confirmed `received_at` reduces unmet |
| Pledgors | PCF/PHO/Superadmin only, mayor/Governor read-only | Mayors and the Governor may also pledge (still read-only elsewhere) |
| Pledge status actions | Any board viewer could act | Only the donor or a PHO Admin / PDRRMO / Superadmin override may advance a status |
| Road status | `Impassable` | `Obstructed` (enum value renamed) |

## 3. Related objects (dependency graph)

The six docs build on each other. `03` and `04` are mostly **code-level**; `01` and `02` are schema + code; `06` is an isolated schema rename.

```
06 (road_status rename)      -> independent of the others
01 (needs & assistance board) -> prerequisite for EVERYTHING below
02 (confirm received qty)     -> requires 01 schema
03 (fulfilled / progress / ledger) -> requires 01 + 02 behavior
04 (mayor / governor pledges) -> requires 01; touches the same role helpers as 05
05 (pledge status ownership)  -> requires 01 + 04 sub-roles
```

## 4. Related files (overview)

All paths are relative to the repository root (Web root). Flutter paths are relative to `flutter/flutter_saster`.

- Database: `database/migrations/*.sql` (per-doc file lists inside each doc).
- Shared PHP helpers: `app/includes/functions.php`.
- JSON APIs (used by Flutter): `api/get_assistance_board.php`, `api/get_center_needs.php`, `api/save_center_needs.php`, `api/pledge_assistance.php`, `api/update_assistance_status.php`, `api/confirm_assistance_received.php`, `api/get_dashboard_summary.php`.
- Web pages: `public/assistance.php`, `public/center-needs.php`, `public/create-incident-report.php`, `public/edit-incident-report.php`, `public/incident-reports.php`.
- Web POST handlers: `app/evacuation-centers/{save-center-needs,pledge-assistance,update-assistance-status,confirm-assistance-received}.php`, `app/reports/{save-report,update-report}.php`.
- Flutter: `lib/services/{assistance_service,auth_service}.dart`, `lib/screens/shared/{assistance_board_screen,center_needs_screen}.dart`, `lib/widgets/{pledge_ledger_row,need_progress_bar,fulfilled_chip,report_card,report_details_sheet}.dart`, `lib/screens/barangay/{create_incident_screen,edit_incident_screen}.dart`, `lib/models/incident_model.dart`, `lib/services/incident_service.dart`, `lib/constants/api_config.dart`.

## 5. What this package deliberately EXCLUDES

Do **not** port anything related to:

- Socket.IO / realtime server (`realtime/`), Node.js tests (`realtime/test-phase1.js`).
- Bearer-token API sessions, `api_sessions` / `api_socket_tickets` tables, `socket_ticket.php`, `api_authenticate`/`issue_api_token`.
- CORS-for-realtime headers and the repo-root `.htaccess` that forwards `HTTP_AUTHORIZATION`.
- Any dependency on those (the docs below assume plain `$_SESSION`-based auth on the Web and `acting_user_id`-based APIs, which is how these features originally shipped).

The receiving codebase may have the realtime source present; just do not add realtime-specific code in these docs.

## 6. Excluded credentials / secrets

No passwords or demo seeds are reproduced in these documents. Migration files such as `seed_evac_needs_demo.sql` and `add_governor_role.sql` create demo accounts and seed rows; reference them **by filename** on the porting machine instead of pasting their contents.

## 7. Working procedure (IMPORTANT — apply on EVERY doc)

1. Work on a **separate branch** (Git) so each change is reviewable.
2. **Back up the database first** (see §9).
3. For every file a doc tells you to change, **open the existing file on the target machine first and compare** it to the reference code described here. Some features may already be partially present. Never blindly overwrite.
4. Apply database migrations before the code that reads the new columns/tables (`latest schema first`).
5. Run the verification checklist in the doc.
6. After all six docs: run the end-to-end regression checklist (§8).

## 8. End-to-end regression checklist (final)

Run once, after all six docs are applied:

- [ ] Log in as a **Superadmin** → `public/assistance.php` renders the board; a center with needs shows the needs table and pledge buttons.
- [ ] A **barangay Chairman/Secretary** opens `public/center-needs.php?id=…` for their own centre; needs/profiles save; a `Delivered` donation shows the inline "Confirm Received" field; confirming with `qty_received` updates the board's "Received" column and unmet math.
- [ ] A **Mayor (mayor_kalibo/mayor_ibajay)** sees the board scoped to their town, can pledge, sees its own pledge update buttons, and does **not** see update buttons on other people's pledges (send a crafted direct POST anyway → rejected).
- [ ] The **Governor** sees the province-wide board, can pledge, and can only update its own pledges (direct POST on a PDRRMO pledge → rejected).
- [ ] **PHO Admin (empty sub_role)** and **PDRRMO** can update any pledge's status; **Superadmin** can too.
- [ ] `public/create-incident-report.php` offers **Obstructed** (no "Impassable"); writing a road status keeps the row valid; `incident-reports.php` filter includes Obstructed.
- [ ] Report detail modal shows the road badge: Passable=green, Partially Passable=warning, Obstructed=danger.
- [ ] Flutter build succeeds (`flutter analyze` has no errors/warnings) and the API endpoints return `success:true`.

## 9. Database backup (MANDATORY before any migration)

```sql
-- mysqldump the ENTIRE schema + data (not just the feature tables).
mysqldump -u root capstone > saster_backup_before_assistance_$(date +%Y%m%d%H%M).sql
```

Keep it until the last doc has passed its checklist.

## 10. Where to put this package on the target machine

Place this `Minor_changes/` folder at the repository root next to `database/`, `api/`, `app/`, `public/`, `flutter/`. It is documentation only; it does not need to be served.

## 11. Completion evidence

- All six feature docs below are written against the **current reference source** and are marked `Implemented` where the behaviour verifiably exists there (with `file:line` references).
- What is **not** covered here: running any of this against a ported copy on a second machine (there is no second machine in this environment). That validation is the explicit job of the porting agent using each doc's verification checklist.