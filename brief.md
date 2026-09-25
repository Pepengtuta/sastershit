# OBILAK — Barangay Disaster Reporting & Response System
### Capstone Project Brief | Kalibo, Aklan

---

## Background of the Study

During typhoons, floods, and other disasters in Kalibo, Aklan, a critical gap exists between the barangay level and the provincial response units — the **Provincial Health Office (PHO)** and the **Provincial Coordination Facility (PCF)**.

Barangays on the ground have no fast, structured way to report incidents upward. Coordinators and health officers, in turn, have no single live view of what is happening across all 16 barangays at the same time. This delay in information flow results in **slower response, misallocated resources, and incomplete situational awareness** during the moments it matters most.

Manual reporting through calls or SMS is fragmented, hard to track, and leaves no auditable record of who reported what, when, and what action was taken.

---

## Objectives of the System

The OBILAK system was built to:

1. **Enable fast, structured incident reporting** — Barangay officials submit disaster reports directly from a mobile app, including disaster type, number of people affected, injured, dead, or missing, evacuation needs, GPS location, and photo or video evidence.

2. **Give coordinators and health officers a live, unified view** — The PHO and PCF monitor all incoming reports from a web dashboard with an interactive map, status tracking, and analytics — in real time, without waiting for calls.

3. **Enforce a clear, role-based workflow** — Reports follow a structured chain: Barangay submits → PCF reviews and verifies → PHO acts on health-related cases → Superadmin manages accounts and system integrity.

4. **Centralize critical disaster resources** — The system maintains a live directory of evacuation centers (with capacity and current status), emergency hotlines, and broadcast alerts that can be pushed to specific barangays.

5. **Provide data for decision-making** — A built-in analytics dashboard shows incident trends, disaster type breakdowns, human impact tallies, and a weather outlook — giving coordinators and health officers the numbers they need to make informed decisions.

---

## Why This System Was Built

> **The problem is not a lack of effort — it is a lack of structure.**

When a disaster hits, barangay captains make phone calls. Coordinators write things down on paper or in separate spreadsheets. The PHO waits for updates that may come hours late, if at all. There is no single source of truth.

OBILAK was built to replace that fragmented process with **one connected system** where:

- Every incident is logged with evidence and a map pin the moment it is reported.
- Coordinators can see, verify, and act on reports without waiting for a callback.
- Health officers have a direct channel for cases escalated to the PHO level.
- No report gets lost, no status is ambiguous, and every action leaves an audit trail.

For **Doctors and Program Coordinators**, this means:
- You will know which barangays are affected, how many people need help, and what resources are needed — before you make your first decision.
- You can act on verified, structured data instead of secondhand information.
- The system works locally — no internet dependency during disaster operations.

---

## System at a Glance

| Component | Details |
|-----------|---------|
| **Mobile App** | Flutter — for Barangay use (Android / Web) |
| **Web Dashboard** | PHP + MySQL — for PCF, PHO, and Superadmin |
| **Map** | Interactive barangay boundary map (Leaflet) |
| **Weather** | Live forecast with heavy-rain and strong-wind alerts |
| **Coverage** | All 16 barangays of Kalibo, Aklan |
| **Roles** | Barangay · PCF · PHO · Superadmin |

---

## User Roles — Who Does What

| Role | Description |
|------|-------------|
| **Barangay** | Submits and tracks incident reports from the mobile app |
| **PCF** *(Program Coordinator)* | Reviews, verifies, and routes reports on the web dashboard |
| **PHO** *(Provincial Health Office / Doctor)* | Monitors and acts on health-related disaster cases |
| **Superadmin** | Manages accounts, configures the system, views the full audit trail |

---

*OBILAK — Capstone Project, Kalibo, Aklan*
