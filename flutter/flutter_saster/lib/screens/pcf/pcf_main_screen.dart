import 'package:flutter/material.dart';

import '../../constants/api_config.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_coordinator.dart';
import '../../widgets/offline_data_status.dart';
import '../../widgets/server_required_notice.dart';
import '../login_screen.dart';
import '../shared/add_evacuation_center_screen.dart';
import '../shared/add_hotline_screen.dart';
import '../shared/profile_screen.dart';
import 'add_alert_screen.dart';
import 'pcf_alerts_screen.dart';
import 'pcf_dashboard_screen.dart';
import 'pcf_evacuation_centers_screen.dart';
import 'pcf_hotlines_screen.dart';
import 'pcf_map_screen.dart';
import 'review_reports_screen.dart';
import '../shared/assistance_board_screen.dart';

class PcfMainScreen extends StatefulWidget {
  const PcfMainScreen({super.key});

  @override
  State<PcfMainScreen> createState() => _PcfMainScreenState();
}

class _PcfMainScreenState extends State<PcfMainScreen> {
  int selectedIndex = 0;
  int reportsRefreshToken = 0;
  int alertsRefreshToken = 0;
  int ecRefreshToken = 0;
  int hotlineRefreshToken = 0;
  int assistanceRefreshToken = 0;

  /// Bumped when the API becomes reachable again; remounts the active tab so
  /// its cached view refreshes immediately after a recovery.
  int reachabilityToken = 0;
  ApiReachabilityStatus _lastApiStatus = ApiReachabilityStatus.unknown;

  @override
  void initState() {
    super.initState();
    OfflineSyncCoordinator.instance.addListener(_onReachabilityChanged);
  }

  @override
  void dispose() {
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

  final List<String> titles = const [
    'Dashboard',
    'Reports',
    'Alerts',
    'Emergency Hotlines',
    'Barangay Map',
    'Evacuation Centers',
    'Needs & Assistance',
    'Profile',
  ];

  Future<void> logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> openAddAlert() async {
    if (isServerUnreachable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(kOfflineWriteMessage), backgroundColor: Colors.red),
      );
      return;
    }
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddAlertScreen()));
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 2;
        alertsRefreshToken++;
      });
    }
  }

  Future<void> openAddHotline() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddHotlineScreen()));
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 3;
        hotlineRefreshToken++;
      });
    }
  }

  Future<void> openAddEvacuationCenter() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddEvacuationCenterScreen()));
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 5;
        ecRefreshToken++;
      });
    }
  }

  Widget? buildFab() {
    if (AuthService.isMayor) return null;

    if (selectedIndex == 2) {
      return FloatingActionButton(
        onPressed: openAddAlert,
        tooltip: 'Add Alert',
        child: const Icon(Icons.notification_add_outlined),
      );
    }

    if (selectedIndex == 3) {
      return FloatingActionButton(
        onPressed: openAddHotline,
        tooltip: 'Add Hotline',
        child: const Icon(Icons.add_call),
      );
    }

    if (selectedIndex == 5) {
      return FloatingActionButton(
        onPressed: openAddEvacuationCenter,
        tooltip: 'Add Evacuation Center',
        child: const Icon(Icons.add),
      );
    }

    return null;
  }

  void selectScreen(int index) {
    setState(() => selectedIndex = index);
  }

  Drawer buildDrawer() {
    final String cardTitle;
    final String cardSubtitle;
    if (AuthService.isPcfAdmin) {
      cardTitle = 'MDR Admin';
      cardSubtitle = 'MDR Admin';
    } else if (AuthService.isMdrKalibo) {
      cardTitle = 'MDRRMO KALIBO';
      cardSubtitle = 'MDRRMO';
    } else if (AuthService.isMdrIbajay) {
      cardTitle = 'MDRRMO IBAJAY';
      cardSubtitle = 'MDRRMO';
    } else if (AuthService.isMayorIbajay) {
      cardTitle = 'MAYOR IBAJAY';
      cardSubtitle = 'Mayor';
    } else if (AuthService.isMayorKalibo) {
      cardTitle = 'MAYOR KALIBO';
      cardSubtitle = 'Mayor';
    } else {
      cardTitle = AuthService.currentName ?? 'PCF';
      cardSubtitle = 'PCF';
    }

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              title: Text(cardTitle, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
              subtitle: Text(cardSubtitle, style: const TextStyle(color: AppColors.textMuted)),
            ),
            const Divider(),
            if (!AuthService.isMdrKalibo &&
                !AuthService.isMdrIbajay &&
                !AuthService.isMayor) ...[
              _MunicipalityFilter(
                onFilterChanged: () => setState(() {
                  assistanceRefreshToken++;
                }),
              ),
              const Divider(),
            ],
            if (AuthService.isPcfAdmin)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Manage Users'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const _MdrManageUsersScreen(),
                  ));
                },
              ),
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
            ListTile(
              selected: selectedIndex == 6,
              leading: const Icon(Icons.volunteer_activism_outlined),
              title: const Text('Needs & Assistance'),
              onTap: () {
                Navigator.pop(context);
                selectScreen(6);
              },
            ),
            ListTile(
              selected: selectedIndex == 7,
              leading: const Icon(Icons.person_outline),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                selectScreen(7);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const PcfDashboardScreen(),
      ReviewReportsScreen(
        refreshToken: reportsRefreshToken,
        onStatusChanged: () => setState(() => reportsRefreshToken++),
      ),
      PcfAlertsScreen(refreshToken: alertsRefreshToken),
      PcfHotlinesScreen(refreshToken: hotlineRefreshToken),
      const PcfMapScreen(),
      PcfEvacuationCentersScreen(refreshToken: ecRefreshToken),
      AssistanceBoardScreen(refreshToken: assistanceRefreshToken),
      ProfileScreen(onLogout: logout),
    ];

    return Scaffold(
      drawer: buildDrawer(),
      appBar: AppBar(
        title: Text(titles[selectedIndex]),
        actions: const [OfflineDataStatusIndicator()],
      ),
      body: KeyedSubtree(
        key: ValueKey('tab-$selectedIndex-$reachabilityToken'),
        child: screens[selectedIndex],
      ),
      floatingActionButton: buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < 4 ? selectedIndex : 0,
        onDestinationSelected: selectScreen,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none_outlined),
            selectedIcon: Icon(Icons.notifications_active),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.phone_in_talk_outlined),
            selectedIcon: Icon(Icons.phone_in_talk),
            label: 'Call',
          ),
        ],
      ),
    );
  }
}

