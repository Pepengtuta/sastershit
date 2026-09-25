import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/hotline_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/hotline_cache_first_mixin.dart';
import '../../widgets/hotline_cache_status.dart';
import '../../widgets/hotline_reconnect_mixin.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/search_box.dart';
import '../shared/edit_hotline_screen.dart';

class PhoHotlinesScreen extends StatefulWidget {
  final int refreshToken;

  const PhoHotlinesScreen({super.key, this.refreshToken = 0});

  @override
  State<PhoHotlinesScreen> createState() => _PhoHotlinesScreenState();
}

class _PhoHotlinesScreenState extends State<PhoHotlinesScreen> with HotlineReconnectMixin<PhoHotlinesScreen>, HotlineCacheFirstMixin<PhoHotlinesScreen> {
  final searchController = TextEditingController();
  String selectedCategory = 'All';

  final categories = const ['All', 'Barangay', 'Municipal', 'PNP', 'Fire', 'Medical', 'Hospital', 'MDRRMO', 'PHO', 'Coast Guard', 'Other'];

  @override
  String get hotlineFallbackRole => 'pho';

  @override
  int get hotlineRefreshToken => widget.refreshToken;

  @override
  String get hotlineSearch => searchController.text.trim();

  @override
  String get hotlineCategory => selectedCategory;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
    String phoneNumber(Map<String, dynamic> hotline) {
    final hotlineNumber = hotline['hotline_number']?.toString() ?? '';
    final cellphone = hotline['cellphone_numbers']?.toString() ?? '';
    final telephone = hotline['telephone_numbers']?.toString() ?? '';
    final raw = hotlineNumber.isNotEmpty ? hotlineNumber : (cellphone.isNotEmpty ? cellphone : telephone);
    return raw.split(RegExp(r'[,;/]')).first.trim();
  }

  Future<void> callNumber(String number) async {
    if (number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No callable number found.'), backgroundColor: AppColors.primaryRed));
      return;
    }

    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call feature is not available on this device.'), backgroundColor: AppColors.primaryRed));
    }
  }

  Future<void> openEdit(Map<String, dynamic> hotline) async {
    final updated = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditHotlineScreen(hotline: hotline)));
    if (updated == true && mounted) loadHotlines();
  }

  Future<void> confirmDelete(Map<String, dynamic> hotline) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Hotline'),
        content: Text('Delete "${hotline['office_name']}"? This cannot be undone.'),
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

    final result = await HotlineService.deleteHotline(id: (hotline['id'] as num).toInt());
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hotline deleted.'), backgroundColor: AppColors.successGreen));
      loadHotlines();
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
          child: Column(
            children: [
              SearchBox(controller: searchController, hint: 'Search hotlines...', onChanged: (_) => loadHotlines()),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category == selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => selectedCategory = category);
                        loadHotlines();
                      },
                      selectedColor: AppColors.primaryRed,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textDark,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        HotlineCacheStatus(
          showingSaved: showingSaved,
          lastUpdated: lastUpdated,
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (isLoading) return const LoadingView();
              if (errorMessage != null) return ErrorState(message: errorMessage!, onRetry: loadHotlines);
              if (hotlines.isEmpty) return const EmptyState(icon: Icons.phone_in_talk_outlined, message: 'No hotlines found.');
              return RefreshIndicator(
                onRefresh: loadHotlines,
                color: AppColors.primaryRed,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: hotlines.length,
                  itemBuilder: (context, index) {
                    final hotline = Map<String, dynamic>.from(hotlines[index]);
                    final number = phoneNumber(hotline);
                    return InfoCard(
                      child: Row(
                        children: [
                          const CircleAvatar(backgroundColor: AppColors.successGreen, foregroundColor: Colors.white, child: Icon(Icons.phone_in_talk_outlined)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(hotline['office_name']?.toString() ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Category: ${hotline['category'] ?? 'Other'}', style: const TextStyle(fontSize: 12)),
                                Text('No: $number', style: const TextStyle()),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Call',
                            onPressed: () => callNumber(number),
                            icon: const Icon(Icons.call, color: AppColors.primaryRed),
                          ),
                          if (!AuthService.isReadOnlyObserver)
                            PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') openEdit(hotline);
                              if (value == 'delete') confirmDelete(hotline);
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