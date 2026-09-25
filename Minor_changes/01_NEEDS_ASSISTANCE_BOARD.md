# 01 — Needs & Assistance Board (center needs + donation ledger)

## 1. Purpose

Give every evacuation centre a **"what it needs"** list and a **"who donated what to where"** (assistance ledger), viewable on a single board by province/city roles.

- **Occupants profile** (`evac_center_profile`): vulnerable-sector counts of who is inside the centre (used later by the dashboard panels).
- **Center needs** (`evac_center_needs`): item + unit + `qty_needed` declared by the centre.
- **Assistance ledger** (`evac_assistance`): every pledge/donation, with donor, qty, and a status lifecycle `Pledged → Sent → Delivered`.

This doc delivers the schema and the CRUD for these three objects, plus the board page/API. The *fulfillment math* is defined in doc 03 (and refined by doc 02).

## 2. Before / After

| | Before | After |
|---|---|---|
| Data model | No per-centre needs/pledges | 3 new tables (profile, needs, ledger) |
| Board | — | Needs & Assistance page (Web) + board screen (Flutter) |
| Actors | — | Superadmin/PHO/PCF (all sub-roles) view board; mayors & Governor included in doc 04 |

## 3. Related database objects

Reference migration: `database/migrations/add_evac_needs_assistance.sql` (run once). It creates, idempotently (`CREATE TABLE IF NOT EXISTS`):

