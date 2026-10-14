# Documentation TODO

Tracking list of project docs that still need to be **written** or **corrected**.
Status markers: `[ ]` to do · `[~]` in progress · `[x]` done.

---

## Recently completed

- [x] `obilak-docs/API.md` — rewritten to match the current **40 endpoints + 2 helpers** (commit `7c6cf6a`).
- [x] `obilak-docs/DATABASE.md` — rewritten for the current **16-table** schema + local-vs-Railway notes (commit `90922fc`).
- [x] `obilak-docs/README.md` — `README2.md` merged into one **system overview**; `README2.md` deleted (commit `47961be`).

---

## Stale docs to fix (in repo)

### [ ] `README1.md` — "Deploying Ugyon to Railway"
Mostly correct, but it drifts from the current code/config:

- [ ] **Step 5 + Step 6 — variable names.** The app now reads `DB_*` env vars
      (`DB_HOST`, `DB_USER`, `DB_PASS`, `DB_NAME`, `DB_PORT`) via `config/env.php`
      and `config/db_connection.php:8-12` — **not** the `MYSQL*` names. Update both
      the variable table and the code sample.
- [ ] **Step 6 — code sample uses `getenv()`;** the real code uses the `env()`
      helper with a `.env` loader (`config/db_connection.php`). Align the sample.
- [ ] **Step 4 — dump filename.** Guide says `capstone-with-data.sql`; the repo
      ships `database/Railway/capstone.sql`. Fix the name/path and note that the
      file's own `CREATE DATABASE capstone` header does not match the
      `DB_NAME=railway` production database.
- [ ] **Step 9 — Flutter path is wrong.** `flutter/flutter_saster/lib/config/api_config.dart`
      → `flutter/flutter_saster/lib/constants/api_config.dart`. Also fix the broken
      code fence around the `flutter build apk` block.
- [ ] **Step 10 — Cloudinary uses ONE var.** Replace the three `CLOUDINARY_*` rows
      with a single `CLOUDINARY_URL=cloudinary://KEY:SECRET@CLOUD`.
- [ ] Add `.env` / `.env.example` (`DB_*`, optional `CLOUDINARY_URL`) to the
      variables section.
- [ ] Remove any leftover `web/` paths — the API lives at the repo root `api/`.

### [ ] `about_this_system.md` — canonical coding-agent briefing
Snapshot dated **2026-09-21**; still very useful, but predates recent work:

- [ ] Update the snapshot date and scale figures (42 API files, 16 tables).
- [ ] Add: env-based config (`config/env.php`, `.env`), **Cloudinary** evidence,
      **Railway** production host, the **sub-role expansion** (`mdr_*`, `mayor_*`,
      `pdrrmo`, `governor`), and the **Needs & Assistance** module.
- [ ] Verify barangay counts → **51** (16 Kalibo + 35 Ibajay) where figures appear.
- [ ] Add `database/Railway/` and the local-`capstone` vs prod-`railway` distinction.
- [ ] Re-check the "sources of truth" table paths still exist.

### [ ] `obilak-docs/CHANGELOG.md`
- [ ] Remove the reference to "README2 (plain-language guide)" — that file is gone
      (now merged into `README.md`).
- [ ] Add recent work: Cloudinary evidence hosting, env-var DB config, Railway
      deployment, Needs & Assistance board, sub-role expansion, username
      validation, folder-based Cloudinary scheme, 16-table schema.
- [ ] Add a rough date/order hint.

### [ ] `brief.md` — capstone project brief
- [ ] "All **16** barangays of Kalibo" → now covers **Kalibo (16) + Ibajay (35) = 51**.
- [ ] Roles: add sub-roles (captain / secretary / tanod · MDR / mayor · PHO admin /
      PDRRMO / governor).
- [ ] Add the Needs & Assistance module, Cloudinary evidence, and Railway hosting.

### [ ] `script.md` — demo / marketing voiceover
- [ ] Evidence limits: says "up to **five photos or two short videos**"; actual =
      **1 photo + 1 video** (`config/app_config.php`).
- [ ] Naming: mixes "Saster" and "Ugyon / OBILAK" — pick one consistently.

### [ ] root `README.md`
- [ ] Currently rough Aklanon run-notes ("import capstone.sql… `localhost/public`").
      Either replace with a proper short pointer to `obilak-docs/`, or keep as a
      quick-start and tidy the spelling.

---

## Missing docs to create

- [ ] `docs/DEPLOYMENT.md` (or expand `README1.md`) — one Railway deploy + ops
      guide: env vars, DB-name gotcha, Cloudinary, backups.
- [ ] `docs/CONFIGURATION.md` — every env var / config file (`config/env.php`,
      `app_config.php`, `cloudinary.php`) with defaults.
- [ ] `docs/SECURITY.md` — auth model (no tokens yet), open CORS, read-only roles,
      upload hardening (`.htaccess`), secret rotation.
- [ ] `docs/PERMISSIONS.md` — role × sub-role × action matrix (web + API paths).
- [ ] `docs/USER_GUIDE.md` — how to use the web dashboard and mobile app per role.
- [ ] `docs/ASSISTANCE_MODULE.md` — needs & assistance flow, end to end.

---

## Outside the repo (thesis)

- [ ] Align the write-up (`D:\HN3\CAPSTONE 101\UGYON\UGYON.md` / `.docx`) with the
      built system: remove "notifications for new incidents"; relabel figures
      (printable 4.8/4.9, "casualty and impact", drop "routes", coordinate/track
      relief, provincial review); note that **video evidence is implemented**.

---

## Notes

- Add an item here whenever a doc is found to disagree with the code.
- When a section is finished, tick it and add the commit hash next to the file.
- Pair every doc claim with a `file:line` reference where cheap, so it can be
  re-verified later.
