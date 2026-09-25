# 03 — Fulfilled Indicator, Progress Bar & Ledger (fulfillment math)

## 1. Purpose

Standardise, everywhere it appears, how "fulfilled" is computed and displayed for a centre need:

- the `Fulfilled` chip + green highlight on a row when a need is fully satisfied,
- the at-a-glance progress bar (`Received X / needed Y`, unmet Z),
- the `X of Y needs fully met` summary,
- the per-donation **ledger row** with the Pledged/Sent/Delivered/Received stage trail and shortfall badge,
- the board's per-centre `N Needs Open` / `Fully Supplied` chips and the "urgency" sort.

The defining rule (from doc 02): **only barangay-confirmed supply counts** (`received_at` set, `qty_received` used). A second, deliberately different number also exists: the **pledge-capacity guard** that prevents over-stacking pledges. This doc documents both so a porter reproduces them exactly and understands why they differ.

## 2. Before / After

| Display | Before | After |
|---|---|---|
| Fulfilled | Based on Sent/Delivered statuses | Based on confirmed `received_qty >= qty_needed` |
| Progress bar | none/naive | `received/needed`, red unmet / green fulfilled, `incoming` line |
| Ledger row | simple status text | Stage trail (Pledged→Sent→Delivered→Received) + shortfall + Over-pledge chips |
| Board row chips | none | `Fully Supplied`, `N Needs Open`, urgency sort (red/yellow/green) |
| Pledge guard | none | `pledge_remaining_for_need()` (committed supply, warn-only) |

## 3. Related database objects

**None new.** Relies on doc 01 schema + doc 02 columns (`qty_received`, `received_at`, `confirmed_by_user_id`, `over_pledge_flag`). Consumers:

- `api/get_assistance_board.php:126-143` (needs subqueries + aggregation),
- `api/get_center_needs.php:92-117` (per-need pledged/sent/delivered/received + helpers),
- `api/get_dashboard_summary.php:435-457` (unmet totals use the same received rule),
- `public/assistance.php:58-73`, `public/center-needs.php:93-101`.

No ALTER is required. If the DB lacks `over_pledge_flag`, apply the repair from doc 01 §3 before wiring this doc's chips.

## 4. Related files

- PHP: `app/includes/functions.php` (`pledge_remaining_for_need`, `center_status_allowlist`, badge helpers), the four board/needs consumers above, `public/assistance.php`, `public/center-needs.php`.
- Flutter: `lib/widgets/need_progress_bar.dart`, `lib/widgets/fulfilled_chip.dart`, `lib/widgets/pledge_ledger_row.dart`, `lib/screens/shared/assistance_board_screen.dart`, `lib/screens/shared/center_needs_screen.dart`.

## 5. Backend rules

The board JSON already computes the fields the client renders; the client rarely recomputes. Server responsibilities:

- Needs payload per need (`get_assistance_board.php:175-187`): `qty_needed`, `received_qty`, `pending_qty`, `incoming_qty`, `unmet`, `fulfilled`.
- Ledger payload per donation (`get_assistance_board.php:192-210`): `status`, `qty`, `qty_received`, `received_at`, `over_pledge`, `can_manage_status`, `pledged_at`/`sent_at`/`delivered_at`, `for_item`, `donor_label`.
- Center-needs payload (`get_center_needs.php:106-114`): `pledged`, `sent`, `delivered`, `received`, `helpers` (GROUP_CONCAT of distinct `donor_label`).

## 6. Web changes

`public/assistance.php`:

- Needs row: highlight `background:rgba(25,135,84,0.08)` when `fulfilled`; a `Fulfilled` badge (`badge-soft-success`); the progress track `<div class="need-fill">` width `= min(100, round(received/needed*100))%`, green fill when fulfilled (`assistance.php:246-296`).
- Column `Still Needed`: shows `Fulfilled` badge or `unmet` (`assistance.php:278-284`);
- `data-remaining` on the pledge button = `remaining_committed = max(0, qty_needed - received_qty - incoming_qty)` (the number the JS over-pledge `confirm()` compares against) (`assistance.php:251`, `435-480`).
- Center header chips: `Fully Supplied` when `received_qty >= qty_needed` for all needs, else `N Needs Open` (only unmet needs count) (`assistance.php:207-222`).
- Ledger table: status badge colours `Pledged→badge-soft-secondary`, `Sent→badge-soft-info`, `Delivered→badge-soft-success`; plus `Received` (success) and `Over-pledge` (warning) badges; shortfall `(X received)` next to qty (`assistance.php:338-345`).

`public/center-needs.php`:

- `X of Y needs fully met` banner (`center-needs.php:234-238`; count logic `178-186`).
- Who's-helping table with `Needed/Pledged/Sent/Delivered/Received/Helpers` (`center-needs.php:414-456`) — explicitly labelled: *"Only supplies the barangay has confirmed Received reduce what's still needed."*
- Fulfilled row highlight + badge in both the needing table and the who's-helping table.

## 7. Flutter changes

