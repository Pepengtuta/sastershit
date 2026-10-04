# Request Assistance + Donor Pledges

Feature plan: barangay-initiated "request assistance" not tied to an evacuation center, plus donor pledges (MDR / Mayor / Governor / PDRRMO / PHO) that fulfill those requests — reusing the existing pledge workflow (Pledged → Sent → Delivered → Confirmed Received).

## Background / professor feedback

1. "In Needs & Assistance, the barangay should also be able to send needs & assistance, not just when they ask for [a center / when asked]." — Today a barangay can only declare needs by editing an **evacuation center's** needs page (`evac_center_needs`). With no center, it cannot request anything. Barangay users also cannot see the Needs & Assistance board on the web.
2. "Mayors and governors make donations like they declare: 'oh, evacuees might need this, I'll send this to them.'" — Donor declarations already exist (evac_assistance ledger) but on the **web** the donor label is generic for mayor/governor sub-roles; on mobile labels are correct.

## Current state

- Roles: `barangay` (captain/secretary/tanod), `pcf` (mdr_admin/mdr_kalibo/mdr_ibajay/mayor_kalibo/mayor_ibajay), `pho` (pdrrmo/governor), `superadmin`.
- `can_view_assistance()` / `can_pledge_assistance()` → `superadmin`/`pho`/`pcf` only (web). Mayor/governor are pcf/pho sub-roles, so they can pledge, but `app/evacuation-centers/pledge-assistance.php` donor-label logic only renders MDRRMO/MDR Admin/Municipal Office/PHO/Super Admin.
- `api/pledge_assistance.php` already maps `mayor_kalibo`, `mayor_ibajay`, `governor` labels and allows their scope (municipal / province-wide).
- Needs anchored to centers only: `evac_center_needs.evac_center_id` (created via `app/evacuation-centers/save-center-needs.php` / `api/save_center_needs.php`).

## Data model — `database/migrations/add_brgy_assistance_requests.sql`

- New table `brgy_assistance_requests`:
  - `id` INT PK AI
  - `barangay_id` INT
  - `barangay_name` VARCHAR (denormalized for labels / scoping)
  - `municipality` VARCHAR (for MDR scoping)
  - `item` VARCHAR
  - `unit` VARCHAR (ENUM-ish allowlist: packs/sacks/boxes/liters/pcs/kits)
  - `qty_needed` INT
  - `remarks` TEXT
  - `requested_by` INT (FK users)
  - `status` ENUM('Open','Closed') default 'Open'
  - `is_demo` TINYINT default 0
  - `created_at` DATETIME
- Extend `evac_assistance`:
  - `brgy_request_id` INT NULL (indexed)
  - `evac_center_id` becomes nullable (allow NULL when `brgy_request_id` is set)
  - pledge targets either center+need OR barangay request; status workflow unchanged
- Optional demo seed: `database/migrations/seed_brgy_needs_demo.sql` (mirror `seed_evac_needs_demo.sql`; wipe via `remove_demo_data.sql` — extend it to delete demo brgy requests + their pledges).

## Phase 1 — Web (core) 

1. Request submission
   - `app/assistance/save-brgy-request.php` (new): CSRF + auth (`barangay` role, sub_role captain/secretary), scoped to own barangay via `$_SESSION['barangay_name']`; validate item/unit/qty.
   - `public/request-assistance.php` (new): submit form + list of own requests + pledges received + Confirm Received for Delivered rows.
   - Sidebar: add "Request Assistance" link for `barangay` role menu in `app/includes/sidebar.php`.
2. Board
   - `public/assistance.php` + `api/get_assistance_board.php`: add "Barangay Assistance Requests" section — barangay, item, **Still Needed** (committed-supply math like `pledge_remaining_for_need`), municipality-scoped for MDR sub-roles, province-wide for PHO/superadmin.
   - `app/evacuation-centers/pledge-assistance.php`: accept `brgy_request_id`; fix donor labels to mirror `api/pledge_assistance.php:78-83` (Mayor Kalibo / Mayor Ibajay / Governor / MDRRMO / PDRRMO / PHO / Super Admin).
3. Status + confirmation
   - `app/evacuation-centers/update-assistance-status.php`: handle `brgy_request_id` rows — MDR scope via request `municipality`.
   - `app/evacuation-centers/confirm-assistance-received.php`: when `brgy_request_id` is set, validate actor's barangay matches request `barangay_name`; qty_received rules unchanged.

## Phase 2 — Flutter app (mirror)

4. Services/repo
   - `AssistanceService`: `saveBrgyRequest()`, `pledge(toRequest:)`, board fetch includes requests; `AssistanceRepository` caches requests into existing SQLite store; add request pre-cache step in `offline_sync_coordinator.dart`.
5. API
   - `api/save_brgy_request.php` (new), update `api/pledge_assistance.php` (accept `brgy_request_id`), `api/update_assistance_status.php` (scope via request municipality), `api/confirm_assistance_received.php` (barangay matches request).
6. UI
   - Barangay "Request Assistance" screen (submit + own requests + confirm received).
   - `assistance_board_screen.dart`: barangay-requests section with pledge flow.
7. Verify: `flutter analyze` + `flutter test`.

## Verification (manual)

- Web: login barangay captain (Agbago) → submit request; login `mdr_ibajay`, `mayor_ibajay`, governor → pledge to it; advance Sent → Delivered; barangay confirms received; confirm web ledger shows "Mayor Ibajay" / "Governor" labels.

## Files to touch (summary)

- `database/migrations/add_brgy_assistance_requests.sql` (new)
- `database/migrations/seed_brgy_needs_demo.sql` (new, optional) + extend `remove_demo_data.sql`
- `app/assistance/save-brgy-request.php` (new)
- `public/request-assistance.php` (new)
- `app/includes/sidebar.php`
- `public/assistance.php`, `api/get_assistance_board.php`
- `app/evacuation-centers/pledge-assistance.php`, `update-assistance-status.php`, `confirm-assistance-received.php`
- `api/save_brgy_request.php` (new), `api/pledge_assistance.php`, `api/update_assistance_status.php`, `api/confirm_assistance_received.php`
- `lib/services/assistance_service.dart`, `lib/services/assistance_repository.dart`, `lib/services/offline_sync_coordinator.dart`
- `lib/screens/shared/assistance_board_screen.dart`, new barangay request screen in `lib/screens/barangay/`, `barangay_main_screen.dart`

## Notes

- Touches `api/`, `app/`, `public/`, `database/migrations/` (normally off-limits zones) — explicitly approved for this feature.
- Conventions: CSRF on web POSTs; prepared statements everywhere; `is_demo` flags + `remove_demo_data.sql` wipe; new statuses fail-safe; no comments unless needed.