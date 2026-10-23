# Agent Prompt — Offline Assistance Queue (Pledge + Status + Confirm Received)

> **READ FIRST:** Before touching any file, read `about_this_system.md` in
> the project root. This is the canonical system guide. Pay special attention
> to the assistance board section and the offline architecture sections.

---

## 0. What you are building

Currently, in `assistance_board_screen.dart` and `center_needs_screen.dart`,
every action that writes data — pledging assistance, updating a pledge status,
confirming a donation was received, and saving center needs — first checks
`_isNetworkAvailable()` and **blocks the user with an error message if offline**.

You are replacing those hard blocks with an **offline action queue** — a SQLite
queue that stores the intended action, applies it optimistically to the local UI,
and automatically flushes to the server when connectivity returns.

This gives OBILAK **bidirectional offline sync** for the Needs & Assistance
domain:
- Server → device: already cached by `AssistanceRepository` (read side ✅)
- Device → server: pledge / status update / confirm received queued offline ✅ ← *you are building this*

**Conflict resolution policy: Server-wins.**
`api/pledge_assistance.php`, `api/update_assistance_status.php`, and
`api/confirm_assistance_received.php` enforce all business rules. If the server
rejects a queued action, mark it `failed`, revert the optimistic local change,
and surface the rejection message. Do NOT retry server rejections automatically.

**Optimistic UI:** When the user submits an action offline, immediately update
the local cached board/center data so the UI feels responsive. Revert on
server rejection when sync completes.

---

## 1. The four offline-capable actions

Study each current implementation before writing a line of code.

| Action | Screen | Current call | Endpoint |
|---|---|---|---|
| **Pledge assistance** | `assistance_board_screen.dart → _pledge()` | `AssistanceService.pledge(...)` | `api/pledge_assistance.php` |
| **Update pledge status** | `assistance_board_screen.dart → _changeStatus()` | `AssistanceService.updateStatus(...)` | `api/update_assistance_status.php` |
| **Confirm received** | `center_needs_screen.dart → _confirmReceived()` | `AssistanceService.confirmReceived(...)` | `api/confirm_assistance_received.php` |
| **Save center needs** | `center_needs_screen.dart → _save()` | `AssistanceService.saveCenterNeeds(...)` | `api/save_center_needs.php` |

> **Note on Save Center Needs:** This is the most complex action because it
> replaces the entire needs list for a center. Queue it as a JSON blob. On sync,
> the server overwrites the existing needs — idempotent by design.

---

## 2. New files to create

| File | Purpose |
|---|---|
| `lib/services/assistance_action_queue_database.dart` | SQLite table for all four queued assistance actions |
| `lib/services/assistance_action_queue_repository.dart` | Model classes + status constants + repository |
| `lib/services/assistance_action_sync.dart` | Single-flight sync loop, connectivity listener, backoff retry |

---

## 3. Existing files to modify

| File | What changes |
|---|---|
| `lib/services/offline_sync_coordinator.dart` | `init()` calls `AssistanceActionSync.instance.init()`; add flush step |
| `lib/screens/shared/assistance_board_screen.dart` | `_pledge()` and `_changeStatus()` → write to queue, optimistic update |
| `lib/screens/shared/center_needs_screen.dart` | `_save()` and `_confirmReceived()` → write to queue, optimistic update |
| `lib/widgets/pledge_ledger_row.dart` | Show "Pending Sync" / "Sync Failed" chip on queued rows |

---

## 4. Database design — `assistance_action_queue_database.dart`

Single SQLite file: `saster_assistance_action_queue.db`

Copy the `_open()` / `get database` / `_dbVersion` singleton pattern exactly
from `report_queue_database.dart`.

### Table: `queued_assistance_actions`

```sql
CREATE TABLE queued_assistance_actions (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  action_type     TEXT    NOT NULL,
  user_id         INTEGER NOT NULL,
  payload         TEXT    NOT NULL,
  optimistic_json TEXT,
  status          TEXT    NOT NULL DEFAULT 'queued',
  error_message   TEXT,
  created_at      TEXT    NOT NULL,
  synced_at       TEXT
);

CREATE INDEX idx_asst_actions_user_status
ON queued_assistance_actions (user_id, status);

CREATE INDEX idx_asst_actions_type
ON queued_assistance_actions (action_type, status);
```

