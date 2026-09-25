# 05 — Pledge Status Ownership (who may advance a pledge's status)

## 1. Purpose

Define and enforce **who may advance a pledge's status** (`Pledged → Sent`, `Sent/Delivered → Delivered`) on the assistance board. Without this, any viewer could edit anyone's delivery record. The enforced policy below applies to the **web POST path**, the **JSON API path**, and the **UI** (buttons/menus) — hiding the button is necessary but not sufficient: direct POST/API requests must also be rejected server-side.

## 2. Before / After

| Who | Before (target of change) | After (final policy) |
|---|---|---|
| The **donor** themselves | any viewer could act | May advance their own pledge, and only theirs |
| **Governor** | any viewer | May advance **only their own** pledges (not provincial override) |
| **Mayor** (`mayor_*`) | any viewer | May advance **only their own** pledges (and only in their town) |
| Every other ordinary donor role | any viewer | May advance **only their own** pledges |
| **PHO Admin** (empty sub_role) | — | Full operational override (any pledge, municipality, province-wide for PHO) |
| **PDRRMO** | — | Full operational override (any pledge, municipality) |
| **Superadmin** | — | Full operational override (any pledge) |

The same rule also drives the **read-only visibility** of the status buttons in the UI, the Flutter `⋯` menu, and the API `can_manage_status` flag on each ledger row.

## 3. Related database objects

**None.** Pure behavioural change over doc 01/02 data (`evac_assistance`: `donor_user_id`, `status`, `sent_at`, `delivered_at`). No ALTER.

## 4. Related files

- API: `api/update_assistance_status.php` (the authoritative enforcer).
- Web: `app/evacuation-centers/update-assistance-status.php` (session twin), `public/assistance.php` (button rendering).
- Board flag: `api/get_assistance_board.php:192-210` (`can_manage_status`).
- Helpers: `app/includes/functions.php` (`can_pledge_assistance`, `mdr_municipality`, `mayor_municipality`).
- Flutter: `lib/widgets/pledge_ledger_row.dart` (`canManage` gate), `lib/screens/shared/assistance_board_screen.dart` (invokes `onUpdateStatus` only when the callback is wired), `lib/services/assistance_service.dart` (`updateStatus`).

## 5. Backend rules (authoritative)

**Role + state gate** (identical in both handlers):

- Actor must be `Active` and `role ∈ {superadmin, pho, pcf}` (`api/update_assistance_status.php:12-24`, web `update-assistance-status.php:8-11`).
- The donation must exist; a `pcf` actor may only advance statuses inside their own municipality.

**Ownership rule** (`api/update_assistance_status.php:45-50`, web `update-assistance-status.php:36-42`):

```php
$V_prov_override = ($V_role === 'superadmin')
    || ($V_role === 'pho' && strtolower(trim((string)$V_sub_role)) !== 'governor');

if ((int)$donation['donor_user_id'] !== $acting_user_id && !$V_prov_override) {
    // reject
}
```

Read carefully — `strtolower(...) !== 'governor'` means "every PHO account **except the Governor**": PHO Admin (empty sub_role) and PDRRMO are overrides; the **Governor is NOT**. Mayors (`pcf` `mayor_*`) never satisfy the override, so they are donor-only. This exactly implements the §2 policy everywhere.

**Transition rules** (both handlers):

- `send`: allowed only from `status='Pledged'`; sets `status='Sent'`, `sent_at = COALESCE(sent_at,NOW())` (NULL-safe: a re-submit cannot rewrite history).
- `deliver`: allowed from `Pledged` or `Sent` (never re-deliver an already-`Delivered` row); sets `status='Delivered'`, `sent_at`/`delivered_at` both `COALESCE(...,NOW())`.
- Anything else → reject.

**Match the same flag on the board payload** (`api/get_assistance_board.php:203`):

```php
"can_manage_status" => ($is_donor || $V_prov_override) && $V_can_pledge,
```

## 6. Web changes

