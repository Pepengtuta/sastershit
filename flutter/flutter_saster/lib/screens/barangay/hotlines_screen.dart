import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/hotline_cache_first_mixin.dart';
import '../../widgets/hotline_cache_status.dart';
import '../../widgets/hotline_reconnect_mixin.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/search_box.dart';

class HotlinesScreen extends StatefulWidget {
  const HotlinesScreen({super.key});

  @override
  State<HotlinesScreen> createState() => _HotlinesScreenState();
}

class _HotlinesScreenState extends State<HotlinesScreen> with HotlineReconnectMixin<HotlinesScreen>, HotlineCacheFirstMixin<HotlinesScreen> {
  final searchController = TextEditingController();
  String selectedCategory = 'All';

  final categories = const ['All', 'Barangay', 'Municipal', 'PNP', 'Fire', 'Medical', 'Hospital', 'MDRRMO', 'PHO', 'Coast Guard', 'Other'];

  @override
  String get hotlineFallbackRole => 'barangay';

  @override
  String? get hotlineMunicipality => AuthService.currentMunicipality;

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
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
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