import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/evacuation_center_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/evacuation_center_cache_first_mixin.dart';
import '../../widgets/hotline_reconnect_mixin.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/offline_cache_status.dart';
import '../../widgets/search_box.dart';
import '../../widgets/status_badge.dart';
import '../shared/edit_evacuation_center_screen.dart';

class PhoEvacuationCentersScreen extends StatefulWidget {
  final int refreshToken;

  const PhoEvacuationCentersScreen({super.key, this.refreshToken = 0});

  @override
  State<PhoEvacuationCentersScreen> createState() => _PhoEvacuationCentersScreenState();
}

class _PhoEvacuationCentersScreenState extends State<PhoEvacuationCentersScreen>
    with
        HotlineReconnectMixin<PhoEvacuationCentersScreen>,
        EvacuationCenterCacheFirstMixin<PhoEvacuationCentersScreen> {
  final searchController = TextEditingController();

  @override
  String get centerFallbackRole => 'pho';

  @override
  String get centerSearch => searchController.text.trim();

  @override
  int get centerRefreshToken => widget.refreshToken;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> openEdit(Map<String, dynamic> center) async {
    if (await guardOfflineAction()) return;
    if (!mounted) return;
    final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditEvacuationCenterScreen(center: center)));
    if (updated == true && mounted) loadCenters();
  }

  Future<void> confirmDelete(Map<String, dynamic> center) async {
    if (await guardOfflineAction()) return;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Evacuation Center'),
        content: Text('Delete "${center['center_name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await EvacuationCenterService.deleteEvacuationCenter(id: (center['id'] as num).toInt());
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evacuation center deleted.'), backgroundColor: AppColors.successGreen));
      loadCenters();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Failed to delete.'), backgroundColor: AppColors.primaryRed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SearchBox(controller: searchController, hint: 'Search evacuation centers...', onChanged: (_) => loadCenters()),
        ),
        OfflineCacheStatus(
          showingSaved: showingSaved,
          lastUpdated: lastUpdated,
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (isLoading) return const LoadingView();
              if (errorMessage != null) return ErrorState(message: errorMessage!, onRetry: loadCenters);
              if (centers.isEmpty) return const EmptyState(icon: Icons.location_city_outlined, message: 'No evacuation centers found.');
              return RefreshIndicator(
                onRefresh: loadCenters,
                color: AppColors.primaryRed,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: centers.length,
                  itemBuilder: (context, index) {
                    final center = Map<String, dynamic>.from(centers[index]);
                    return InfoCard(
                      child: Row(
                        children: [
                          const CircleAvatar(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, child: Icon(Icons.location_city_outlined)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(center['center_name']?.toString() ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Barangay ${center['barangay'] ?? ''}', style: const TextStyle()),
                                if ((center['capacity']?.toString() ?? '').isNotEmpty) Text('Capacity: ${center['capacity']}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                          if (showingSaved) ...[
                            const SavedDataTag(),
                            const SizedBox(width: 6),
                          ],
                          StatusBadge(status: center['status']?.toString() ?? 'Available'),
                          if (!AuthService.isReadOnlyObserver)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') openEdit(center);
                              if (value == 'delete') confirmDelete(center);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Edit')])),
                              PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
