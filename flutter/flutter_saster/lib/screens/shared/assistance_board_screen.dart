import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/assistance_repository.dart';
import '../../services/assistance_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/fulfilled_chip.dart';
import '../../widgets/hotline_reconnect_mixin.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/need_progress_bar.dart';
import '../../widgets/offline_cache_status.dart';
import '../../widgets/pledge_ledger_row.dart';
import '../../widgets/search_box.dart';
import '../../widgets/status_badge.dart';

/// Shown when the device is offline and no saved assistance board exists on
/// this device yet (first use).
const String _boardFirstUseOfflineMessage =
    "You're offline and no saved assistance data is available on this device "
    'yet.\n\nConnect to the internet once to download and save it for offline '
    'viewing.';

class AssistanceBoardScreen extends StatefulWidget {
  final int refreshToken;

  const AssistanceBoardScreen({super.key, this.refreshToken = 0});

  @override
  State<AssistanceBoardScreen> createState() => _AssistanceBoardScreenState();
}

class _AssistanceBoardScreenState extends State<AssistanceBoardScreen>
    with HotlineReconnectMixin<AssistanceBoardScreen> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? data;
  DateTime? lastUpdated;
  bool showingSaved = false;
  bool offline = false;
  bool _loadInProgress = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _unmetOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void onNetworkRestored() => loadBoard();

  List<Map<String, dynamic>> _visibleCenters(List<dynamic> rawList) {
    if (!_unmetOnly && _searchQuery.isEmpty) return _sortedCenters(rawList);
    return _sortedCenters(rawList).where((center) {
      if (_unmetOnly && _urgencyFor(center) == _Urgency.green) return false;
      if (_searchQuery.isNotEmpty) {
        final name = center['center_name']?.toString().toLowerCase() ?? '';
        final barangay = center['barangay']?.toString().toLowerCase() ?? '';
        if (!name.contains(_searchQuery) && !barangay.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  void didUpdateWidget(covariant AssistanceBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      loadBoard();
    }
  }

  Future<void> loadBoard() async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    setState(() {
      isLoading = true;
      errorMessage = null;
      showingSaved = false;
    });

    final userId = AuthService.currentUserId ?? 0;
    final role = AuthService.currentRole ?? '';
    final municipality = AuthService.effectiveMunicipality;

    final cached = await AssistanceRepository.instance.getCachedBoard(
      userId: userId,
      role: role,
      municipality: municipality,
    );

    if (!mounted) {
      _loadInProgress = false;
      return;
    }

    if (cached.hasCache) {
      setState(() {
        data = cached.data;
        lastUpdated = cached.lastUpdated;
        isLoading = false;
      });
    }

    if (!await _isNetworkAvailable()) {
      if (!mounted) {
        _loadInProgress = false;
        return;
      }
      _applyBoardFailure(cached);
      _loadInProgress = false;
      return;
    }

    final refreshed = await AssistanceRepository.instance.refreshBoard(
      userId: userId,
      role: role,
      municipality: municipality,
    );

    if (!mounted) {
      _loadInProgress = false;
      return;
    }

    if (refreshed.offline) {
      _applyBoardFailure(cached);
      _loadInProgress = false;
      return;
    }

    setState(() {
      data = refreshed.data;
      lastUpdated = refreshed.lastUpdated;
      showingSaved = false;
      offline = false;
      isLoading = false;
    });
    _loadInProgress = false;
  }

  void _applyBoardFailure(AssistanceBoardLoadResult cached) {
    setState(() {
      isLoading = false;
      offline = true;
      if (cached.hasCache) {
        data = cached.data;
        lastUpdated = cached.lastUpdated;
        showingSaved = true;
      } else {
        errorMessage = _boardFirstUseOfflineMessage;
      }
    });
  }

  Future<bool> _isNetworkAvailable() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.primaryRed : AppColors.successGreen,
      ),
    );
  }

  Future<void> _pledge({
    required int centerId,
    int? needId,
    String initialItem = '',
    String initialUnit = 'packs',
    int remaining = -1,
  }) async {
    if (!await _isNetworkAvailable()) {
      _showMessage(
        'Reconnect to the internet to pledge assistance.',
        error: true,
      );
      return;
    }
    if (!mounted) return;
    final itemCtrl = TextEditingController(text: initialItem);
    final qtyCtrl = TextEditingController();
    final remarkCtrl = TextEditingController();
    String unit = initialUnit;

    const units = ['packs', 'sacks', 'boxes', 'liters', 'pcs', 'kits'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pledge Assistance'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: itemCtrl,
                decoration: const InputDecoration(
                  labelText: 'Item',
                  hintText: 'e.g. Rice',
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Quantity'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      items: units
                          .map(
                            (u) => DropdownMenuItem(value: u, child: Text(u)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) unit = v;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: remarkCtrl,
                decoration: const InputDecoration(
                  labelText: 'Remarks (optional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit Pledge'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    final item = itemCtrl.text.trim();
    if (item.isEmpty || qty <= 0) {
      _showMessage(
        'Please enter an item and a positive quantity.',
        error: true,
      );
      return;
    }

    // Soft over-pledge warning (warn but don't block), mirroring the web:
    // Cancel aborts the pledge; Continue records it anyway (server sets the
    // over-pledge audit flag).
    if (needId != null && remaining >= 0 && qty > remaining) {
      if (!mounted) return;
      final excess = qty - remaining;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Over-pledge'),
          content: Text(
            'Only $remaining $unit still needed for $item \u2014 you\u2019re '
            'pledging $qty ($excess more than needed). Continue anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }

    final result = await AssistanceService.pledge(
      evacCenterId: centerId,
      needId: needId,
      item: item,
      unit: unit,
      qty: qty,
      remarks: remarkCtrl.text.trim(),
    );

    if (result['success'] == true) {
      var message = result['message']?.toString() ?? 'Pledge recorded.';
      final over =
          (result['data'] is Map) &&
          (result['data'] as Map)['over_pledge'] == true;
      if (over) {
        message +=
            ' Flagged as over-pledge (exceeds what\u2019s still needed).';
      }
      _showMessage(message);
      loadBoard();
    } else {
      _showMessage(
        result['message']?.toString() ?? 'Failed to record the pledge.',
        error: true,
      );
    }
  }

  Future<void> _changeStatus(int id, String action) async {
    if (!await _isNetworkAvailable()) {
      _showMessage(
        'Reconnect to the internet to update a pledge status.',
        error: true,
      );
      return;
    }
    final result = await AssistanceService.updateStatus(
      assistanceId: id,
      action: action,
    );
    if (result['success'] == true) {
      _showMessage(result['message']?.toString() ?? 'Status updated.');
      loadBoard();
    } else {
      _showMessage(
        result['message']?.toString() ?? 'Failed to update status.',
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingView();
    if (errorMessage != null)
      return ErrorState(message: errorMessage!, onRetry: loadBoard);

    final board = data!;
    final canPledge = board['can_pledge'] == true && !offline;
    final zeroCenters = (board['zero_pledge_centers'] as List?) ?? const [];
    final centers = (board['centers'] as List?) ?? const [];
    final summary = (board['summary'] as Map?)?.cast<String, dynamic>() ?? {};
    final visibleCenters = _visibleCenters(centers);

    return RefreshIndicator(
      onRefresh: loadBoard,
      color: AppColors.primaryRed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Needs & Assistance',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Scope: ${board['scope_label'] ?? 'All Municipalities'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          OfflineCacheStatus(
            showingSaved: showingSaved,
            lastUpdated: lastUpdated,
          ),
          const SizedBox(height: 12),
          if (showingSaved)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SavedDataTag(fontSize: 11),
              ),
            ),
          _SummaryRow(summary: summary),
          if (zeroCenters.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ZeroPledgeBanner(centers: zeroCenters, onReload: loadBoard),
          ],
          const SizedBox(height: 12),
          SearchBox(
            controller: _searchController,
            hint: 'Search barangay or center...',
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 8),
          FilterChip(
            label: const Text('Unmet only'),
            selected: _unmetOnly,
            onSelected: (value) => setState(() => _unmetOnly = value),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(height: 4),
          if (centers.isEmpty)
            const EmptyState(
              icon: Icons.volunteer_activism_outlined,
              message: 'No declared center needs found in this scope.',
            )
          else if (visibleCenters.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              message: 'No centers match your search or filter.',
            )
          else
            ...visibleCenters.map((center) {
              return _CenterTile(
                key: ValueKey(center['id']),
                center: center,
                canPledge: canPledge,
                onPledge: _pledge,
                onUpdateStatus: offline ? null : _changeStatus,
              );
            }),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _SummaryRow({required this.summary});

  int _value(String key) => int.tryParse(summary[key]?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final items = [
      {'label': 'Unmet', 'value': _value('unmet_total')},
      {'label': 'Incoming', 'value': _value('incoming_total')},
      {'label': 'Awaiting', 'value': _value('pending_confirmation_total')},
      {'label': 'Pledges', 'value': _value('pledge_count')},
      {'label': 'My Pledges', 'value': _value('my_pledges')},
    ];

    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Column(
              children: [
                Text(
                  item['value'].toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: item['label'] == 'Unmet'
                        ? AppColors.primaryRed
                        : item['label'] == 'Awaiting'
                        ? const Color(0xFF0E7A5F)
                        : AppColors.textDark,
                  ),
                ),
                Text(
                  item['label'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ZeroPledgeBanner extends StatelessWidget {
  final List<dynamic> centers;
  final VoidCallback onReload;

  const _ZeroPledgeBanner({required this.centers, required this.onReload});

  @override
  Widget build(BuildContext context) {
    final names = centers
        .whereType<Map>()
        .map((c) => c['center_name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFF92400E),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Centers with needs but no pledges yet:',
                  style: const TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.refresh_outlined,
                  size: 18,
                  color: Color(0xFF92400E),
                ),
                onPressed: onReload,
                tooltip: 'Refresh',
              ),
            ],
          ),
          Text(
            names,
            style: const TextStyle(
              color: Color(0xFF92400E),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Urgency { red, yellow, green }

int _urgencyRank(_Urgency urgency) => switch (urgency) {
  _Urgency.red => 0,
  _Urgency.yellow => 1,
  _Urgency.green => 2,
};

_Urgency _urgencyFor(Map<String, dynamic> center) {
  final needs = (center['needs'] as List?) ?? const [];
  var anyUnmet = false;
  var anyZeroPledgeUnmet = false;
  for (final raw in needs) {
    final need = Map<String, dynamic>.from(raw as Map);
    final unmet = int.tryParse(need['unmet']?.toString() ?? '0') ?? 0;
    final incoming = int.tryParse(need['incoming_qty']?.toString() ?? '0') ?? 0;
    if (unmet > 0) {
      anyUnmet = true;
      if (incoming == 0) anyZeroPledgeUnmet = true;
    }
  }
  if (!anyUnmet) return _Urgency.green;
  return anyZeroPledgeUnmet ? _Urgency.red : _Urgency.yellow;
}

String _summaryLine(Map<String, dynamic> center, _Urgency urgency) {
  final needs = (center['needs'] as List?) ?? const [];
  String? zeroPledgeItem;
  var zeroPledgeUnmet = 0;
  String? anyItem;
  var anyUnmet = 0;
  for (final raw in needs) {
    final need = Map<String, dynamic>.from(raw as Map);
    final unmet = int.tryParse(need['unmet']?.toString() ?? '0') ?? 0;
    if (unmet <= 0) continue;
    final incoming = int.tryParse(need['incoming_qty']?.toString() ?? '0') ?? 0;
    if (incoming == 0) {
      if (unmet > zeroPledgeUnmet) {
        zeroPledgeItem = need['item']?.toString() ?? '';
        zeroPledgeUnmet = unmet;
      }
    } else if (unmet > anyUnmet) {
      anyItem = need['item']?.toString() ?? '';
      anyUnmet = unmet;
    }
  }
  if (zeroPledgeItem != null)
    return '$zeroPledgeItem: unmet $zeroPledgeUnmet \u00b7 no pledges';
  if (anyItem != null) return '$anyItem: unmet $anyUnmet';
  return 'All needs met';
}

List<Map<String, dynamic>> _sortedCenters(List<dynamic> rawList) {
  final list = rawList
      .map((raw) => Map<String, dynamic>.from(raw as Map))
      .toList();
  list.sort((a, b) {
    final rankCompare = _urgencyRank(
      _urgencyFor(a),
    ).compareTo(_urgencyRank(_urgencyFor(b)));
    if (rankCompare != 0) return rankCompare;
    final muni = (a['municipality']?.toString() ?? '').compareTo(
      b['municipality']?.toString() ?? '',
    );
    if (muni != 0) return muni;
    final barangay = (a['barangay']?.toString() ?? '').compareTo(
      b['barangay']?.toString() ?? '',
    );
    if (barangay != 0) return barangay;
    return (a['center_name']?.toString() ?? '').compareTo(
      b['center_name']?.toString() ?? '',
    );
  });
  return list;
}

class _CenterTile extends StatefulWidget {
  final Map<String, dynamic> center;
  final bool canPledge;
  final Future<void> Function({
    required int centerId,
    int? needId,
    String initialItem,
    String initialUnit,
    int remaining,
  })
  onPledge;
  final Future<void> Function(int id, String action)? onUpdateStatus;

  const _CenterTile({
    super.key,
    required this.center,
    required this.canPledge,
    required this.onPledge,
    required this.onUpdateStatus,
  });

  @override
  State<_CenterTile> createState() => _CenterTileState();
}

class _CenterTileState extends State<_CenterTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = widget.center;
    final urgency = _urgencyFor(center);
    final dotColor = switch (urgency) {
      _Urgency.red => AppColors.primaryRed,
      _Urgency.yellow => AppColors.warningYellow,
      _Urgency.green => AppColors.successGreen,
    };

    final needs = (center['needs'] as List?) ?? const [];
    var openNeeds = 0;
    for (final raw in needs) {
      final n = Map<String, dynamic>.from(raw as Map);
      final qty = int.tryParse(n['qty_needed']?.toString() ?? '0') ?? 0;
      final received = int.tryParse(n['received_qty']?.toString() ?? '0') ?? 0;
      if (qty > 0 && received < qty) openNeeds++;
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          center['center_name']?.toString() ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${center['barangay']}, ${center['municipality']}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _summaryLine(center, urgency),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(
                    status: center['status']?.toString() ?? 'Available',
                  ),
                  if (needs.isNotEmpty && openNeeds == 0) ...[
                    const SizedBox(width: 6),
                    const FulfilledChip(label: 'Fully Supplied'),
                  ] else if (openNeeds > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningYellow.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.warningYellow.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        openNeeds == 1
                            ? '1 Need Open'
                            : '$openNeeds Needs Open',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.warningYellow,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _CenterDetail(
                      center: center,
                      canPledge: widget.canPledge,
                      onPledge: widget.onPledge,
                      onUpdateStatus: widget.onUpdateStatus,
                      onCollapse: () => setState(() => _expanded = !_expanded),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _CenterDetail extends StatelessWidget {
  final Map<String, dynamic> center;
  final bool canPledge;
  final Future<void> Function({
    required int centerId,
    int? needId,
    String initialItem,
    String initialUnit,
    int remaining,
  })
  onPledge;
  final Future<void> Function(int id, String action)? onUpdateStatus;

  final VoidCallback onCollapse;

  const _CenterDetail({
    required this.center,
    required this.canPledge,
    required this.onPledge,
    required this.onUpdateStatus,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final needs = (center['needs'] as List?) ?? const [];
    final ledger = (center['ledger'] as List?) ?? const [];
    final types = (center['types'] as List?) ?? const [];
    final profile = (center['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (center['incident'] != null)
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: AppColors.successGreen,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Backed by ${(center['incident'] as Map)['disaster_type']} incident · ${(center['incident'] as Map)['status_label'] ?? (center['incident'] as Map)['status']}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: AppColors.warningYellow,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Unverified: no linked incident report',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warningYellow,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        Text(
          'Who\u2019s inside',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (types.isEmpty)
          Text('No profile declared yet.', style: theme.textTheme.bodySmall)
        else ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: types.map((raw) {
              final p = Map<String, dynamic>.from(raw as Map);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${p['label'] ?? p['code']}: ${p['count']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            'Total: ${profile['total_evacuees'] ?? 0} evacuees · ${profile['families'] ?? 0} families',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'Center Needs',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        if (needs.isEmpty)
          Text('No needs declared.', style: theme.textTheme.bodySmall)
        else
          ...needs.map((raw) {
            final need = Map<String, dynamic>.from(raw as Map);
            return _NeedRow(
              need: need,
              canPledge: canPledge,
              onPledge: onPledge,
              centerId: center['id'] as int,
            );
          }),
        if (ledger.isNotEmpty) ...[
          const Divider(height: 22),
          Text(
            'Assistance Ledger',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          ...ledger.map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            return PledgeLedgerRow(row: row, onUpdateStatus: onUpdateStatus);
          }),
        ],
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: onCollapse,
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            label: const Text('Collapse'),
          ),
        ),
      ],
    );
  }
}

class _NeedRow extends StatelessWidget {
  final Map<String, dynamic> need;
  final bool canPledge;
  final int? centerId;
  final Future<void> Function({
    required int centerId,
    int? needId,
    String initialItem,
    String initialUnit,
    int remaining,
  })
  onPledge;

  const _NeedRow({
    required this.need,
    required this.canPledge,
    required this.onPledge,
    this.centerId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needed = int.tryParse(need['qty_needed']?.toString() ?? '0') ?? 0;
    final received = int.tryParse(need['received_qty']?.toString() ?? '0') ?? 0;
    final incoming = int.tryParse(need['incoming_qty']?.toString() ?? '0') ?? 0;
    final fulfilled = need['fulfilled'] == true;
    final unit = need['unit']?.toString() ?? '';
    int remainingCommitted = needed - received - incoming;
    if (remainingCommitted < 0) remainingCommitted = 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: fulfilled ? const EdgeInsets.all(10) : EdgeInsets.zero,
        decoration: fulfilled
            ? BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.successGreen.withValues(alpha: 0.35),
                ),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${need['item'] ?? ''}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (fulfilled) ...[
                  const FulfilledChip(),
                  const SizedBox(width: 8),
                ],
                if (canPledge)
                  InkWell(
                    onTap: () => onPledge(
                      centerId: centerId ?? 0,
                      needId: int.tryParse(need['id']?.toString() ?? '0'),
                      initialItem: need['item']?.toString() ?? '',
                      initialUnit: unit,
                      remaining: remainingCommitted,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.successGreen.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'Pledge',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.successGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            NeedProgressBar(
              needed: needed,
              received: received,
              unit: unit,
              incoming: incoming,
              fulfilled: fulfilled,
            ),
          ],
        ),
      ),
    );
  }
}
