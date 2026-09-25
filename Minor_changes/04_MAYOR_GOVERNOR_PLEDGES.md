# 04 — Mayor & Governor Pledges (read-only observers gain pledge rights)

## 1. Purpose

Previously-created **observer sub-roles** — the two town Mayors (PCF: `mayor_kalibo`, `mayor_ibajay`) and the Aklan Governor (PHO: `governor`) — were strictly read-only. This change lets them **donate/pledge assistance** on the Needs & Assistance board, while they remain **fully read-only everywhere else** (users, centres, report statuses, alerts, hotlines). Provincial operational staff (PHO Admin, PDRRMO) and municipal MDR remain as before.

## 2. Before / After

| Role/sub-role | Before | After |
|---|---|---|
| Mayor (PCF `mayor_*`) | read-only viewer on board | can **pledge** own-municipality only; still read-only elsewhere |
| Governor (PHO `governor`) | read-only viewer | can **pledge** province-wide; still read-only elsewhere |
| PHO Admin / PDRRMO | pledge | pledge (unchanged) |
| Donor labels | — | `Mayor Kalibo`, `Mayor Ibajay`, `Governor` shown on ledger |

## 3. Related database objects

The observer accounts come from role sub-role migrations (delivered before this change, but ported together here because the pledge code depends on the enum values):

- `database/migrations/add_pcf_mdr_subroles.sql` — adds the PCF MDR sub-roles (`mdr_admin`, `mdr_kalibo`, `mdr_ibajay`).
- `database/migrations/add_mayor_subroles.sql` — extends the `users.sub_role` enum with `mayor_kalibo`, `mayor_ibajay` (PCF).
- `database/migrations/add_pho_pdrrmo_subrole.sql` — adds `pdrrmo`.
- `database/migrations/add_governor_role.sql` — adds `governor`, restores the `pdrrmo` enum value inside the same ALTER, and (optionally) sets the existing PDRRMO account's `sub_role` to `pdrrmo`.

Apply order matters: `add_pcf_mdr_subroles` → `add_mayor_subroles` → `add_governor_role` (the governor migration re-modifies the same `users.sub_role` enum and includes values from the earlier ones).

Final `users.sub_role` enum (current live): `captain, secretary, tanod, mdr_admin, mdr_kalibo, mdr_ibajay, pdrrmo, governor, mayor_kalibo, mayor_ibajay`.

**No table changes in this doc.** The migration statements themselves are referenced by filename rather than pasted (they also create demo accounts; those credentials are out of scope — see doc 00 §6).

## 4. Related files

- Helpers: `app/includes/functions.php` → `can_view_assistance()`, `can_pledge_assistance()`, `is_readonly_role()`, `mdr_municipality()`, `mayor_municipality()`, `get_effective_municipality()`, `role_name()`, `sub_role_name()`, `can_manage_*()` gates.
- Web board + pledge: `public/assistance.php`, `app/evacuation-centers/pledge-assistance.php` (donor labels).
- API: `api/get_assistance_board.php`, `api/pledge_assistance.php` (scope + donor labels), `api/update_assistance_status.php` (see doc 05).
- Flutter: `lib/services/auth_service.dart` (`isMayor`, `isGovernor`, `isReadOnlyObserver`, `effectiveMunicipality`, `isPcfMdr`, `isPhoAdmin`, `isPdrrmo`), `lib/screens/shared/assistance_board_screen.dart` (uses server `can_pledge`).

## 5. Backend rules

**Pledge right** (`functions.php:527-531`):

```php
function can_pledge_assistance($V_role, $V_sub_role = '') {
    return can_view_assistance($V_role); // superadmin || pho || pcf
}
```

So `can_view_assistance('pcf')` and `can_view_assistance('pho')` — which include mayors and Governor — return true for pledging. `can_view_assistance()` itself is unchanged (`superadmin/pho/pcf`), so barangay roles still never see the board.

**Read-only pinning** (so pledging is their ONLY write): `is_readonly_role()` (`functions.php:1031-1034`):

```php
return ($V_role === 'pcf' && in_array($V_sub_role, ['mayor_kalibo','mayor_ibajay'], true))
    || ($V_role === 'pho' && $V_sub_role === 'governor');
```

`is_readonly_session()` feeds every `can_manage_*()` gate (`functions.php:147-177, 554-568`), so a Mayor/Governor session is blocked from: report status updates, hotline CRUD, evacuation-centre CRUD, user management, `can_manage_evacuation_centers`. `public/center-needs.php` and `api/save_center_needs.php` also reject these sub-roles (doc 01 §5).

**Municipality scope for pledges / board** (`functions.php:1037-1059`; enforcement in `api/pledge_assistance.php:46-52` and `api/get_assistance_board.php:35-59`):

- `mayor_kalibo` / `mdr_kalibo` → forced `Kalibo`; `mayor_ibajay` / `mdr_ibajay` → forced `Ibajay`; Governor (`pho`) → province-wide / no forced scope.
- API intentionally re-reads the DB sub_role (defence in depth).

