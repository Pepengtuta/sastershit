import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_coordinator.dart';
import '../../widgets/offline_data_status.dart';
import '../login_screen.dart';
import '../pcf/add_alert_screen.dart';
import '../pcf/pcf_alerts_screen.dart';
import '../pcf/review_reports_screen.dart';
import '../shared/add_evacuation_center_screen.dart';
import '../shared/add_hotline_screen.dart';
import '../shared/profile_screen.dart';
import 'manage_users_screen.dart';
import 'superadmin_dashboard_screen.dart';
import 'superadmin_evacuation_centers_screen.dart';
import 'superadmin_hotlines_screen.dart';
import 'superadmin_map_screen.dart';
import 'user_activity_screen.dart';

class SuperadminMainScreen extends StatefulWidget {
  const SuperadminMainScreen({super.key});

  @override
  State<SuperadminMainScreen> createState() => _SuperadminMainScreenState();
}

class _SuperadminMainScreenState extends State<SuperadminMainScreen> {
  int selectedIndex = 0;
  int reportsRefreshToken = 0;
  int alertsRefreshToken = 0;
  int ecRefreshToken = 0;
  int hotlineRefreshToken = 0;

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
    'All Reports',
    'Alerts',
    'Emergency Hotlines',
    'Barangay Map',
    'Manage Users',
    'Evacuation Centers',
    'Profile',
    'User Activity',
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
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddAlertScreen()));
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 2;
        alertsRefreshToken++;
      });
    }
  }

  Future<void> openAddEc() async {
    final created = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AddEvacuationCenterScreen()));
    if (created == true && mounted) {
      setState(() {
        selectedIndex = 6;
        ecRefreshToken++;
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

  /// Superadmin can add hotlines (index 3) and evacuation centers (index 6).
  Widget? buildFab() {
    if (selectedIndex == 6) {
      return FloatingActionButton(
        onPressed: openAddEc,
        tooltip: 'Add Evacuation Center',
        child: const Icon(Icons.add_home_work_outlined),
      );
    }
    if (selectedIndex == 3) {
      return FloatingActionButton(
        onPressed: openAddHotline,
        tooltip: 'Add Hotline',
        child: const Icon(Icons.add_call),
      );
    }
    return null;
  }

  void selectScreen(int index) {
    setState(() => selectedIndex = index);
  }

  Drawer buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.admin_panel_settings_outlined),
              ),
              title: Text(AuthService.currentName ?? 'Superadmin', style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold)),
              subtitle: const Text('Superadmin account', style: TextStyle(color: AppColors.textMuted)),
            ),
            const Divider(),
            _MunicipalityFilter(
              onFilterChanged: () => setState(() {}),
            ),
            const Divider(),
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
              leading: const Icon(Icons.people_outline),
              title: const Text('Manage Users'),
              onTap: () {
                Navigator.pop(context);
                selectScreen(5);
              },
            ),
            ListTile(
              selected: selectedIndex == 8,
              leading: const Icon(Icons.history),
              title: const Text('User Activity'),
              onTap: () {
                Navigator.pop(context);
                selectScreen(8);
              },
            ),
            ListTile(
              selected: selectedIndex == 6,
              leading: const Icon(Icons.location_city_outlined),
              title: const Text('Evacuation Centers'),
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
      const SuperadminDashboardScreen(),
      ReviewReportsScreen(
        refreshToken: reportsRefreshToken,
        onStatusChanged: () => setState(() => reportsRefreshToken++),
        allowStatusActions: false,
      ),
      PcfAlertsScreen(refreshToken: alertsRefreshToken),
      SuperadminHotlinesScreen(refreshToken: hotlineRefreshToken),
      const SuperadminMapScreen(),
      const ManageUsersScreen(),
      SuperadminEvacuationCentersScreen(refreshToken: ecRefreshToken),
      ProfileScreen(onLogout: logout),
      const UserActivityScreen(),
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
