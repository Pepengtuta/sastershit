# OBILAK — Changelog

A record of the work done on the OBILAK system, from the start of development
through the current build. Because the project was built as a continuous series
of improvements (not numbered releases), entries are grouped by type:
**Added** (new features), **Fixed** (bugs & security), and **Improved**
(refactors & polish).

---

## Added — new features

- **Mobile incident reporting** — barangays can submit reports from the app with
  disaster type, description, people affected/injured/dead/missing, evacuation
  needs, a map pin, and photo/video evidence.
- **In-app photo & video viewer** — evidence opens inside the app with
  pinch-to-zoom for photos and built-in video playback (no need to leave the
  app).
- **Dashboard analytics suite** (web + app):
  - **Status breakdown** — how reports are split across Pending → Resolved.
  - **Daily trend** — reports over time.
  - **Human-impact tally** — totals for affected / injured / dead / missing.
  - **Disaster-type bar chart** — which disasters happen most.
- **Weather card** (web + app) — current conditions, a multi-day look-ahead, and
  a heavy-rain / strong-wind heads-up banner, powered by the free Open-Meteo
  service and cached on the server.
- **User management + audit trail** — superadmin can create, edit, reset, and
  activate/deactivate accounts, with every action recorded in an audit log.
- **PHO action controls** — a dedicated way for the Provincial Health Office to
  act on and update the reports referred to them.
- **Project documentation** — README (setup), README2 (plain-language guide),
  API reference, database schema (with diagram), and this changelog.

---

## Fixed — bugs & security

- **Security: unsafe delete links** — replaced delete actions that ran from a
  simple web link (a CSRF risk) with safe, intentional POST actions.
- **Login & UI fixes** — resolved login flow issues and related interface
  glitches.
- **Report editing rules** — a barangay can now only edit a report while it is
  still *Pending*; once it's being processed, it's locked to keep the record
  trustworthy.
- **Dashboard chart scaling** — bars now measure against a clean, rounded
  ceiling with evenly spaced markers, instead of stretching to the single
  biggest bar (which made small differences look exaggerated).
- **Analytics chart ceiling & markers** — corrected the gridline/marker behavior
  on the newer analytics charts so they read accurately.
- **"All-time" label** — fixed a mislabeled total on the web dashboard so it
  clearly reflects all-time figures.

---

## Improved — refactors & polish

- **Unified uploads** — consolidated two overlapping upload paths into a single,
  consistent flow.
- **Role permissions** — tightened enforcement so each role (barangay, PCF, PHO,
  superadmin) can only do what it should.
- **Reports handling** — streamlined and merged duplicated report logic for
  consistency.
- **UI color cleanup** — made colors consistent across the interface for a
  cleaner, more professional look.
- **Code style ("pony tail" rule)** — adopted a standing rule that all code be
  written simply and kept readable and maintainable, without losing
  functionality.

---

## Notes

- This is a **development changelog** for a capstone project; dates and version
  numbers were not tracked per change, so items are grouped by type rather than
  by release.
- The system is built for a **local / development setup** (XAMPP + MySQL). Some
  hardening (such as token-based login) is planned for a future phase.