class _MunicipalityFilter extends StatefulWidget {
  final VoidCallback onFilterChanged;
  const _MunicipalityFilter({required this.onFilterChanged});

  @override
  State<_MunicipalityFilter> createState() => _MunicipalityFilterState();
}

class _MunicipalityFilterState extends State<_MunicipalityFilter> {
  List<String> _municipalities = [];

  @override
  void initState() {
    super.initState();
    _loadMunicipalities();
  }

  Future<void> _loadMunicipalities() async {
    final list = await AuthService.getMunicipalities();
    if (mounted) setState(() => _municipalities = list);
  }

  @override
  Widget build(BuildContext context) {
    final current = AuthService.filterMunicipality;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Municipality', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: current,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Municipalities')),
              ..._municipalities.map((m) => DropdownMenuItem(value: m, child: Text(m))),
            ],
            onChanged: (value) async {
              await AuthService.setFilterMunicipality(value);
              if (mounted) {
                widget.onFilterChanged();
              }
            },
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Inline MDR Manage Users Screen (PCF MDR Admin / MDR-Kalibo / MDR-Ibajay)
// ═══════════════════════════════════════════════════════════════════════
class _MdrManageUsersScreen extends StatefulWidget {
  const _MdrManageUsersScreen();
  @override
  State<_MdrManageUsersScreen> createState() => _MdrManageUsersScreenState();
}