- `lib/widgets/need_progress_bar.dart`: the single progress bar implementation. Progress = `(received/needed).clamp(0,1)`, red when not fulfilled, green when fulfilled; outputs `Received X / needed Y unit · unmet Z` and, when `incoming > 0`, `Incoming (pledged): X unit` (`need_progress_bar.dart:33-73`).
- `lib/widgets/fulfilled_chip.dart`: green `Fulfilled` pill (never shown for delivered-but-unconfirmed).
- `lib/widgets/pledge_ledger_row.dart`: stage trail built from `pledged_at/sent_at/delivered_at/received_at` (nulls filtered), shortfall chip `Received X of Y` when `isReceived && qtyReceived>0 && qtyReceived<qty`, `Over-pledge` chip from `over_pledge` (`pledge_ledger_row.dart:80-122, 187-201, 260-293`).
- `lib/screens/shared/assistance_board_screen.dart`: summary row (`Unmet/Incoming/Awaiting/Pledges/My Pledges`), `Fully Supplied` chip when `openNeeds == 0` else `N Needs Open`, urgency dot + sort (`_urgencyFor`, `_sortedCenters`: red = unmet with `incoming_qty == 0`, yellow = unmet with incoming, green = all met; then municipality → barangay → centre name) (`assistance_board_screen.dart:349-550`).
- `lib/screens/shared/center_needs_screen.dart`: `_needFulfilled(id, qtyNeeded)` returns `received >= qtyNeeded` using the server `fulfillment[].received`; the `X of Y needs fully met` banner; per-need progress bar under each editable row; who's-helping panel cells (`Needed/Pledged/Sent/Delivered/Received`) (`center_needs_screen.dart:56-74, 421-467, 563-700`).

## 8. Shared calculation rules (authoritative table)

| Quantity | Formula | Source |
|---|---|---|
| `received_qty` (need) | `SUM(COALESCE(qty_received, qty))` where `received_at IS NOT NULL` | board/needs/dashboard |
| `pending_qty` | `SUM(qty)` where `status='Delivered' AND received_at IS NULL` | board |
| `incoming_qty` | `SUM(qty)` where `status IN ('Pledged','Sent')` | board/Flutter |
| `unmet` / Still Needed | `max(0, qty_needed - received_qty)` | board + dashboard + Flutter |
| `remaining_committed` (pledge button) | `max(0, qty_needed - received_qty - incoming_qty)` | web row `data-remaining`, Flutter `_NeedRow` (`assistance_board_screen.dart:903-904`) |
| `fulfilled` (display) | `qty_needed > 0 && received_qty >= qty_needed` | everywhere |
| `pledge_remaining_for_need` (guard) | `max(0, qty_needed - SUM(CASE WHEN received_at IS NOT NULL THEN qty_received ELSE qty END))` over `status IN ('Pledged','Sent','Delivered')` | `functions.php:538-554`; used by both pledge handlers to flag over-pledge |

**Why the two differ (documented in `functions.php:533-537`):** the guard is *stricter* (counts every committed unit, including still-Pledged) so you cannot stack pledges so that total committed supply exceeds the declared need, even before anything ships. The board display keeps rescue-view realism by only dropping `received` from unmet. Do not "merge" them into one number — they serve different purposes and both are intentional.

## 9. Porting procedure

1. Ensure docs 01 + 02 are applied (columns and consumers present).
2. Port `pledge_remaining_for_need()` into `app/includes/functions.php`.
3. Port the web rendering blocks (assistance.php needs/ledger tables; center-needs.php banners + who's-helping table).
4. Port the Flutter widgets and board math exactly, name-for-name with the payload fields above.
5. Check every place `qty_needed - received` is computed uses confirmed `received` only (grep the ported tree for `status IN ('Sent','Delivered')` in board queries — it must have been replaced by the `received_at` rule).
6. Run the checklist.

## 10. Verification checklist

- [ ] Board: pledge 3 of needed 10 → `unmet` stays 10, `incoming_qty=3`; mark Sent, then Delivered → `unmet` still 10, `pending_qty=3`; captain confirms `qty_received=3` → `received_qty=3`, `unmet=7`, `pending_qty=0`.
- [ ] Same needle: confirm `qty_received=10` → row turns green + `Fulfilled` chip; board header shows `Fully Supplied`.
- [ ] Pledge 15 on the same need → success but `over_pledge_flag=1` and an `Over-pledge` chip on the ledger row.
- [ ] Shortfall: confirm 4 of declared 10 → `Received 4 of 10` chip + `unmet=6` after subtracting prior confirmed.
- [ ] Flutter progress bars and summary chips match the numbers printed on the web page for the same DB state.
- [ ] Dashboard `unmet` totals match the board's `unmet_total`.

## 11. Completion evidence

Status: **Implemented** in the reference source.

- All widgets/panels/quotations verified against the files and lines cited (`need_progress_bar.dart`, `fulfilled_chip.dart`, `pledge_ledger_row.dart`, both screens, `functions.php`, both board/needs consumers, dashboard summary).
- The two intentionally-different numbers exist exactly as described; the discrepancy is documented *in-code* (`functions.php:533-537`).
- Not verified here: a fresh rendering pass of the Flutter board against a **ported** DB (no second environment); the reference environment used a local dev copy where the board was exercised during Phase 1 verification.