**Donor labels** — server-authoritative, never from the client:

- Web POST `pledge-assistance.php:66-80`: PCF MDR → `MDRRMO <muni>` / `MDR Admin` / `Municipal Office`; PHO → `PDRRMO` / `PHO Provincial Health Office`; else `Super Admin`.
- API `pledge_assistance.php:74-87` adds the observer labels: `Mayor Kalibo`, `Mayor Ibajay`, `Governor`.

> Divergence note (documented for a reason): the *web* pledge/status POST only enforces the **PCF MDR** municipality (`mdr_municipality()`), not the Mayor's forced town. A Mayor is kept inside their town on the web because the board itself is scoped via `get_effective_municipality()` (which *does* map Mayors) — so they only see and can pledge to their own town's centres through the UI. The **API** additionally hard-blocks cross-town pledges at the handler level. If you harden the web path too, mirror the checks from `api/pledge_assistance.php:46-52`.

## 6. Web changes

- `public/assistance.php:15-18`: `$V_can_pledge = can_pledge_assistance($role,$sub_role)`; `$V_board_muni = get_effective_municipality($role,$sub_role)` (now returns a Mayor's forced town). Read-only banner ("you can view but not pledge") is only shown to roles that cannot pledge — none of the board viewers anymore.
- Sidebar/menus: Mayor/Governor menus already forbid everything else via the `can_manage_*` gates; no new menu entry is required, only the board stays reachable.

## 7. Flutter changes

- `lib/services/auth_service.dart`: sub-role mirrors of the server helpers — `isMayorKalibo`, `isMayorIbajay`, `isMayor`, `isGovernor`, `isMdrKalibo`, `isMdrIbajay`, `isPcfMdr`, `isPhoAdmin`, `isPdrrmo`, `isReadOnlyObserver`. `effectiveMunicipality` forces `Kalibo`/`Ibajay` for the Mayor sub-roles too (`auth_service.dart:36-45`).
- `lib/screens/shared/assistance_board_screen.dart` already derives its pledge button from the API's `can_pledge` flag (`assistance_board_screen.dart:279`), so Mayors/Governor get the Pledge UI automatically once the backend returns `can_pledge: true` (it does — see `get_assistance_board.php:29`).
- No navigation change: these users reach the board the same way they already reach read-only data.

## 8. Shared rules

- Pledge rights are a pure function of **`role ∈ {superadmin,pho,pcf}`** (all sub-roles).
- "Read-only observer" is a pure function of **(`pcf` + mayor sub-roles) OR (`pho` + governor)**.
- Mayor scope is **`Kalibo↔mayor_kalibo`, `Ibajay↔mayor_ibajay`** (same mapping as the MDR twins); Governor has **no** scope.
- These rules must be identical on backend and Flutter (`auth_service.dart` mirrors `functions.php`).

## 9. Porting procedure

1. Apply sub-role migrations in the dependency order listed in §3.
2. Port/verify `can_pledge_assistance()`, `is_readonly_role()`, `mayor_municipality()`, `get_effective_municipality()` in `functions.php`.
3. Add the Mayor/Governor donor labels to the web and API pledge handlers.
4. Verify the API pledge handler's own-municipality checks for the Mayor sub-roles.
5. Port the Flutter role helpers + `effectiveMunicipality` for Mayor sub-roles.
6. Run the checklist.

## 10. Verification checklist

- [ ] `role_name()`/`sub_role_name()` display `Mayor` and `Governor` on their sessions.
- [ ] Log in as `mayor_kalibo`: sees only Kalibo centres on the board; pledge succeeds; the ledger labels the row `Mayor Kalibo`; direct API pledge to an Ibajay centre returns an error; `can_manage_users=0`, cannot edit a centre or a hotline.
- [ ] Log in as `governor`: sees all municipalites; pledge succeeds; ledger shows `Governor`; still cannot change report statuses or manage users.
- [ ] Barangay accounts still cannot open the board (redirect / 403).
- [ ] Flutter: Mayor sees the Pledge button; Pledge dialog posts successfully.

## 11. Completion evidence

Status: **Implemented** in the reference source.

- Sub-role migration chain exists (`add_pcf_mdr_subroles` → `add_mayor_subroles` → `add_pho_pdrrmo_subrole` → `add_governor_role`), and the live `users.sub_role` enum contains all ten values.
- `can_pledge_assistance()`/`is_readonly_role()`/`mayor_municipality()`/`get_effective_municipality()` verified in `functions.php`; scope checks verified in `api/pledge_assistance.php`.
- Donor labels for Mayor/Governor are present in the API handler; the web handler keeps the pre-Mayor labels (`Municipal Office`/`PHO Provincial Health Office`) — the divergence is proactive: a porter may want the web ledger to show `Mayor Kalibo` too if it was present on their source.
- **Not verified by execution:** freshly-created Mayor/Governor accounts on a ported DB (no secondary environment); verification steps above assume the role enum and demo accounts from the migrations.