**Column notes:**
- `action_type` — one of: `'pledge'`, `'update_status'`, `'confirm_received'`,
  `'save_center_needs'`
- `user_id` — the acting user; all queries are scoped by this
- `payload` — JSON-encoded map of the exact fields sent to the server endpoint
  (mirrors what `AssistanceService` sends today)
- `optimistic_json` — JSON-encoded snapshot of the local change that was applied
  to the cache, so the sync service knows what to revert on failure
- `status` — `queued` / `sending` / `sent` / `failed`

### Methods to implement

```dart
Future<int> enqueue({
  required String actionType,
  required int userId,
  required Map<String, dynamic> payload,
  Map<String, dynamic>? optimisticJson,
  required DateTime createdAt,
});

Future<List<Map<String, dynamic>>> getPendingForUser(int userId);
// WHERE user_id = ? AND status IN ('queued', 'sending') ORDER BY created_at ASC

Future<List<Map<String, dynamic>>> getForUser(int userId);
// All rows for a user ordered by created_at DESC

Future<void> updateResult({
  required int id,
  required String status,
  String? errorMessage,
  DateTime? syncedAt,
});
```

---

## 5. Repository — `assistance_action_queue_repository.dart`

Mirror `report_queue_repository.dart` in style and naming.

### Status constants

```dart
class AssistanceActionQueueStatus {
  AssistanceActionQueueStatus._();
  static const String queued  = 'queued';
  static const String sending = 'sending';
  static const String sent    = 'sent';
  static const String failed  = 'failed';
}
```

### Action type constants

```dart
class AssistanceActionType {
  AssistanceActionType._();
  static const String pledge          = 'pledge';
  static const String updateStatus    = 'update_status';
  static const String confirmReceived = 'confirm_received';
  static const String saveCenterNeeds = 'save_center_needs';
}
```

### Model class

```dart
class QueuedAssistanceAction {
  const QueuedAssistanceAction({
    required this.id,
    required this.actionType,
    required this.userId,
    required this.payload,
    required this.optimisticJson,
    required this.status,
    this.errorMessage,
    required this.createdAt,
    this.syncedAt,
  });

  factory QueuedAssistanceAction.fromRow(Map<String, dynamic> row) { ... }

  final int id;
  final String actionType;
  final int userId;
  final Map<String, dynamic> payload;
  final Map<String, dynamic>? optimisticJson;
  final String status;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? syncedAt;
}
```

### Repository methods

```dart
static AssistanceActionQueueRepository instance =
    AssistanceActionQueueRepository();

Future<int> enqueue({
  required String actionType,
  required int userId,
  required Map<String, dynamic> payload,
  Map<String, dynamic>? optimisticJson,
});

Future<List<QueuedAssistanceAction>> getPendingForUser(int userId);
Future<List<QueuedAssistanceAction>> getForUser(int userId);

Future<void> markSending(int id);
Future<void> markQueued(int id, {String? errorMessage});
Future<void> markSent(int id);
Future<void> markFailed(int id, String errorMessage);
```

---

## 6. Sync service — `assistance_action_sync.dart`

Mirror `offline_report_sync.dart` structure exactly.

- **Single-flight** via `_runningSync` future pattern
- **Connectivity listener** in `init()`
- **Backoff retry** `[5s, 10s, 20s, 30s, 1m]` for transient network failures
- **Server rejections** → `failed`, no auto-retry
- **Scoped by `user_id`**
- **`StreamController<void> changes`** (broadcast, sync: true) for UI refresh

### Injectable typedefs (for tests)

```dart
typedef AssistanceActionPoster = Future<Map<String, dynamic>> Function(
  String actionType,
  Map<String, dynamic> payload,
);

class AssistanceActionSync {
  AssistanceActionSync({
    AssistanceActionQueueRepository? repository,
    AssistanceActionPoster? poster,
  }) : _repository = repository ?? AssistanceActionQueueRepository.instance,
       _poster = poster ?? _defaultPoster;

  static AssistanceActionSync instance = AssistanceActionSync();
  // ...
}
```

