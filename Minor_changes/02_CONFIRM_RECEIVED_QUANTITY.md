# 02 — Confirm Received Quantity (barangay countersign for delivered donations)

## 1. Purpose

Add a barangay-side **countersign** step: when a donor marks a pledge `Delivered`, it is **not** yet "received". The receiving **barangay Chairman or Secretary** checks the delivery and records the **quantity that actually arrived** (`qty_received`, 1 … the donor's declared qty). Only after this confirmation does the supply count against the centre's needs.

This fixes the gap where a donor could mark something Delivered without proof of arrival, and it enables honest shortfall handling: if fewer items arrived than were declared, the remaining deficit stays "Still Needed" on the board.

## 2. Before / After

| | Before | After |
|---|---|---|
| `Delivered` | supply looked fulfilled | awaiting `received_at` / barangay confirmation |
| Actual count | not captured | `qty_received` (1 … `qty`) recorded per donation, with a shortfall marker |
| Who may confirm | no one | barangay captain/secretary of the centre's own barangay |
| Board/dashboard math | — | `received_qty` = confirmed-arrival total only (see doc 03) |

## 3. Related database objects

Reference migrations (order matters):

```sql
-- database/migrations/add_qty_received_to_evac_assistance.sql
ALTER TABLE `evac_assistance`
  ADD COLUMN `qty_received` int(11) DEFAULT NULL AFTER `qty`;
```

```sql
-- database/migrations/alter_evac_assistance_add_received.sql
ALTER TABLE evac_assistance
  ADD COLUMN received_at timestamp NULL DEFAULT NULL AFTER delivered_at,
  ADD COLUMN confirmed_by_user_id int(11) DEFAULT NULL AFTER received_at,
  ADD KEY idx_received (received_at);
```

Notes:

- `received_at` makes a donation "Received"; the donor-side `status` **stays `Delivered`** (Received is not a new enum value — decision recorded in the migration header).
- No default on `received_at` / `qty_received`: NULL = not yet confirmed.
- **Idempotency:** target DB may already have `qty_received` (e.g. if doc 01's `over_pledge_flag` repair was applied from a newer source). Guard with `information_schema` checks, or drop-and-readd in dev only.
- **Rollback:** `ALTER TABLE evac_assistance DROP COLUMN qty_received, DROP COLUMN confirmed_by_user_id, DROP COLUMN received_at;`

## 4. Related files

- Web handler: `app/evacuation-centers/confirm-assistance-received.php`.
- API handler: `api/confirm_assistance_received.php` (Flutter path).
- Board/consumer queries already assuming the columns: `api/get_assistance_board.php` (§5, doc 03), `public/assistance.php`, `api/get_center_needs.php`, `public/center-needs.php`, `api/get_dashboard_summary.php:435-457`.
- Flutter: `lib/services/assistance_service.dart` (`confirmReceived`), `lib/screens/shared/center_needs_screen.dart` (`_confirmReceived` + `_canConfirmReceived`), `lib/widgets/pledge_ledger_row.dart` (`Confirm Received` button + shortfall chip + `Received` stage chip).

## 5. Backend rules (API + web handlers)

Both handlers enforce the same 6 rules; the difference is web = POST form + `$_SESSION`, API = JSON `acting_user_id`.

1. **Role:** only `role='barangay'` with `sub_role IN ('captain','secretary')`, account `Active` (`api/confirm_assistance_received.php:16-24`; web `confirm-assistance-received.php:16-28`).
2. **Barangay bound:** the actor must have `barangay_id > 0`, and the centre's `barangay` must equal the actor's barangay name (DB-verified via `barangays` lookup) (`api:48-55`, `web:50-58`).
3. **State gate:** the donation must be `status='Delivered'` AND `received_at IS NULL` (`api:44-46`, `web:45-48`).
4. **Quantity validation:** `qty_received` is an integer in `[1, declared qty]` (shortfalls allowed, zero/over not) (`api:58-65`, `web:61-71`).
5. **Atomic, race-safe UPDATE** (double-submit / re-request cannot double-confirm):

```sql
UPDATE evac_assistance
   SET received_at = COALESCE(received_at, NOW()),
       confirmed_by_user_id = ?,
       qty_received = ?
 WHERE id = ? AND received_at IS NULL AND status = 'Delivered';
```

Successful only when `affected_rows = 1` (`api:69-77`, `web:73-87`).

6. **No actor ID sent from client:** the actor is looked up from the session/user id.

Failure modes surface as `denied=1` / `invalid_qty=1` (web) or JSON error with a specific human message (API).

## 6. Web changes

- `public/center-needs.php` ledger table: for rows with `status='Delivered'` and empty `received_at` AND the viewer is a barangay role, render an inline `<input type="number" min="1" max="{qty}" value="{qty}">` + "Confirm Received" submit into `app/evacuation-centers/confirm-assistance-received.php` with `assistance_id`, `center_id`, `qty_received` (`center-needs.php:390-404`). Also render the received-date column and shortfall `(X received)` text (`center-needs.php:382-389`).
- Success/error alerts on the page: `?received=1` and `?invalid_qty=1` banners (`center-needs.php:219-221`).
- `public/assistance.php` ledger: receiving column + shortfall `(X received)` shown when `qty_received != qty` (`assistance.php:340-345`).

## 7. Flutter changes

- `lib/widgets/pledge_ledger_row.dart`:
  - `canConfirm = onConfirmReceived != null && status == 'Delivered' && !isReceived` (gate `center_needs_screen.dart:52-54` `_canConfirmReceived` = barangay captain/secretary).
  - Renders a teal `Confirm Received` button, a teal `Received` stage chip, and (when `qty_received < qty`) an amber `Received X of Y` shortfall chip (`pledge_ledger_row.dart:185-201, 260-291`).
- `lib/screens/shared/center_needs_screen.dart` `_confirmReceived(id, declaredQty, unit)` (lines 193-266): dialog lets the user type `1..declaredQty`, then calls `AssistanceService.confirmReceived`, reloads on success.
- `lib/services/assistance_service.dart.confirmReceived` POSTs `{acting_user_id, assistance_id, qty_received}`.

## 8. Shared calculation rules

Once a donation is confirmed:

- `received_qty` for a need = `SUM(CASE WHEN received_at IS NOT NULL THEN COALESCE(qty_received, qty) ELSE 0 END)` (see `api/get_center_needs.php:92-100`).
- Board needs subquery: `SELECT need_id, SUM(COALESCE(qty_received, qty)) FROM evac_assistance WHERE received_at IS NOT NULL GROUP BY need_id` (`api/get_assistance_board.php:135-136`).
- A **shortfall reopens the need automatically**: unmet becomes `max(0, qty_needed - received_qty)` (shared helper used by board, dashboard `api/get_dashboard_summary.php:453`, and Flutter).
- `pending_qty` = `Delivered` but `received_at IS NULL` (awaiting confirmation).

## 9. Porting procedure

1. Back up DB.
2. Apply the two column migrations (and the `over_pledge_flag` repair from doc 01 §3 where needed; the reference schema also carries it).
3. Copy `app/evacuation-centers/confirm-assistance-received.php` and `api/confirm_assistance_received.php`.
4. Add the inline confirm control + banners to `public/center-needs.php`.
5. Add the Flutter confirm flow (service method + dialog + ledger-row wiring).
6. Run the checklist.

## 10. Verification checklist

- [ ] A **barangay captain** of the centre's own barangay can confirm a `Delivered` donation with a valid qty → `received_at` + `qty_received` + `confirmed_by_user_id` set exactly once (`affected_rows=1`).
- [ ] Confirming with `qty_received < qty` (shortfall) keeps board `unmet` positive; the row shows `Received X of Y`.
- [ ] A **non-barangay** role (e.g. PCF MDR) posting to the confirm endpoint is rejected.
- [ ] A captain of a *different* barangay is rejected.
- [ ] Double-submit/race: second submit is rejected (WHERE guard) — `received_at` unchanged.
- [ ] Board + dashboard + Flutter board all show the received total only after confirmation.

## 11. Completion evidence

Status: **Implemented** in the reference source.

- Both column migrations exist; live schema matches (`qty_received int NULL` after `qty`; `received_at`/`confirmed_by_user_id`/`idx_received` present).
- Both handler variants exist and enforce identical rules; the API variant was exercised in the reference environment (a crafted confirm on a delivered test donation succeeded; the row was cleaned up afterwards).
- Board/dashboard/Flutter consumption of the received rule is present at the lines cited.
- The `over_pledge_flag` repair is a **gap** the reference repo itself does not migrate (see doc 01 §3).