- `public/assistance.php`: ledger rows compute `$V_can_update_row = $V_prov_override || (int)$donation['donor_user_id'] === $V_acting_user_id;` and render the `Mark Sent` / `Deliver` buttons **only when `$V_can_pledge && $V_can_update_row`** (`assistance.php:335, 346`). Rows the actor cannot update show `—` instead of buttons. This is UI; the buttons alone are not the security boundary.
- `app/evacuation-centers/update-assistance-status.php`: enforces the ownership rule again, so a crafted POST by a Mayor targeting a PDRRMO pledge is rejected with a redirect to `assistance.php?denied=1` (web) / JSON error (API).
- Municipality note: the web handler scopes `pcf` only via `mdr_municipality()` (MDR sub-roles). Mayor sub-roles are not hard-scoped on the web POST (their board is already town-scoped; see doc 04 §5 divergence note), whereas the **API** hard-scopes both MDR and Mayor sub-roles (`api/update_assistance_status.php:37-43`). Keep parity by copying the API checks if you harden the web path.

## 7. Flutter changes

- `lib/widgets/pledge_ledger_row.dart`: the `⋯` menu renders only when `onUpdateStatus != null && row['can_manage_status'] == true` (`pledge_ledger_row.dart:178-179, 219`). So the server's per-row flag already hides it for a Governor looking at a PDRRMO pledge. Menu items: `Mark Sent` when `Pledged`, `Mark Delivered` when `Pledged|Sent` (`pledge_ledger_row.dart:228-240`).
- `lib/services/assistance_service.dart.updateStatus`: POSTs `{acting_user_id, assistance_id, action}` — a malicious Flutter build cannot bypass the server rule either.

## 8. Shared rules (single source of truth)

- **Override set** = `superadmin` OR (`pho` and sub_role ≠ `governor`). Stated once, used in 3 places (web handler, API handler, board payload).
- **Ordinary actor** may act on a row iff `donor_user_id == acting_user_id`; overrides may act on any row (within municipality scope for MDR/Mayor sub-roles).
- **Never let the client decide `can_manage_status`**; derive it from donor + override server-side.
- UI hiding is complementary, never authoritative.

## 9. Porting procedure

1. Ensure docs 01 (board + ledger) are in place; 04 if you want Mayor/Governor roles.
2. Copy/port `update-assistance-status.php` (web + API) wholesale from the reference paths in §4.
3. Ensure `$V_prov_override` and the per-row flag exist in `get_assistance_board.php` and `public/assistance.php` exactly as shown.
4. In the Flutter code, keep the `⋯` menu gated on `can_manage_status`; do not add status controls elsewhere.
5. Grep the ported tree for any other place that writes `evac_assistance.status` (e.g. a stray admin form) and route it through the same guard.
6. Run the checklist, including the **direct-POST** tests (§10), not just the UI tests.

## 10. Verification checklist

- [ ] Donor `D` pledges; `D` can mark Sent then Delivered; `received_at` untouched by these actions.
- [ ] A **second PCF MDR user** cannot mark `D`'s pledge (UI hides + direct POST → `denied=1`/JSON error).
- [ ] **Mayor** cannot mark a PDRRMO/other donor's pledge even with a crafted POST.
- [ ] **Governor** cannot mark a PDRRMO/PHO pledge with a crafted POST (unique case — Governor is in `role=pho` but explicitly excluded from the override by `!== 'governor'`).
- [ ] Governor CAN mark its own pledge.
- [ ] **PHO Admin** and **PDRRMO** CAN mark anyone's pledge (any municipality).
- [ ] **Superadmin** CAN mark anyone's pledge.
- [ ] A `send` on an already-`Sent` row is rejected; a `deliver` on an already-`Delivered` row is rejected; `sent_at`/`delivered_at` do not change on re-submit (NULL-safe).
- [ ] Flutter: Mayor/Governor see no `⋯` menu on others' rows; see it on their own.

## 11. Completion evidence

Status: **Implemented** in the reference source. This is the user-requested "especially precise" section, so the evidence is exact:

- `api/update_assistance_status.php:45-50` — override + ownership reject (`send_response(false, "Only the donor or a provincial/superadmin user may update this status.")`).
- `app/evacuation-centers/update-assistance-status.php:36-42` — identical session-based enforcement.
- `api/get_assistance_board.php:203` — `can_manage_status` flag parity.
- `public/assistance.php:335, 346` — UI gates buttons by the same predicate.
- `lib/widgets/pledge_ledger_row.dart:178-179, 219-240` — Flutter menu gated on `can_manage_status`, transitions match the backend.
- The Governor exclusion (`!== 'governor'`) is present in **all** copies of the predicate — verified by line matching across web/API/board payload.
- **Caveat:** ownership semantics verified by source read; the "crafted direct POST rejected" tests were exercised for the general not-owner rejection in the reference environment but the Mayor/Governor matrix assumes the role accounts exist (they come from doc 04's role migrations).