### `_defaultPoster` — route by `actionType`

```dart
static Future<Map<String, dynamic>> _defaultPoster(
  String actionType,
  Map<String, dynamic> payload,
) {
  final url = switch (actionType) {
    AssistanceActionType.pledge =>
        '${ApiConfig.baseUrl}/pledge_assistance.php',
    AssistanceActionType.updateStatus =>
        '${ApiConfig.baseUrl}/update_assistance_status.php',
    AssistanceActionType.confirmReceived =>
        '${ApiConfig.baseUrl}/confirm_assistance_received.php',
    AssistanceActionType.saveCenterNeeds =>
        '${ApiConfig.baseUrl}/save_center_needs.php',
    _ => throw ArgumentError('Unknown action type: $actionType'),
  };
  return ApiService.postJson(url: url, body: payload);
}
```

### `_sendOnce` logic

```dart
Future<_ActionOutcome> _sendOnce(QueuedAssistanceAction action) async {
  if (!await _hasNetwork()) {
    return const _ActionOutcome(AssistanceActionQueueStatus.queued,
        errorMessage: 'No internet connection.');
  }
  try {
    final result = await _poster(action.actionType, action.payload);
    if (result['success'] == true) {
      return const _ActionOutcome(AssistanceActionQueueStatus.sent);
    }
    final message =
        result['message']?.toString() ?? 'Assistance action failed.';
    if (ApiService.isConnectionFailure(message: message)) {
      return _ActionOutcome(AssistanceActionQueueStatus.queued,
          errorMessage: message);
    }
    return _ActionOutcome(AssistanceActionQueueStatus.failed,
        errorMessage: message);
  } catch (error) {
    return _ActionOutcome(AssistanceActionQueueStatus.queued,
        errorMessage: 'Connection failed: $error');
  }
}
```

### After each row completes

- **Sent:** `markSent()` → call `AssistanceRepository.instance.refreshBoard()`
  and/or `refreshCenterNeeds()` to pull the confirmed server state into the
  local cache.
- **Failed:** `markFailed()` → attempt to revert the optimistic change. For
  simple cases (status update), revert the `optimisticJson` value in the cache.
  For `pledge` and `saveCenterNeeds`, refresh from server if online (the
  reversal is complex and a fresh fetch is cleaner and safer).
- **Queued (transient):** `markQueued()` → backoff timer re-arms.

After the loop: `_notify()`.

---

## 7. Changes to `assistance_board_screen.dart`

### 7a. Replace `_pledge()`

**BEFORE (current):**
```dart
if (!await _isNetworkAvailable()) {
  _showMessage('Reconnect to the internet to pledge assistance.', error: true);
  return;
}
// ... dialog shown ...
final result = await AssistanceService.pledge(...);
```

**AFTER:**
```dart
// Remove the network guard at the top of _pledge().
// Let the user fill the form even offline.

// After form is filled and user taps Submit:
final userId = AuthService.currentUserId ?? 0;
await AssistanceActionQueueRepository.instance.enqueue(
  actionType: AssistanceActionType.pledge,
  userId: userId,
  payload: {
    'acting_user_id': userId,
    'evac_center_id': centerId,
    'need_id': needId,
    'item': item,
    'unit': unit,
    'qty': qty,
    'remarks': remarkCtrl.text.trim(),
  },
  optimisticJson: {
    'center_id': centerId,
    'need_id': needId,
    'item': item,
    'qty': qty,
    'unit': unit,
  },
);

// Optimistic update: add a placeholder entry to the local board data
// so the UI immediately shows the pledge without waiting for the server.
// The simplest approach: increment the pending pledge count locally,
// or reload from cache after enqueue (the cache is not yet updated —
// so show a SnackBar instead and leave the board as-is until sync).
if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ApiService.isApiUnreachable
          ? 'Pledge saved offline — will sync when connected.'
          : 'Pledge queued. Syncing...'),
      backgroundColor: AppColors.primaryBlue,
    ),
  );
}
unawaited(AssistanceActionSync.instance.syncForCurrentUser());
```

