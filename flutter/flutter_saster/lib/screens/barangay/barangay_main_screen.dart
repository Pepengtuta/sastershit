import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/api_config.dart';
import '../../constants/app_colors.dart';
import '../../services/alert_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/barangay_service.dart';
import '../../services/offline_report_sync.dart';
import '../../services/offline_sync_coordinator.dart';
import '../../widgets/offline_data_status.dart';
import '../../widgets/server_required_notice.dart';
import '../login_screen.dart';
import '../shared/profile_screen.dart';
import 'alerts_screen.dart';
import 'barangay_dashboard_screen.dart';
import 'create_incident_screen.dart';
import 'evacuation_centers_screen.dart';
import 'hotlines_screen.dart';
import 'map_screen.dart';
import 'reports_screen.dart';
import 'saved_reports_screen.dart';

class BarangayMainScreen extends StatefulWidget {
  const BarangayMainScreen({super.key});

  @override
  State<BarangayMainScreen> createState() => _BarangayMainScreenState();
}

class _BarangayMainScreenState extends State<BarangayMainScreen>
    with SingleTickerProviderStateMixin {
  int selectedIndex = 0;
  int reportsRefreshToken = 0;
  int mapRefreshToken = 0;
  int alertsRefreshToken = 0;
  int unreadAlerts = 0;

  /// Bumped when the API becomes reachable again; remounts the active tab so
  /// its cached view refreshes immediately after a recovery.
  int reachabilityToken = 0;
  ApiReachabilityStatus _lastApiStatus = ApiReachabilityStatus.unknown;

  late final AnimationController bellController;

  @override
  void initState() {
    super.initState();
    bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    OfflineSyncCoordinator.instance.addListener(_onReachabilityChanged);
    loadUnreadAlerts();
    // A newly active session may have queued reports left over from offline
    // use; the single-flight sync flushes them if the network is reachable.
    OfflineReportSync.instance.syncForCurrentUser();
  }

  @override
  void dispose() {
    bellController.dispose();
    OfflineSyncCoordinator.instance.removeListener(_onReachabilityChanged);
    super.dispose();
  }

  /// After the API flips from unreachable back to reachable, replace the active
  /// tab (new key) so the screen refetches instead of showing a stale error.
  void _onReachabilityChanged() {
    final current = OfflineSyncCoordinator.instance.apiStatus;
    final recovered = current == ApiReachabilityStatus.reachable &&
        _lastApiStatus == ApiReachabilityStatus.unreachable;
    _lastApiStatus = current;
    if (recovered && mounted) {
      setState(() => reachabilityToken++);
    }
  }

  // ── Role helpers ──
  bool get _canManageUsers => AuthService.canManageUsers;
  bool get _isCaptain => AuthService.isCaptain;
  bool get _isSecretary => AuthService.isSecretary;
  bool get _isTanod => AuthService.isTanod;

  // ── BHERT: 4-tab bottom nav (Dashboard, Reports, Alerts, Call) ──
  // ── Chairman/Secretary: full bottom nav (Dashboard, Reports, Alerts, Call) ──
  List<_NavDest> get _bottomNavDests {
    return [
      _NavDest(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      _NavDest(Icons.assignment_outlined, Icons.assignment, 'Reports'),
      _NavDest(Icons.notifications_none_outlined, Icons.notifications_active, 'Alerts'),
      _NavDest(Icons.phone_in_talk_outlined, Icons.phone_in_talk, 'Call'),
    ];
  }

  // ── Title per screen index (dynamic based on role) ──
  String _titleFor(int index) {
    if (index == 99) return 'Profile';
    if (_isTanod) {
      const titles = ['Dashboard', 'Reports', 'Alerts', 'Emergency Hotlines'];
      return titles[index.clamp(0, titles.length - 1)];
    }
    const titles = ['Dashboard', 'Reports', 'Alerts', 'Emergency Hotlines', 'Barangay Map', 'Evacuation Centers', 'Profile'];
    return titles[index.clamp(0, titles.length - 1)];
  }

  Future<void> loadUnreadAlerts() async {
    final userId = AuthService.currentUserId;
    final barangayId = AuthService.currentBarangayId;
    if (userId == null || barangayId == null) return;

    final result = await AlertService.getUnreadAlertCount(
      userId: userId,
      barangayId: barangayId,
    );

    if (!mounted) return;

    final count = result['success'] == true
        ? int.tryParse((result['data']?['count'] ?? 0).toString()) ?? 0
        : 0;

    setState(() => unreadAlerts = count);

    if (count > 0 && selectedIndex != 2) {
      bellController.repeat(reverse: true);
    } else {
      bellController.stop();
      bellController.reset();
    }
  }

  void clearUnreadAlerts() {
    setState(() => unreadAlerts = 0);
    bellController.stop();
    bellController.reset();
  }

  Future<void> logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> openCreateIncident() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const CreateIncidentScreen()),
    );

    if (created == true && mounted) {
      setState(() {
        selectedIndex = 1;
        reportsRefreshToken++;
        mapRefreshToken++;
      });
    }
  }

  Widget alertIcon({required bool selected}) {
    final baseIcon = Icon(selected ? Icons.notifications_active : Icons.notifications_none_outlined);

    Widget icon = unreadAlerts > 0
        ? AnimatedBuilder(
            animation: bellController,
            builder: (context, child) {
              final angle = math.sin(bellController.value * math.pi * 2) * 0.18;
              return Transform.rotate(angle: angle, child: child);
            },
            child: baseIcon,
          )
        : baseIcon;

    if (unreadAlerts <= 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -8,
          top: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primaryRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              unreadAlerts > 9 ? '9+' : unreadAlerts.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void selectScreen(int index) {
    setState(() => selectedIndex = index);
    if (index == 2) {
      clearUnreadAlerts();
      alertsRefreshToken++;
    } else if (unreadAlerts > 0) {
      bellController.repeat(reverse: true);
    }
  }

  Drawer buildDrawer() {
    final rawName = AuthService.currentName ?? '';
    final cleanName = rawName.replaceAll(RegExp(r'^(Barangay Chairman|Chairman|Barangay Captain|Captain|Barangay Tanod|Tanod|BHERT|Barangay Secretary|Secretary)\s+', caseSensitive: false), '');
    final String cardTitle;
    if (_isCaptain) {
      cardTitle = 'Chairman';
    } else if (_isSecretary) {
      cardTitle = 'Secretary';
    } else {
      cardTitle = 'BHERT: ${cleanName.toUpperCase()}';
    }

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: _isCaptain
                    ? AppColors.primaryRed
                    : _isSecretary
                        ? Colors.blue
                        : Colors.teal,
                foregroundColor: Colors.white,
                child: Icon(_isCaptain ? Icons.shield_outlined : _isSecretary ? Icons.badge_outlined : Icons.person_outline),
              ),
              title: Text(
                cardTitle,
                style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'BRGY: ${AuthService.currentBarangayName ?? ''}',
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const Divider(),

            // ── Chairman & Secretary only: Manage Users ──
            if (_canManageUsers)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Manage Users'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const _ManageUsersScreen(),
                  ));
                },
              ),

            // ── Chairman & Secretary only: Map, Evacuation Centers ──
            if (!_isTanod) ...[
              ListTile(
                selected: selectedIndex == 4,
                leading: const Icon(Icons.map_outlined),
                title: const Text('Map'),
                onTap: () {
                  Navigator.pop(context);
                  selectScreen(4);
                },
              ),
              ListTile(
                selected: selectedIndex == 5,
                leading: const Icon(Icons.location_city_outlined),
                title: const Text('Evacuation Centers'),
                onTap: () {
                  Navigator.pop(context);
                  selectScreen(5);
                },
              ),
            ],

            ListTile(
              leading: const Icon(Icons.outbox_outlined),
              title: const Text('Saved Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SavedReportsScreen(),
                ));
              },
            ),

            ListTile(
              selected: selectedIndex == 99,
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                selectScreen(99);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final navDests = _bottomNavDests;
    final maxBottomIndex = navDests.length - 1;

    // Build screens list dynamically
    final screens = <Widget>[
      const BarangayDashboardScreen(),
      ReportsScreen(refreshToken: reportsRefreshToken),
      AlertsScreen(refreshToken: alertsRefreshToken, onAlertsRead: clearUnreadAlerts),
      const HotlinesScreen(),
    ];

    // Chairman/Secretary get Map, EC in drawer (not bottom nav)
    if (!_isTanod) {
      screens.addAll([
        MapScreen(refreshToken: mapRefreshToken),
        const EvacuationCentersScreen(),
      ]);
    }

    screens.add(ProfileScreen(onLogout: logout));

    return Scaffold(
      drawer: buildDrawer(),
      appBar: AppBar(
        title: Text(_titleFor(selectedIndex)),
        actions: const [OfflineDataStatusIndicator()],
      ),
      body: selectedIndex == 99
          ? KeyedSubtree(
              key: ValueKey('tab-99-$reachabilityToken'),
              child: screens.last, // Profile
            )
          : KeyedSubtree(
              key: ValueKey('tab-$selectedIndex-$reachabilityToken'),
              child: screens[selectedIndex],
            ),
      floatingActionButton: selectedIndex == 1 && !AuthService.isSecretary
          ? FloatingActionButton(
              onPressed: openCreateIncident,
              tooltip: 'Create Incident',
              child: const Icon(Icons.note_add_outlined),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex <= maxBottomIndex ? selectedIndex : 0,
        onDestinationSelected: (i) => selectScreen(i),
        destinations: navDests
            .map((d) => NavigationDestination(
                  icon: Icon(d.outlinedIcon),
                  selectedIcon: Icon(d.filledIcon),
                  label: d.label,
                ))
            .toList(),
      ),
    );
  }
}