```sql
CREATE TABLE IF NOT EXISTS `evac_center_profile` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evac_center_id` int(11) NOT NULL,
  `total_evacuees` int(11) NOT NULL DEFAULT 0,
  `families` int(11) NOT NULL DEFAULT 0,
  `pregnant` int(11) NOT NULL DEFAULT 0,
  `lactating_mothers` int(11) NOT NULL DEFAULT 0,
  `infants` int(11) NOT NULL DEFAULT 0,
  `children` int(11) NOT NULL DEFAULT 0,
  `older_persons` int(11) NOT NULL DEFAULT 0,
  `pwd` int(11) NOT NULL DEFAULT 0,
  `sick` int(11) NOT NULL DEFAULT 0,
  `injured` int(11) NOT NULL DEFAULT 0,
  `source` enum('manual','computed') NOT NULL DEFAULT 'manual',
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `updated_by` int(11) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_evac_center` (`evac_center_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `evac_center_needs` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evac_center_id` int(11) NOT NULL,
  `item` varchar(150) NOT NULL,
  `unit` enum('packs','sacks','boxes','liters','pcs','kits') NOT NULL DEFAULT 'pcs',
  `qty_needed` int(11) NOT NULL DEFAULT 0,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_evac_center` (`evac_center_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS `evac_assistance` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `evac_center_id` int(11) NOT NULL,
  `need_id` int(11) DEFAULT NULL,
  `donor_user_id` int(11) NOT NULL,
  `donor_label` varchar(120) NOT NULL,
  `item` varchar(150) NOT NULL,
  `unit` enum('packs','sacks','boxes','liters','pcs','kits') NOT NULL DEFAULT 'pcs',
  `qty` int(11) NOT NULL DEFAULT 0,
  `status` enum('Pledged','Sent','Delivered') NOT NULL DEFAULT 'Pledged',
  `pledged_at` timestamp NULL DEFAULT NULL,
  `sent_at` timestamp NULL DEFAULT NULL,
  `delivered_at` timestamp NULL DEFAULT NULL,
  `remarks` varchar(255) DEFAULT NULL,
  `is_demo` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_evac_center` (`evac_center_id`),
  KEY `idx_donor` (`donor_user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
```

Also adds `evacuation_centers.is_demo tinyint(1) NOT NULL DEFAULT 0` (guarded via `information_schema` so re-runs are safe).

> **Important (gap found in reference repo):** the **current** `evac_assistance` table also carries `over_pledge_flag tinyint(1) NOT NULL DEFAULT 0` and (after doc 02) `qty_received`, `received_at`, `confirmed_by_user_id`. Whether `over_pledge_flag` is part of *your* target migration is up to you: it is used by the pledge code in doc 01 §5 and displayed in doc 03. The reference migrations folder has **no** file that adds `over_pledge_flag`; if your backup lacks it, add it yourself:
>
> ```sql
> ALTER TABLE `evac_assistance`
>   ADD COLUMN `over_pledge_flag` tinyint(1) NOT NULL DEFAULT 0 AFTER `remarks`;
> ```

**Rollback:** drop the three tables (`DROP TABLE evac_assistance; DROP TABLE evac_center_needs; DROP TABLE evac_center_profile;`) and (optionally) `evacuation_centers.is_demo`.

**Demo data:** `database/migrations/seed_evac_needs_demo.sql` seeds rows for demo centres; `remove_demo_data.sql` wipes `is_demo = 1` rows. Apply demo seeding only in dev.

## 4. Related files

- API: `api/get_assistance_board.php`, `api/get_center_needs.php`, `api/save_center_needs.php`, `api/pledge_assistance.php`.
- Web: `public/assistance.php`, `public/center-needs.php`, `app/evacuation-centers/save-center-needs.php`, `app/evacuation-centers/pledge-assistance.php`.
- Helpers: `app/includes/functions.php` → `can_view_assistance()`, `can_manage_evacuation_centers()`, `center_status_allowlist()`, `credited_incident_statuses()`, `credited_incident_for_center()`, `computed_headcount_for_center()`, `pledge_remaining_for_need()`.
- Flutter: `lib/services/assistance_service.dart`, `lib/screens/shared/assistance_board_screen.dart`, `lib/screens/shared/center_needs_screen.dart`, `lib/widgets/need_progress_bar.dart`, `lib/widgets/fulfilled_chip.dart`, `lib/widgets/pledge_ledger_row.dart`.

## 5. Backend rules (API layer + helpers)

**Actor checks** (mirrored in `get_assistance_board.php:15-27`, `get_center_needs.php:15-29`, `pledge_assistance.php:12-25`):

- Board: `role ∈ {superadmin, pho, pcf}` and `status = 'Active'`. Everyone who can view the board can also pledge (`can_pledge = true`, `get_assistance_board.php:29`; helper `can_pledge_assistance()` = `can_view_assistance()` in `functions.php:529-531`).
- Center-needs: same three roles **plus** barangay `captain`/`secretary` (own barangay only).
- Pledge: same three roles only.

**Municipality scope** (`get_assistance_board.php:35-59`, `pledge_assistance.php:46-52`):

- `pcf` sub-role `mdr_kalibo`/`mayor_kalibo` → forced to `Kalibo`; `mdr_ibajay`/`mayor_ibajay` → forced to `Ibajay`.
- Everyone else uses the input `municipality` filter (empty = all).
- The API **re-checks the DB sub_role** (defense in depth, `get_assistance_board.php:50-59`; `pledge_assistance.php:46-52`).

**Zero-pledge centres** (`get_assistance_board.php:62-70`):

```sql
SELECT ec.id, ec.center_name, ec.barangay, ec.municipality, ec.status
FROM evacuation_centers ec
WHERE (EXISTS (SELECT 1 FROM evac_center_profile p WHERE p.evac_center_id = ec.id)
    OR EXISTS (SELECT 1 FROM evac_center_needs n WHERE n.evac_center_id = ec.id))
  AND NOT EXISTS (SELECT 1 FROM evac_assistance a WHERE a.evac_center_id = ec.id)
  AND ec.status IN ('Open','Full','Needs Supplies','Available')
ORDER BY ec.municipality ASC, ec.barangay ASC, ec.center_name ASC;
```

`center_status_allowlist()` (`functions.php:203-205`) => `['Open','Full','Needs Supplies','Available']`. `Closed` is deliberately excluded.

**Credibility/Incident link** (`credited_incident_for_center`, `functions.php:207-223`): a centre's needs are "verified" if it has a linked incident in `credited_incident_statuses()` = `['Forwarded to PCF','Under MDR Review','Verified','Responding','Referred to PHO','Under PHO Review','Resolved']` (`functions.php:192-194`).

**Pledge insert** (`api/pledge_assistance.php`, web twin `app/evacuation-centers/pledge-assistance.php`):

- Unit allowlist `['packs','sacks','boxes','liters','pcs','kits']`.
- `need_id` must belong to the pledged centre (else nulled).
- **Soft over-pledge flag (warn, never block):** `over_pledge_flag = (qty > pledge_remaining_for_need(need_id)) ? 1 : 0` (`functions.php:538-554`; `pledge_assistance.php:58-71`). The remaining-committed calculation is defined in doc 03 §8.
- Donor label is set server-side and never trusted from the client:
  - web (`pledge-assistance.php:66-80`): PCF → `MDRRMO <muni>` / `MDR Admin` / `Municipal Office`; PHO → `PDRRMO` / `PHO Provincial Health Office`; else `Super Admin`.
  - API (`pledge_assistance.php:74-87`): additionally `Mayor Kalibo`, `Mayor Ibajay`, `Governor` (see doc 04).

**Save needs (upsert semantics)** (`app/evacuation-centers/save-center-needs.php` and `api/save_center_needs.php`):

- Profile: `INSERT … ON DUPLICATE KEY UPDATE` keyed by `evac_center_id`; `source` stays `manual` unless the user explicitly clicked "Fill Reported Totals" (`computed`).
- Needs: match existing rows by **lowercased item name** and UPDATE in place (keep row ids — `evac_assistance.need_id` references them). Delete only rows removed from the submitted list. Wrapping in a transaction (`mysqli_begin_transaction`).
- Scoping: barangay chairman limited to own barangay; MDR sub-roles to own municipality (web `save-center-needs.php:26-40`).

## 6. Web changes

- `public/assistance.php`: board page. Gates with `can_view_assistance()`; pledge buttons gated by `can_pledge_assistance()`. Zero-pledge banner, needs table (`Item | Unit | Needed | Received | Incoming / Awaiting Confirmation | Still Needed | Action`), per-centre collapsible ledger (`Who donated what to where`), pledge bootstrap modal whose submit handler fires a soft over-pledge `confirm()` when `qty > data-remaining` (`assistance.php:435-480`; `data-remaining = max(0, qty_needed - received_qty - incoming_qty)`, `assistance.php:251`).
- `public/center-needs.php`: per-centre edit screen. Gates with `can_manage_evacuation_centers()` (`functions.php:171-177`). Occupants profile inputs, need rows (`N_item[]`, `N_qty[]`, `N_unit[]`), "Fill Reported Totals" JS that sets `N_profile_source=computed` (`center-needs.php:342-356`). Fulfillment table + donations ledger rendered read-only (Confirmation to be added by doc 02).
- `app/evacuation-centers/save-center-needs.php` and `pledge-assistance.php`: the POST targets above (CSRF-verified via `csrf_verify()`; redirected back to their page with a status flag).

## 7. Flutter changes

- `lib/services/assistance_service.dart`: `getCenterNeeds()`, `saveCenterNeeds()`, `getBoard()`, `pledge()` — all POST to the APIs with `acting_user_id: AuthService.currentUserId`.
- `lib/screens/shared/assistance_board_screen.dart`: loads the board, renders summary chips (`Unmet/Incoming/Awaiting/Pledges/My Pledges`), zero-pledge banner, search + "Unmet only" chip, urgency-sorted centre tiles (red = unmet with no incoming, yellow = unmet with incoming, green = all met; see `_urgencyFor`/`_sortedCenters`), expandable centre detail (`Who's inside`, `Center Needs`, `Assistance Ledger`), pledge dialog with the same soft over-pledge warning as the web (`assistance_board_screen.dart:202-226`).
- `lib/screens/shared/center_needs_screen.dart`: form screen; profile fields; need rows; computed/banner logic; report-totals prefill.
- `lib/widgets/need_progress_bar.dart` + `lib/widgets/fulfilled_chip.dart`: shared progress bar and green `Fulfilled` chip (colour/green semantics documented in doc 03).

## 8. Shared calculation rules (board math at this doc's level)

> Doc 02 refines the "received" definition. At **this** doc's level the reference code is written as **received = `SUM(qty) WHERE received_at IS NOT NULL`** already assumes doc 02 is applied. If you apply 01 before 02, keep the board queries' `received_qty` subquery but note it will show 0 until doc 02 is in place (there is no `received_at` yet). To be explicit, the final (post-02) rules, already in the reference source:

- `received_qty` per need = `SUM(COALESCE(qty_received, qty))` over rows where `received_at IS NOT NULL`.
- `pending_qty` = `SUM(qty)` where `status='Delivered' AND received_at IS NULL`.
- `incoming_qty` = `SUM(qty)` where `status IN ('Pledged','Sent')`.
- `unmet = max(0, qty_needed - received_qty)`; `fulfilled = qty_needed > 0 AND received_qty >= qty_needed`.
- `pledge_remaining_for_need()` (capacity guard) counts **all committed** supply: `SUM(CASE WHEN received_at IS NOT NULL THEN qty_received ELSE qty END)` over `status IN ('Pledged','Sent','Delivered')`, subtracted from `qty_needed`, floored at 0.
- Summary totals on the board: `unmet_total`, `incoming_total` (Pledged+Sent), `pending_confirmation_total` (Delivered unconfirmed), `pledge_count`, `my_pledges` (rows by the actor), `zero_pledge_count`.

## 9. Porting procedure

1. Back up the DB (§9 in doc 00).
2. Run the schema migration (`add_evac_needs_assistance.sql`), plus the `over_pledge_flag` ALTER if needed (see §3 gap note).
3. Add the three helper functions to `app/includes/functions.php` if missing (`center_status_allowlist`, `credited_incident_statuses`, `credited_incident_for_center`, `computed_headcount_for_center`, `can_view_assistance`, `can_pledge_assistance`, `can_manage_evacuation_centers`, `pledge_remaining_for_need`).
4. Add the two web POST handlers (`save-center-needs.php`, `pledge-assistance.php`) and the two web pages (`assistance.php`, `center-needs.php`).
5. Add the API endpoints (copy from `api/`), keeping the CORS headers already present in the reference files (`Access-Control-Allow-*`; these only matter if the target will also have the Flutter app calling through a browser).
6. Add the Flutter service methods + screens + widgets (paths in §4/§7).
7. Verify per §10.

## 10. Verification checklist

- [ ] DB: three tables exist; `evacuation_centers.is_demo` added (or your selected variant).
- [ ] Superadmin saves profile + 2 needs items on a centre via web; the row ids are stable when the same item name is edited again (upsert, not delete/reinsert).
- [ ] PCF MDR-Kalibo pledges on a Kalibo centre; a pledge to an Ibajay centre is rejected.
- [ ] Barangay secretary (non-captain) can open own centre needs; a chairman can open only own barangay's centre.
- [ ] `/api/get_assistance_board.php` returns `success:true` with `centers`, `ledger`, `zero_pledge_centers`, `summary`.
- [ ] Flutter board renders centres + pledge dialog; `flutter analyze` clean.
- [ ] Pledging more than the remaining committed amount sets `over_pledge_flag=1` but still succeeds with a warning.

## 11. Completion evidence

Status: **Implemented** in the reference source.

- `add_evac_needs_assistance.sql` exists and matches live schema for the three base tables.
- All board CRUD endpoints and web pages exist and were verified working through Apache in the reference environment (`get_assistance_board.php` returned 200/full data; pledge inserted and then cleaned before handover).
- The `over_pledge_flag` column is used but has **no migration file** in the repo (gap documented in §3) — a deviation a porting agent must reconcile on the target DB.
- Doc 02 adds the `qty_received`/`received_at` columns the board math already assumes.