> **Over-pledge warning:** Keep the existing over-pledge warning dialog. It
> uses the local `remaining` value from the cached board data. Since that value
> may be stale when offline, add a note to the warning: *"Note: you are
> offline — this figure is from saved data and may have changed."*

### 7b. Replace `_changeStatus()`

**BEFORE:**
```dart
if (!await _isNetworkAvailable()) {
  _showMessage('Reconnect to the internet to update a pledge status.', error: true);
  return;
}
final result = await AssistanceService.updateStatus(
  assistanceId: id, action: action);
```

**AFTER:**
```dart
// Remove the network guard.
final userId = AuthService.currentUserId ?? 0;
await AssistanceActionQueueRepository.instance.enqueue(
  actionType: AssistanceActionType.updateStatus,
  userId: userId,
  payload: {
    'acting_user_id': userId,
    'assistance_id': id,
    'action': action,
  },
  optimisticJson: {'assistance_id': id, 'action': action},
);

if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ApiService.isApiUnreachable
          ? 'Status update saved offline — will sync when connected.'
          : 'Status update queued. Syncing...'),
      backgroundColor: AppColors.primaryBlue,
    ),
  );
}
unawaited(AssistanceActionSync.instance.syncForCurrentUser());
```

### 7c. Subscribe to sync changes for auto-refresh

In `initState()` of `_AssistanceBoardScreenState`, add:

```dart
late StreamSubscription<void> _actionSyncSub;

@override
void initState() {
  super.initState();
  loadBoard();
  _actionSyncSub = AssistanceActionSync.instance.changes.listen((_) {
    if (mounted) loadBoard();
  });
}

@override
void dispose() {
  _searchController.dispose();
  _actionSyncSub.cancel();
  super.dispose();
}
```

### 7d. Remove `canPledge = board['can_pledge'] == true && !offline`

Change it to:

```dart
final canPledge = board['can_pledge'] == true;
```

Pledging is now allowed offline — the queue handles the rest. The `!offline`
guard is no longer needed since we queue instead of blocking.

Similarly, in `_CenterTile`, remove `onUpdateStatus: offline ? null : _changeStatus`
and always pass `_changeStatus`.

---

## 8. Changes to `center_needs_screen.dart`

### 8a. Replace `_save()`

**BEFORE:**
```dart
if (!await _isNetworkAvailable()) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Reconnect to the internet to save center needs...')));
  return;
}
final result = await AssistanceService.saveCenterNeeds(...);
```

**AFTER:**
```dart
// Remove the network guard — save to queue instead.
final userId = AuthService.currentUserId ?? 0;
await AssistanceActionQueueRepository.instance.enqueue(
  actionType: AssistanceActionType.saveCenterNeeds,
  userId: userId,
  payload: {
    'acting_user_id': userId,
    'evac_center_id': widget.evacCenterId,
    'total_evacuees': profile['total_evacuees'],
    'families': profile['families'],
    'pregnant': profile['pregnant'],
    'lactating_mothers': profile['lactating_mothers'],
    'infants': profile['infants'],
    'children': profile['children'],
    'older_persons': profile['older_persons'],
    'pwd': profile['pwd'],
    'sick': profile['sick'],
    'injured': profile['injured'],
    'items': items,
    'profile_source': useReportedTotals ? 'computed' : 'manual',
  },
);

if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ApiService.isApiUnreachable
          ? 'Center needs saved offline — will sync when connected.'
          : 'Center needs queued. Syncing...'),
      backgroundColor: AppColors.primaryBlue,
    ),
  );
  Navigator.pop(context, true);
}
unawaited(AssistanceActionSync.instance.syncForCurrentUser());
```

> **Important:** For `saveCenterNeeds`, the `items` field is a
> `List<Map<String, dynamic>>` — `jsonEncode` handles this correctly since
> the repository stores the payload as a JSON string.

### 8b. Replace `_confirmReceived()`

**BEFORE:**
```dart
if (!await _isNetworkAvailable()) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Reconnect to the internet to confirm...')));
  return;
}
final result = await AssistanceService.confirmReceived(...);
```