/// Simple nav destination data class
class _NavDest {
  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;
  const _NavDest(this.outlinedIcon, this.filledIcon, this.label);
}

// ═══════════════════════════════════════════════════════════════════════
// Inline Manage Users Screen (Chairman / Secretary only)
// ═══════════════════════════════════════════════════════════════════════
class _ManageUsersScreen extends StatefulWidget {
  const _ManageUsersScreen();
  @override
  State<_ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<_ManageUsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _search = '';
  String? _error;
  int? _population = AuthService.currentBarangayPopulation;
  bool _savingPopulation = false;

  /// Runs [action] only while the server is reachable. User management writes
  /// are online-only: offline, a clear explanation is shown instead.
  void guardOffline(VoidCallback action) {
    if (isServerUnreachable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kOfflineWriteMessage),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    action();
  }

  /// Snackbar for a mutation result. A connection failure is surfaced as the
  /// plain online-only requirement instead of raw network text.
  void showResult(Map<String, dynamic> res) {
    if (!mounted) return;
    final message = res['message']?.toString() ?? 'Done';
    final text = ApiService.isConnectionFailure(message: message)
        ? kOfflineWriteMessage
        : message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: res['success'] == true ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadPopulation();
  }

  Future<void> _loadPopulation() async {
    final result = await BarangayService.getBarangays();
    if (!mounted || result['success'] != true) return;
    final list = result['data'] ?? [];
    for (final b in list is List ? list : <dynamic>[]) {
      if (b is Map &&
          int.tryParse(b['id'].toString()) == AuthService.currentBarangayId) {
        setState(() => _population = int.tryParse(b['population'].toString()));
        return;
      }
    }
  }

