# Agent Prompt — Option B: Offline Status Action Queue (Bidirectional Sync)

> **READ FIRST:** Before touching any file, read `about_this_system.md` in
> the project root. This is the canonical system guide. Pay special attention
> to sections on roles, the incident workflow, and the offline architecture.

---

## 0. What you are building

Right now, when a Barangay Chairman marks a report as "Reviewed", or a PCF/MDR
officer marks it "Verified", the app calls `IncidentService.updateStatus()`
directly. If the device has no internet, the action silently fails.

You are adding an **offline status action queue** — a SQLite queue that holds
status change actions when the device is offline, then automatically flushes
them to the server when connectivity returns.

This gives OBILAK **bidirectional offline sync with eventual consistency**:
- BHERT → submits reports offline (already exists via `offline_report_sync.dart`)
- Chairman/PCF/PHO → changes report status offline (what you are building now)

**Conflict resolution policy: Server-wins.**
The server's `api/update_status.php` already enforces status workflow gates
(e.g., you can't verify a report that has already been dismissed). If the queued
action is rejected by the server, mark it `failed` and surface the rejection
message to the user — do NOT retry a server rejection automatically.

**Optimistic UI:** When the user queues an action offline, immediately update
the report's status in the local cached report list so the UI feels responsive.
When the sync completes (success or failure), refresh the report list.

---

## 1. Architecture overview

The pattern mirrors `offline_report_sync.dart` / `report_queue_database.dart` /
`report_queue_repository.dart` exactly. Read all three of those files fully
before writing a single line of code.

```
User taps action button (offline)
        ↓
StatusActionQueueRepository.enqueue(reportId, newStatus, remarks, ...)
        ↓
SQLite: queued_status_actions table  ←── source of truth
        ↓  (optimistic: also update cached report list status locally)
UI shows report with new status + "Pending Sync" chip
        ↓
Connectivity returns  (or: OfflineSyncCoordinator step / manual retry)
        ↓
StatusActionSync._runSyncLoop()
        ├─ POST api/update_status.php
        ├─ success  → mark sent  → refresh report list cache
        └─ server rejection  → mark failed → show error → revert optimistic status
```

---

## 2. New files to create

| File | Purpose |
|---|---|
| `lib/services/status_action_queue_database.dart` | SQLite table for queued status change actions |
| `lib/services/status_action_queue_repository.dart` | Model class + repository wrapping the database |
| `lib/services/status_action_sync.dart` | Single-flight sync loop, connectivity listener, backoff retry |

---

## 3. Existing files to modify

| File | What changes |
|---|---|
| `lib/services/offline_sync_coordinator.dart` | Call `StatusActionSync.instance.init()` and add a flush step |
| `lib/screens/barangay/reports_screen.dart` | `changeReportStatus()` → write to queue instead of direct API call |
| `lib/screens/pcf/review_reports_screen.dart` | `updateReport()` → write to queue instead of direct API call |
| PHO health reports screen (locate with `list_dir lib/screens/pho/`) | Same pattern |
| `lib/screens/barangay/barangay_main_screen.dart` | Call `StatusActionSync.instance.init()` on app start (if not done via coordinator) |
| `lib/widgets/report_card.dart` | Show a "Pending Sync" chip when the report has a queued action |
| `lib/services/report_queue_repository.dart` | No change — read only for reference |

---

## 4. Database design — `status_action_queue_database.dart`

Single SQLite file: `saster_status_action_queue.db`

Copy the `_open()` / `get database` / `_dbVersion` pattern exactly from
`report_queue_database.dart`.

### Table: `queued_status_actions`

```sql
CREATE TABLE queued_status_actions (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  report_id        INTEGER NOT NULL,
  user_id          INTEGER NOT NULL,
  new_status       TEXT    NOT NULL,
  remarks          TEXT    NOT NULL DEFAULT '',
  referred_to_pho  INTEGER NOT NULL DEFAULT 0,
  status           TEXT    NOT NULL DEFAULT 'queued',
  error_message    TEXT,
  optimistic_old_status TEXT,
  created_at       TEXT    NOT NULL,
  synced_at        TEXT
);

CREATE INDEX idx_status_actions_user_status
ON queued_status_actions (user_id, status);

CREATE INDEX idx_status_actions_report
ON queued_status_actions (report_id);
```

**Column notes:**
- `report_id` — the incident report being acted on
- `user_id` — the actor (scoped so account switching never leaks)
- `new_status` — e.g. `'Reviewed'`, `'Verified'`, `'Responding'` etc.
- `remarks` — the remark string already built by the screen
- `referred_to_pho` — `1` when this is a "Refer to PHO" action (mirrors
  `referredToPho` in `IncidentService.updateStatus`)
- `status` — `queued` / `sending` / `sent` / `failed`
- `optimistic_old_status` — the report's previous status before the optimistic
  update; stored so you can revert if the server rejects the action
- `error_message` — server rejection reason shown to the user

### Methods to implement

```dart
Future<int> enqueue({
  required int reportId,
  required int userId,
  required String newStatus,
  required String remarks,
  required bool referredToPho,
  required String optimisticOldStatus,
  required DateTime createdAt,
});

Future<List<Map<String, dynamic>>> getPendingForUser(int userId);
// WHERE user_id = ? AND status IN ('queued', 'sending') ORDER BY created_at ASC

Future<List<Map<String, dynamic>>> getForUser(int userId);
// WHERE user_id = ? ORDER BY created_at DESC  (for any future pending-actions screen)

Future<Map<String, dynamic>?> getPendingForReport(int reportId);
// WHERE report_id = ? AND status IN ('queued', 'sending') LIMIT 1
// Used by ReportCard to show the pending chip

Future<void> updateResult({
  required int id,
  required String status,
  String? errorMessage,
  DateTime? syncedAt,
});
```

---

## 5. Repository — `status_action_queue_repository.dart`

Mirror `report_queue_repository.dart` exactly in style.

### Status constants

```dart
class StatusActionQueueStatus {
  StatusActionQueueStatus._();
  static const String queued  = 'queued';
  static const String sending = 'sending';
  static const String sent    = 'sent';
  static const String failed  = 'failed';
}
```

### Model class

```dart
class QueuedStatusAction {
  const QueuedStatusAction({
    required this.id,
    required this.reportId,
    required this.userId,
    required this.newStatus,
    required this.remarks,
    required this.referredToPho,
    required this.status,
    required this.errorMessage,
    required this.optimisticOldStatus,
    required this.createdAt,
    required this.syncedAt,
  });

  factory QueuedStatusAction.fromRow(Map<String, dynamic> row) { ... }

  final int id;
  final int reportId;
  final int userId;
  final String newStatus;
  final String remarks;
  final bool referredToPho;
  final String status;
  final String? errorMessage;
  final String optimisticOldStatus;
  final DateTime createdAt;
  final DateTime? syncedAt;
}
```

### Repository methods

```dart
static StatusActionQueueRepository instance = StatusActionQueueRepository();

Future<int> enqueue({
  required int reportId,
  required int userId,
  required String newStatus,
  required String remarks,
  bool referredToPho = false,
  required String optimisticOldStatus,
});

Future<List<QueuedStatusAction>> getPendingForUser(int userId);
Future<List<QueuedStatusAction>> getForUser(int userId);
Future<QueuedStatusAction?> getPendingForReport(int reportId);

Future<void> markSending(int id);
Future<void> markQueued(int id, {String? errorMessage});
Future<void> markSent(int id);
Future<void> markFailed(int id, String errorMessage);
```

---

## 6. Sync service — `status_action_sync.dart`

Mirror `offline_report_sync.dart` in structure. Key rules:

- **Single-flight** — `ensureSyncedForUser()` shares one in-flight future.
- **Connectivity listener** — start in `init()`, flush on every reconnect.
- **Backoff retry** — same schedule as `offline_report_sync.dart`:
  `[5s, 10s, 20s, 30s, 1m]` for transient network failures only.
- **Server rejections** (`success == false` but NOT a connection failure) → mark
  `failed`. Do NOT retry automatically.
- **Scoped by `user_id`** — account switching never syncs another user's queue.
- **Notify UI** — `StreamController<void> changes` (broadcast, sync: true),
  same as `offline_report_sync.dart`.

### Injectable constructor (for tests)

```dart
typedef StatusActionPoster = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

class StatusActionSync {
  StatusActionSync({
    StatusActionQueueRepository? repository,
    StatusActionPoster? poster,
  }) : _repository = repository ?? StatusActionQueueRepository.instance,
       _poster = poster ?? _defaultPoster;

  static StatusActionSync instance = StatusActionSync();

  static Future<Map<String, dynamic>> _defaultPoster(
    Map<String, dynamic> body,
  ) {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_status.php',
      body: body,
    );
  }
  // ... rest mirrors offline_report_sync.dart
}
```

### `_sendOnce` logic

```dart
Future<_ActionOutcome> _sendOnce(QueuedStatusAction action) async {
  if (!await _hasNetwork()) {
    return const _ActionOutcome(StatusActionQueueStatus.queued,
        errorMessage: 'No internet connection.');
  }
  try {
    final result = await _poster({
      'report_id':       action.reportId,
      'user_id':         action.userId,
      'status':          action.newStatus,
      'remarks':         action.remarks,
      'referred_to_pho': action.referredToPho ? 1 : 0,
    });

    if (result['success'] == true) {
      return const _ActionOutcome(StatusActionQueueStatus.sent);
    }

    final message = result['message']?.toString() ?? 'Status update failed.';
    // Connection failure → keep queued (backoff retry).
    // Server rejection   → mark failed (manual retry or inform user).
    if (ApiService.isConnectionFailure(message: message)) {
      return _ActionOutcome(StatusActionQueueStatus.queued,
          errorMessage: message);
    }
    return _ActionOutcome(StatusActionQueueStatus.failed,
        errorMessage: message);
  } catch (error) {
    return _ActionOutcome(StatusActionQueueStatus.queued,
        errorMessage: 'Connection failed: $error');
  }
}
```

### After each row is processed

- **Sent:** `_repository.markSent(action.id)` then call
  `ReportRepository.instance.getList(...)` to refresh the cached report list
  so the UI sees the confirmed server status.
- **Failed:** `_repository.markFailed(action.id, message)`.
  Also revert the optimistic status in the cached report list back to
  `action.optimisticOldStatus` — users must see that their action did not apply.
- **Queued (transient):** `_repository.markQueued(action.id, errorMessage: ...)`.
  Backoff timer re-arms.

After the loop completes, call `_notify()` so any listening UI rebuilds.

---

## 7. Changes to report list screens

Apply the **same pattern** to all three screens:
- `lib/screens/barangay/reports_screen.dart`
- `lib/screens/pcf/review_reports_screen.dart`
- PHO health reports screen (locate with `list_dir lib/screens/pho/` first)

### Replace every direct `IncidentService.updateStatus()` call

**BEFORE (current code in `reports_screen.dart`):**
```dart
Future<void> changeReportStatus(Map<String, dynamic> report,
    String newStatus, String remarks) async {
  final result = await IncidentService.updateStatus(
    reportId: reportId, userId: userId,
    status: newStatus, remarks: remarks,
  );
  if (mounted && result['success'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    loadReports();
  } else if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
}
```

**AFTER:**
```dart
Future<void> changeReportStatus(Map<String, dynamic> report,
    String newStatus, String remarks) async {
  final reportId = int.tryParse(report['id']?.toString() ?? '') ?? 0;
  final userId   = AuthService.currentUserId ?? 0;
  if (reportId <= 0 || userId <= 0) return;

  final currentStatus = report['status']?.toString() ?? '';

  // Queue the action (works online or offline).
  await StatusActionQueueRepository.instance.enqueue(
    reportId:            reportId,
    userId:              userId,
    newStatus:           newStatus,
    remarks:             remarks,
    referredToPho:       newStatus == 'Referred to PHO',
    optimisticOldStatus: currentStatus,
  );

  // Optimistic update: immediately change status in the local list.
  setState(() {
    final idx = reports.indexWhere(
        (r) => r['id']?.toString() == reportId.toString());
    if (idx != -1) {
      reports[idx] = Map<String, dynamic>.from(reports[idx])
        ..['status'] = newStatus;
    }
  });

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ApiService.isApiUnreachable
            ? 'Saved offline — will sync when connected.'
            : 'Status update queued. Syncing...'),
        backgroundColor: AppColors.primaryBlue,
      ),
    );
  }

  // Attempt to flush the queue immediately (no-op if offline).
  unawaited(StatusActionSync.instance.syncForCurrentUser());
}
```

Apply the same replacement in `review_reports_screen.dart` (`updateReport()`)
and the PHO screen. In `review_reports_screen.dart` pass `referredToPho: true`
when `forwardToPho` is true.

### Listen to sync changes for auto-refresh

In `initState()` of each screen, subscribe to `StatusActionSync.instance.changes`:

```dart
late StreamSubscription<void> _actionSyncSub;

@override
void initState() {
  super.initState();
  loadReports();
  _actionSyncSub = StatusActionSync.instance.changes.listen((_) {
    if (mounted) loadReports();
  });
}

@override
void dispose() {
  _actionSyncSub.cancel();
  super.dispose();
}
```

---

## 8. Changes to `report_card.dart` — "Pending Sync" chip

`ReportCard` needs to check whether the displayed report has a pending queued
action and show a visual indicator if so.

Change `ReportCard` from `StatelessWidget` to `StatefulWidget` so it can run an
async lookup. In `initState`, query:

```dart
QueuedStatusAction? _pendingAction;

@override
void initState() {
  super.initState();
  _checkPending();
}

Future<void> _checkPending() async {
  final reportId = int.tryParse(widget.report['id']?.toString() ?? '') ?? 0;
  if (reportId <= 0) return;
  final action = await StatusActionQueueRepository.instance
      .getPendingForReport(reportId);
  if (mounted) setState(() => _pendingAction = action);
}
```

Also subscribe to `StatusActionSync.instance.changes` to re-check when the sync
loop completes:

```dart
late StreamSubscription<void> _sub;

@override
void initState() {
  super.initState();
  _checkPending();
  _sub = StatusActionSync.instance.changes.listen((_) {
    if (mounted) _checkPending();
  });
}

@override
void dispose() {
  _sub.cancel();
  super.dispose();
}
```

In `build()`, add the pending chip next to the `StatusBadge`:

```dart
if (_pendingAction != null)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.warningYellow.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.warningYellow),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.cloud_upload_outlined,
            size: 12, color: AppColors.warningYellow),
        SizedBox(width: 4),
        Text('Pending Sync',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.warningYellow,
                fontWeight: FontWeight.w600)),
      ],
    ),
  ),
```

If `_pendingAction?.status == StatusActionQueueStatus.failed`:
Show a red "Sync Failed" chip instead, and a small error message below the card.

---

## 9. Changes to `offline_sync_coordinator.dart`

### 9a. Init the sync service

In `init()` (or wherever `OfflineReportSync.instance.init()` is called), also
call:

```dart
await StatusActionSync.instance.init();
```

### 9b. Add as a sync step

Inside `defaultOfflineDatasets()`, **after step 8 (dashboard)**, add:

```dart
// 9. Flush any queued status actions (bidirectional sync).
results.add(
  await _guard('status action queue', () async {
    await StatusActionSync.instance.syncForCurrentUser();
    // Always returns true — the sync loop handles failures internally.
    return true;
  }),
);
```

---

## 10. Conflict resolution — what to do on server rejection

The server's `api/update_status.php` enforces the full workflow gate. When the
server rejects a queued action (e.g., a Chairman tries to "Review" a report that
was already "Dismissed" by someone else while they were offline):

1. Mark the action as `failed` in SQLite.
2. Revert the optimistic status in the local cached report list back to
   `action.optimisticOldStatus`.
3. Emit a change notification so the UI rebuilds.
4. The `ReportCard` will show a red "Sync Failed" chip.
5. On next `loadReports()`, the true server status replaces any optimistic value.

**No automatic retry on server rejections.** Only connection failures use the
backoff timer.

---

## 11. Implementation order — follow exactly, do not skip steps

1. `list_dir lib/screens/pho/` — find the PHO health reports screen filename.
2. Read ALL of these files before writing a single line:
   - `lib/services/offline_report_sync.dart`
   - `lib/services/report_queue_database.dart`
   - `lib/services/report_queue_repository.dart`
   - `lib/services/offline_sync_coordinator.dart`
   - `lib/services/incident_service.dart`
   - `lib/screens/barangay/reports_screen.dart`
   - `lib/screens/pcf/review_reports_screen.dart`
   - `lib/widgets/report_card.dart`
   - `api/update_status.php` — understand the server-side status gates
3. **Create** `lib/services/status_action_queue_database.dart`
4. **Create** `lib/services/status_action_queue_repository.dart`
5. **Create** `lib/services/status_action_sync.dart`
6. **Modify** `lib/services/offline_sync_coordinator.dart`
7. **Modify** `lib/screens/barangay/reports_screen.dart`
8. **Modify** `lib/screens/pcf/review_reports_screen.dart`
9. **Modify** PHO health reports screen
10. **Modify** `lib/widgets/report_card.dart`
11. Run `flutter analyze` — fix every warning before finishing.
12. Run `flutter test` — confirm no regressions.

---

## 12. Hard constraints — never violate

1. **Single-flight sync** — `ensureSyncedForUser()` must never run two sync
   loops concurrently. Copy the `_runningSync` future pattern from
   `offline_report_sync.dart` exactly.

2. **Scoped by `user_id`** — `getPendingForUser(userId)` always filters by
   `user_id`. Account switching must never expose or send another user's queue.

3. **Never retry a server rejection.** Only connection failures (`ApiService
   .isConnectionFailure(message: message)`) return `queued`. Server rejections
   always return `failed`.

4. **Never overwrite a `failed` row.** Once a row is `failed`, only an explicit
   manual retry (a future feature) can re-queue it. The sync loop's
   `getPendingForUser` only returns `queued` and `sending` rows.

5. **Optimistic revert on failure.** When `markFailed()` is called, the sync
   service must also revert the cached report list status. Do not leave the UI
   showing a status that the server rejected.

6. **Do not modify PHP files.** `api/update_status.php` is already correct.
   The payload sent from the queue must match exactly what `updateStatus()` in
   `incident_service.dart` sends: `report_id`, `user_id`, `status`, `remarks`,
   `referred_to_pho`.

7. **`unawaited()` imports.** Use `import 'dart:async' show unawaited;` when
   using `unawaited(...)`. Check the existing codebase for how it is imported.

8. **Run `flutter analyze`** before finishing. Zero new lint errors.

---

## 13. Roles and which status transitions they can queue

Read `api/update_status.php` to confirm the server gates. The transitions the
UI currently allows (and which you are making offline-capable) are:

| Role | Sub-role | Can queue |
|---|---|---|
| Barangay | Captain | Reviewed, Forwarded to PCF, Dismissed |
| Barangay | Secretary | (no status actions — do not add) |
| Barangay | Tanod/BHERT | (no status actions — do not add) |
| PCF | mdr_kalibo / mdr_ibajay | Under MDR Review, Verified, Responding, Dismissed, Resolved, Referred to PHO |
| PCF | mayor_kalibo / mayor_ibajay | READ-ONLY — do not add queue |
| PHO | (empty = pho admin) / pdrrmo | Under PHO Review, Responding, Resolved, Dismissed |
| PHO | governor | READ-ONLY — do not add queue |
| Superadmin | — | READ-ONLY in reports screen (allowStatusActions = false) |

Only touch the action buttons for roles that have write permissions. Observers
(Mayors, Governor, Superadmin in review mode) must not be given a queue path.

---

## 14. API endpoint reference (no changes needed)

| Endpoint | Method | Request fields | Response |
|---|---|---|---|
| `api/update_status.php` | POST | `report_id` (int), `user_id` (int), `status` (string), `remarks` (string), `referred_to_pho` (0 or 1) | `{'success': true/false, 'message': '...'}` |

The server enforces all workflow gates. Your queue just holds and replays the
same payload that the screens already build today.

---

## 15. Defense paragraph (use this after implementation is complete)

> "OBILAK implements **offline-first bidirectional sync with eventual
> consistency**. BHERT field reporters can submit incident reports without
> internet connectivity — these are queued in SQLite and automatically flushed
> to MySQL when connectivity resumes. Barangay Chairmen and PCF/PHO officers
> can similarly perform their status actions — reviewing, verifying, or
> escalating reports — without connectivity. Each device's action queue is
> stored in local SQLite, scoped by user ID to prevent data leakage between
> accounts, and replayed against the server on reconnection using the same
> payload the online path uses. The server enforces all workflow gates and
> acts as the single source of truth for conflict resolution. All devices
> eventually converge to the same consistent state regardless of the order or
> timing of individual connections — a pattern known as eventual consistency."