**AFTER:**
```dart
// Remove the network guard.
final userId = AuthService.currentUserId ?? 0;
await AssistanceActionQueueRepository.instance.enqueue(
  actionType: AssistanceActionType.confirmReceived,
  userId: userId,
  payload: {
    'acting_user_id': userId,
    'assistance_id': id,
    'qty_received': approved,
  },
  optimisticJson: {
    'assistance_id': id,
    'qty_received': approved,
  },
);

if (mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(ApiService.isApiUnreachable
          ? 'Confirmation saved offline — will sync when connected.'
          : 'Confirmation queued. Syncing...'),
      backgroundColor: AppColors.primaryBlue,
    ),
  );
}
unawaited(AssistanceActionSync.instance.syncForCurrentUser());
if (mounted) await loadData();
```

### 8c. Subscribe to sync changes for auto-reload

```dart
late StreamSubscription<void> _actionSyncSub;

@override
void initState() {
  super.initState();
  // ... existing controller setup ...
  loadData();
  _actionSyncSub = AssistanceActionSync.instance.changes.listen((_) {
    if (mounted) loadData();
  });
}

@override
void dispose() {
  // ... existing dispose ...
  _actionSyncSub.cancel();
  super.dispose();
}
```

---

## 9. Changes to `widgets/pledge_ledger_row.dart`

Read this file fully before editing. It renders individual pledge rows in the
ledger. Add a "Pending Sync" or "Sync Failed" chip when the pledge's
`assistance_id` has a queued action.

Change `PledgeLedgerRow` from `StatelessWidget` to `StatefulWidget`. In
`initState`, query:

```dart
QueuedAssistanceAction? _pendingAction;

@override
void initState() {
  super.initState();
  _checkPending();
  _sub = AssistanceActionSync.instance.changes.listen((_) {
    if (mounted) _checkPending();
  });
}

Future<void> _checkPending() async {
  final assistanceId = int.tryParse(
      widget.ledgerRow['id']?.toString() ?? '') ?? 0;
  if (assistanceId <= 0) return;
  final pending = await AssistanceActionQueueRepository.instance
      .getForUser(AuthService.currentUserId ?? 0);
  final match = pending.where((a) =>
      a.actionType == AssistanceActionType.updateStatus &&
      (a.payload['assistance_id']?.toString() == assistanceId.toString()) &&
      a.status == AssistanceActionQueueStatus.queued).firstOrNull;
  if (mounted) setState(() => _pendingAction = match);
}
```

Show the chip inline with the row's status badge — yellow for pending, red for
failed — same visual style as the `StatusBadge` used in `report_card.dart`.

---

## 10. Changes to `offline_sync_coordinator.dart`

### 10a. Init the sync service

Find where `OfflineReportSync.instance.init()` is called and add:

```dart
await AssistanceActionSync.instance.init();
```

### 10b. Add as a sync step

Inside `defaultOfflineDatasets()`, after the existing steps, add:

```dart
// N+1. Flush any queued assistance actions (pledge, status, confirm, save needs).
results.add(
  await _guard('assistance action queue', () async {
    await AssistanceActionSync.instance.syncForCurrentUser();
    return true;  // Sync loop handles failures internally.
  }),
);
```

---

## 11. Implementation order — follow exactly

1. `list_dir lib/screens/` — confirm the PHO screen path and assistance screens.
2. Read all of these files fully before writing code:
   - `lib/services/offline_report_sync.dart` — mirror this for the sync service
   - `lib/services/report_queue_database.dart` — mirror for the DB
   - `lib/services/report_queue_repository.dart` — mirror for the repository
   - `lib/services/assistance_service.dart` — understand every endpoint payload
   - `lib/services/assistance_repository.dart` — understand the existing cache
   - `lib/screens/shared/assistance_board_screen.dart` — full read
   - `lib/screens/shared/center_needs_screen.dart` — full read
   - `lib/widgets/pledge_ledger_row.dart` — full read
   - `lib/services/offline_sync_coordinator.dart` — understand the step pattern
   - `api/pledge_assistance.php` — understand server validation
   - `api/update_assistance_status.php` — understand server validation
   - `api/confirm_assistance_received.php` — understand server validation
