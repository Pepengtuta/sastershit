import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_coordinator.dart';
import '../../services/user_service.dart';
import '../../widgets/offline_data_status.dart';
import '../../widgets/server_required_notice.dart';
import '../login_screen.dart';
import '../pcf/add_alert_screen.dart';
import '../pcf/pcf_alerts_screen.dart';
import '../shared/add_evacuation_center_screen.dart';
import '../shared/add_hotline_screen.dart';
import '../shared/profile_screen.dart';
import '../superadmin/user_activity_screen.dart';
import 'health_reports_screen.dart';
import 'pho_dashboard_screen.dart';
import 'pho_evacuation_centers_screen.dart';
import 'pho_hotlines_screen.dart';
import 'pho_map_screen.dart';
import '../shared/assistance_board_screen.dart';

class PhoMainScreen extends StatefulWidget {
  const PhoMainScreen({super.key});

  @override
  State<PhoMainScreen> createState() => _PhoMainScreenState();
}

class _PhoMainScreenState extends State<PhoMainScreen> {
  int selectedIndex = 0;
  int reportsRefreshToken = 0;
  int alertsRefreshToken = 0;
  int hotlineRefreshToken = 0;
  int ecRefreshToken = 0;
  int mapRefreshToken = 0;
  int municipalityRefreshToken = 0;
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
    // Provincial can publish alerts, but they always go to all barangays (no picker).
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddAlertScreen(forceAllBarangays: true),
      ),
    );
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 2;
        alertsRefreshToken++;
      });
    }
  }

  Future<void> openAddHotline() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddHotlineScreen()),
    );
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 3;
        hotlineRefreshToken++;
      });
    }
  }

  Future<void> openAddEc() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEvacuationCenterScreen()),
    );
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 5;
        ecRefreshToken++;
      });
    }
  }

  Widget? buildFab() {
    if (AuthService.isReadOnlyObserver) return null;
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
        onPressed: openAddEc,
        tooltip: 'Add Evacuation Center',
        child: const Icon(Icons.add_home_work_outlined),
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
    if (AuthService.isPhoAdmin) {
      cardTitle = 'Provincial Admin';
      cardSubtitle = 'Provincial';
    } else if (AuthService.isPdrrmo) {
      cardTitle = 'PDRRMO';
      cardSubtitle = 'PDRRMO';
    } else if (AuthService.isGovernor) {
      cardTitle = 'AKLAN GOVERNOR';
      cardSubtitle = 'Governor';
    } else {
      cardTitle = AuthService.currentName ?? 'Provincial';
      cardSubtitle = 'Provincial';
    }

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.health_and_safety_outlined),
              ),
              title: Text(
                cardTitle,
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                cardSubtitle,
                style: const TextStyle(color: AppColors.textMuted),
              ),
            ),
            const Divider(),
            _MunicipalityFilter(
              onFilterChanged: () => setState(() {
                reportsRefreshToken++;
                hotlineRefreshToken++;
                ecRefreshToken++;
                mapRefreshToken++;
                municipalityRefreshToken++;
                assistanceRefreshToken++;
              }),
            ),
            const Divider(),
            if (AuthService.isPhoAdmin) ...[
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Manage Users'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _PhoManageUsersScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_outlined),
                title: const Text('Activity Log'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Activity Log')),
                          body: const UserActivityScreen(),
                        ),
                      ),
                    );
                },
              ),
            ],
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
      PhoDashboardScreen(
        key: ValueKey('pho-dashboard-$municipalityRefreshToken'),
      ),
      HealthReportsScreen(
        refreshToken: reportsRefreshToken,
        onStatusChanged: () => setState(() => reportsRefreshToken++),
      ),
      PcfAlertsScreen(refreshToken: alertsRefreshToken),
      PhoHotlinesScreen(refreshToken: hotlineRefreshToken),
      PhoMapScreen(refreshToken: mapRefreshToken),
      PhoEvacuationCentersScreen(refreshToken: ecRefreshToken),
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
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
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
    if (mounted) setState(() => _municipalities = list.toSet().toList());
  }

  @override
  Widget build(BuildContext context) {
    final saved = AuthService.filterMunicipality;
    final current = _municipalities.contains(saved) ? saved : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Municipality',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
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
              const DropdownMenuItem(
                value: null,
                child: Text('All Municipalities'),
              ),
              ..._municipalities.map(
                (m) => DropdownMenuItem(value: m, child: Text(m)),
              ),
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
// PHO Admin Manage Users Screen — manages PDRRMO accounts only.
// ═══════════════════════════════════════════════════════════════════════
class _PhoManageUsersScreen extends StatefulWidget {
  const _PhoManageUsersScreen();

  @override
  State<_PhoManageUsersScreen> createState() => _PhoManageUsersScreenState();
}

class _PhoManageUsersScreenState extends State<_PhoManageUsersScreen> {
  List<dynamic> _users = [];
  bool _loading = true;
  String _search = '';
  String? _error;

  static const List<String> _allowedSubRoles = ['pdrrmo', 'governor'];
  String _selectedSubRole = 'pdrrmo';

  static String _subRoleName(String subRole) =>
      subRole == 'governor' ? 'Governor' : 'PDRRMO';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await UserService.getUsers(search: _search);
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

  void _showMessage(Map<String, dynamic> res) {
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
    _loadUsers();
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Provincial Account'),
        content: Column(
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
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedSubRole,
              decoration: const InputDecoration(labelText: 'Sub-role'),
              items: _allowedSubRoles
                  .map((r) => DropdownMenuItem(
                        value: r,
                        child: Text(_subRoleName(r)),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) _selectedSubRole = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || userCtrl.text.isEmpty || passCtrl.text.isEmpty) {
                return;
              }
              Navigator.pop(ctx);
              final res = await UserService.createUser(
                name: nameCtrl.text.trim(),
                username: userCtrl.text.trim(),
                password: passCtrl.text.trim(),
                subRole: _selectedSubRole,
              );
              _showMessage(res);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> user) {
    final nameCtrl = TextEditingController(text: user['name']);
    final userCtrl = TextEditingController(text: user['username']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Provincial Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
            const SizedBox(height: 8),
            TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Sub-role: ${_subRoleName(user['sub_role']?.toString() ?? 'pdrrmo')}', style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await UserService.updateUser(
                userId: int.parse(user['id'].toString()),
                name: nameCtrl.text.trim(),
                username: userCtrl.text.trim(),
                subRole: user['sub_role']?.toString(),
              );
              _showMessage(res);
            },
            child: const Text('Save'),
          ),
        ],
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
              final res = await UserService.toggleStatus(userId: int.parse(user['id'].toString()));
              _showMessage(res);
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
              final res = await UserService.resetPassword(
                userId: int.parse(user['id'].toString()),
                password: passCtrl.text.trim(),
              );
              _showMessage(res);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
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
            tooltip: 'Create PDRRMO',
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
                hintText: 'Search PDRRMO users...',
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
                                  leading: const CircleAvatar(
                                    backgroundColor: AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    child: Icon(Icons.emergency_outlined, size: 20),
                                  ),
                                  title: Text(u['name'] ?? ''),
                                  subtitle: Text(
                                    '${u['username']} • PDRRMO',
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
