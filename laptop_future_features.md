# Disaster Management Features: ResQ vs. SasterGPT

This document lists the features of each repository separately.

---

## 1. ResQ Disaster Management App Features (AyushB21)

This project focuses on responder-to-victim communication, resource management, and self-registration.

### Tech Stack
*   **Mobile App:** React Native (TypeScript / JSX)
*   **Web Portal:** React Single Page Application (SPA)

### Key Features
*   **Live Chat & Messaging:** Features a messaging system for real-time chat between disaster victims (requestees) and responders (`Chats.jsx`, `RequesteeChat.jsx`, `Chat.jsx`, `Message.jsx`).
*   **Responding Teams Coordination:** Interface to coordinate, list, and assign rescue teams to specific emergencies (`Teams.jsx`, `TeamName.jsx`).
*   **Resource Inventory & Tracking:** Form/view to manage, allocate, and update disaster relief resources such as food packs, medical supplies, and response vehicles (`UpdateResources.jsx`).
*   **Self-Registration (Signup):** Allows new users or responders to create accounts themselves directly in the mobile app (`Register.jsx`).
*   **Rescue Task Closeout:** Allows responders to mark a specific rescue task or report as complete (`MarkasComplete.jsx`).

---

## 2. SasterGPT Features

This project focuses on government/agency role coordination (Barangay, PCF, PHO, Admin) and verified incident workflows.

### Tech Stack
*   **Mobile App:** Flutter (Dart / Material 3)
*   **Web Portal:** PHP / MySQL with Bootstrap and Leaflet boundary maps

### Key Features
*   **Multi-Role Enforced Workflows:** Enforces distinct permissions and views across 4 roles:
    *   **Barangay:** Report incidents with GPS pin location and attachments.
    *   **PCF (Provincial Coordination Facility):** Review, verify, and route reports.
    *   **PHO (Provincial Health Office):** Review health-specific disaster details.
    *   **Super Admin:** Global configurations and user management.
*   **Incident Reports with Evidence Attachments:** Barangay can upload multiple photos/videos directly from the mobile app as incident evidence.
*   **Interactive Barangay Boundary Mapping:** Boundary outlines of barangays are shown in Leaflet maps. Hover highlights are synced across the web app using red colors (`#DC3545`) matching the brand theme.
*   **Snappy Pull-to-Refresh & Snappy Filters:** Fast list reload and instant client-side query filters (search, status, date, type) on both Web and Mobile platforms.
*   **Barangay Alerts:** Admins and PCF can post broadcast alerts scoped to specific barangays.
*   **Hotlines Directory:** Central database of emergency hotlines searchable by scope and category.
*   **Evacuation Centers Directory:** Creates and manages availability/open status of evacuation centers within barangays.
*   **Statistics Dashboard:** Visual panels and status timelines on the web portal to review logs of who made changes.