3. **Create** `lib/services/assistance_action_queue_database.dart`
4. **Create** `lib/services/assistance_action_queue_repository.dart`
5. **Create** `lib/services/assistance_action_sync.dart`
6. **Modify** `lib/services/offline_sync_coordinator.dart`
7. **Modify** `lib/screens/shared/assistance_board_screen.dart`
8. **Modify** `lib/screens/shared/center_needs_screen.dart`
9. **Modify** `lib/widgets/pledge_ledger_row.dart`
10. Run `flutter analyze` — fix every warning before finishing.
11. Run `flutter test` — confirm no regressions.

---

## 12. Hard constraints — never violate

1. **Single-flight sync** — copy the `_runningSync` future guard from
   `offline_report_sync.dart`. Never run two sync loops at once.

2. **Scoped by `user_id`** — `getPendingForUser(userId)` always filters.
   Account switching must never expose another user's queue.

3. **Never retry a server rejection.** Only `ApiService.isConnectionFailure()`
   returns `queued`. Server-side logic failures always return `failed`.

4. **`saveCenterNeeds` replaces, not appends.** On sync, the server replaces
   the full needs list. If multiple `saveCenterNeeds` actions are queued for the
   same center (user saved, went offline, saved again), send them in
   `created_at ASC` order so the most recent one wins on the server.

5. **Do not remove the over-pledge warning.** Keep it, just add the offline
   notice that the remaining quantity may be stale.

6. **Do not modify PHP files.** All four API endpoints are already implemented.
   The payload each queue row sends must match exactly what `AssistanceService`
   sends today — compare field for field.

7. **`unawaited` import.** Use `import 'dart:async' show unawaited;`.

8. **Run `flutter analyze`** before finishing. Zero new lint errors.

---

## 13. API endpoint reference (no changes needed)

| Endpoint | Method | Key request fields |
|---|---|---|
| `api/pledge_assistance.php` | POST | `acting_user_id`, `evac_center_id`, `need_id` (optional), `item`, `unit`, `qty`, `remarks` |
| `api/update_assistance_status.php` | POST | `acting_user_id`, `assistance_id`, `action` (e.g. `'mark_sent'`, `'mark_delivered'`) |
| `api/confirm_assistance_received.php` | POST | `acting_user_id`, `assistance_id`, `qty_received` |
| `api/save_center_needs.php` | POST | `acting_user_id`, `evac_center_id`, profile fields, `items` (array), `profile_source` |

---

## 14. Role permissions — who can queue which action

Read `api/pledge_assistance.php` and the other endpoints to confirm. General
rules from the web side:

| Action | Who can do it |
|---|---|
| Pledge assistance | Mayors, Governor, PCF (MDR), PHO — anyone `can_pledge == true` per the board API |
| Update pledge status | The pledging user (mark_sent, cancel) or PCF/PHO (mark_delivered) |
| Confirm received | Barangay Captain or Secretary of the receiving barangay only |
| Save center needs | Barangay Captain or Secretary of the owning barangay only |

The server enforces these on sync. Your queue just stores the intent — do not
re-implement role checks in Flutter. The sync service will surface a `failed`
message if the user queued something they weren't allowed to do.

---

## 15. Defense paragraph (use after implementation)

> "OBILAK's Needs & Assistance module implements **offline-first bidirectional
> sync with eventual consistency**. Mayors, PCF, and PHO coordinators can
> pledge assistance items to evacuation centers without internet connectivity.
> Barangay Captains and Secretaries can save center needs and confirm receipt
> of donated goods while offline. All four write operations — pledge creation,
> pledge status updates, receipt confirmation, and center needs declaration —
> are queued locally in SQLite, scoped by user ID to prevent data leakage, and
> automatically flushed to the MySQL server when connectivity resumes. The server
> acts as the single source of truth and enforces all business rules. If a queued
> action is rejected (for example, a pledge is cancelled by someone else before
> it syncs), the device receives the rejection message and reverts the optimistic
> display. All devices eventually converge to the same consistent state —
> regardless of the order or timing of individual connections."