class _MdrManageUsersScreenState extends State<_MdrManageUsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _search = '';
  String? _error;

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
  }

  Future<void> _loadUsers() async {
    setState(() { _loading = true; _error = null; });
    final result = await _MdrUserServiceHelper.getUsers(search: _search);
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

  List<String> get _allowedSubRoles {
    if (AuthService.isPcfAdmin) {
      return ['mdr_admin', 'mdr_kalibo', 'mdr_ibajay', 'mayor_kalibo', 'mayor_ibajay'];
    }
    if (AuthService.isMdrKalibo) return ['mdr_kalibo'];
    if (AuthService.isMdrIbajay) return ['mdr_ibajay'];
    return ['mdr_kalibo'];
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final allowed = _allowedSubRoles;
    String selectedSubRole = allowed.first;

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
                if (allowed.length > 1)
                  DropdownButtonFormField<String>(
                    value: selectedSubRole,
                    decoration: const InputDecoration(labelText: 'Sub-role'),
                    items: allowed
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(_subRolePickerLabel(r)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedSubRole = v);
                    },
                  )
                else
                  Text('Sub-role: ${_subRolePickerLabel(selectedSubRole)}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                final res = await _MdrUserServiceHelper.createUser(
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
    final allowed = _allowedSubRoles;
    String selectedSubRole = user['sub_role'] ?? allowed.first;
    if (!allowed.contains(selectedSubRole)) {
      selectedSubRole = allowed.first;
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
                if (allowed.length > 1)
                  DropdownButtonFormField<String>(
                    value: selectedSubRole,
                    decoration: const InputDecoration(labelText: 'Sub-role'),
                    items: allowed
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(_subRolePickerLabel(r)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedSubRole = v);
                    },
                  )
                else
                  Text('Sub-role: ${_subRolePickerLabel(selectedSubRole)}', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _MdrUserServiceHelper.updateUser(
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
              final res = await _MdrUserServiceHelper.toggleStatus(userId: user['id']);
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
              final res = await _MdrUserServiceHelper.resetPassword(
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

  String _subRoleLabel(String? subRole) {
    switch (subRole) {
      case 'mdr_admin':
        return 'MDR Admin';
      case 'mdr_kalibo':
        return 'MDR-Kalibo';
      case 'mdr_ibajay':
        return 'MDR-Ibajay';
      case 'mayor_kalibo':
      case 'mayor_ibajay':
        return 'Mayor';
      default:
        return (subRole ?? '').toUpperCase();
    }
  }

  // Picker label keeps the town visible when choosing a mayor sub-role.
  String _subRolePickerLabel(String subRole) {
    switch (subRole) {
      case 'mayor_kalibo':
        return 'Mayor (Kalibo)';
      case 'mayor_ibajay':
        return 'Mayor (Ibajay)';
      default:
        return _subRoleLabel(subRole);
    }
  }

  IconData _roleIcon(String? subRole) {
    switch (subRole) {
      case 'mdr_admin':
        return Icons.admin_panel_settings_outlined;
      case 'mdr_kalibo':
        return Icons.location_on_outlined;
      case 'mdr_ibajay':
        return Icons.location_on_outlined;
      case 'mayor_kalibo':
        return Icons.account_balance_outlined;
      case 'mayor_ibajay':
        return Icons.account_balance_outlined;
      default:
        return Icons.person_outline;
    }
  }

  Color _roleColor(String? subRole) {
    switch (subRole) {
      case 'mdr_admin':
        return AppColors.primaryRed;
      case 'mdr_kalibo':
        return Colors.blue;
      case 'mdr_ibajay':
        return Colors.teal;
      case 'mayor_kalibo':
        return Colors.deepPurple;
      case 'mayor_ibajay':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          const OfflineDataStatusIndicator(),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
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
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _roleColor(u['sub_role']),
                                    foregroundColor: Colors.white,
                                    child: Icon(_roleIcon(u['sub_role']), size: 20),
                                  ),
                                  title: Text(u['name'] ?? ''),
                                  subtitle: Text(
                                    '${u['username']} • ${_subRoleLabel(u['sub_role'])}',
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
                                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                      if (!isSelf)
                                        PopupMenuItem(
                                          value: 'toggle',
                                          child: Text(isActive ? 'Deactivate' : 'Reactivate'),
                                        ),
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
// Helper — thin wrapper around ApiService for MDR user management
// ═══════════════════════════════════════════════════════════════════════
class _MdrUserServiceHelper {
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
        'role': 'pcf',
        'sub_role': subRole,
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