  Future<void> _savePopulation() async {
    final raw = _population?.toString() ?? '';
    if (raw.isEmpty) return;
    setState(() => _savingPopulation = true);
    final result = await BarangayService.updatePopulation(
      barangayId: AuthService.currentBarangayId ?? 0,
      population: _population!,
    );
    if (!mounted) return;
    setState(() => _savingPopulation = false);
    showResult(result);
  }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    final result = await _UserServiceHelper.getUsers(search: _search);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _users = List<dynamic>.from(result['data'] ?? []);
        _loading = false;
      });
    } else {
      setState(() {
        _error = ApiService.userMessage(result['message'] ?? 'Failed to load users.');
        _loading = false;
      });
    }
  }

  String _formatPopulation(int value) => value.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (m) => ',',
      );

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedSubRole = AuthService.isCaptain ? 'secretary' : 'tanod';
    final allowedSubRoles = AuthService.isCaptain
        ? ['secretary', 'tanod']
        : ['tanod'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedSubRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: allowedSubRoles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r[0].toUpperCase() + r.substring(1)),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedSubRole = v);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final res = await _UserServiceHelper.createUser(
                  name: nameCtrl.text.trim(),
                  username: userCtrl.text.trim(),
                  password: passCtrl.text.trim(),
                  subRole: selectedSubRole,
                );
                if (!mounted) return;
                showResult(res);
                _loadUsers();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['name']);
    final userCtrl = TextEditingController(text: user['username']);
    String selectedSubRole = user['sub_role'] ?? 'tanod';
    final allowedSubRoles = AuthService.isCaptain
        ? ['secretary', 'tanod']
        : ['tanod'];
    if (!allowedSubRoles.contains(selectedSubRole) && selectedSubRole != 'captain') {
      selectedSubRole = allowedSubRoles.first;
    }

    // Secretary cannot edit Chairman
    if (user['sub_role'] == 'captain') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot edit Chairman accounts.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
                const SizedBox(height: 8),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                if (allowedSubRoles.length > 1)
                  DropdownButtonFormField<String>(
                    initialValue: selectedSubRole,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: allowedSubRoles
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r[0].toUpperCase() + r.substring(1)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedSubRole = v);
                    },
                  )
                else
                  Text('Role: ${selectedSubRole.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _UserServiceHelper.updateUser(
                  userId: user['id'],
                  name: nameCtrl.text.trim(),
                  username: userCtrl.text.trim(),
                  subRole: selectedSubRole,
                );
                if (!mounted) return;
                showResult(res);
                _loadUsers();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmToggle(Map<String, dynamic> user) {
    final isActive = user['status'] == 'Active';
    final action = isActive ? 'Deactivate' : 'Reactivate';

    // Secretary cannot toggle Chairman
    if (user['sub_role'] == 'captain') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot deactivate Chairman accounts.'), backgroundColor: Colors.red),
      );
      return;
    }

    // Cannot toggle self
    if (user['id'] == AuthService.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot deactivate your own account.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action User'),
        content: Text('Are you sure you want to $action "${user['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await _UserServiceHelper.toggleStatus(userId: user['id']);
              if (!mounted) return;
              showResult(res);
              _loadUsers();
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passCtrl = TextEditingController();

    // Secretary cannot reset Chairman
    if (user['sub_role'] == 'captain') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot reset Chairman passwords.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset Password: ${user['name']}'),
        content: TextField(
          controller: passCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New Password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (passCtrl.text.length < 6) return;
              Navigator.pop(ctx);
              final res = await _UserServiceHelper.resetPassword(
                userId: user['id'],
                password: passCtrl.text.trim(),
              );
              if (!mounted) return;
                showResult(res);
              },
              child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  IconData _roleIcon(String? subRole) {
    switch (subRole) {
      case 'captain':
        return Icons.shield_outlined;
      case 'secretary':
        return Icons.badge_outlined;
      default:
        return Icons.person_outline;
    }
  }

  Color _roleColor(String? subRole) {
    switch (subRole) {
      case 'captain':
        return AppColors.primaryRed;
      case 'secretary':
        return Colors.blue;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          if (AuthService.canManageUsers)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: 'Create User',
              onPressed: () => guardOffline(_showCreateDialog),
            ),
        ],
      ),
      body: Column(
        children: [
          const ServerRequiredNotice(),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.groups, color: AppColors.primaryRed),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Barangay Population',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _population != null
                            ? '${AuthService.currentBarangayName ?? ''}: ${_formatPopulation(_population!)}'
                            : '--',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    onChanged: (v) =>
                        _population = int.tryParse(v) ?? 0,
                    decoration: const InputDecoration(
                      hintText: 'Population',
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _savingPopulation ? null : () => guardOffline(_savePopulation),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (v) {
                _search = v;
                _loadUsers();
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                            FilledButton.tonal(onPressed: _loadUsers, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _users.isEmpty
                        ? const Center(child: Text('No users found.'))
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            child: ListView.separated(
                              itemCount: _users.length,
                               separatorBuilder: (ctx2, idx) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final u = _users[i];
                                final isActive = u['status'] == 'Active';
                                final isSelf = u['id'] == AuthService.currentUserId;
                                final isCaptain = u['sub_role'] == 'captain';
                                final isSecViewingCap = AuthService.isSecretary && isCaptain;
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _roleColor(u['sub_role']),
                                    foregroundColor: Colors.white,
                                    child: Icon(_roleIcon(u['sub_role']), size: 20),
                                  ),
                                  title: Text(u['name'] ?? ''),
                                  subtitle: Text(
                                    '${u['username']} • ${(u['sub_role'] ?? 'tanod').toString() == 'tanod' ? 'BHERT' : (u['sub_role'] ?? '').toString().toUpperCase()}',
                                    style: TextStyle(
                                      color: isActive ? AppColors.textMuted : Colors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'edit':
                                          guardOffline(() => _showEditDialog(u));
                                          break;
                                        case 'toggle':
                                          guardOffline(() => _confirmToggle(u));
                                          break;
                                        case 'reset':
                                          guardOffline(() => _showResetPasswordDialog(u));
                                          break;
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      if (!isSecViewingCap)
                                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      if (!isSelf && !isSecViewingCap)
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(isActive ? 'Deactivate' : 'Reactivate'),
                                        ),
                                      if (!isSecViewingCap)
                                        const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Helper — thin wrapper around ApiService to avoid import issues
// ═══════════════════════════════════════════════════════════════════════
class _UserServiceHelper {
  static Future<Map<String, dynamic>> getUsers({String search = ''}) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/get_users.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'search': search,
      },
    );
  }

  static Future<Map<String, dynamic>> createUser({
    required String name,
    required String username,
    required String password,
    required String subRole,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/save_user.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'name': name,
        'username': username,
        'password': password,
        'sub_role': subRole,
        'barangay_id': AuthService.currentBarangayId,
      },
    );
  }

  static Future<Map<String, dynamic>> updateUser({
    required int userId,
    required String name,
    required String username,
    required String subRole,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/update_user.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'user_id': userId,
        'name': name,
        'username': username,
        'sub_role': subRole,
      },
    );
  }

  static Future<Map<String, dynamic>> toggleStatus({required int userId}) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/toggle_user_status.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'user_id': userId,
      },
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required int userId,
    required String password,
  }) async {
    return ApiService.postJson(
      url: '${ApiConfig.baseUrl}/reset_user_password.php',
      body: {
        'acting_user_id': AuthService.currentUserId,
        'user_id': userId,
        'password': password,
      },
    );
  }
}


