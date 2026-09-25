import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/assistance_repository.dart';
import '../../services/assistance_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/error_state.dart';
import '../../widgets/fulfilled_chip.dart';
import '../../widgets/hotline_reconnect_mixin.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/need_progress_bar.dart';
import '../../widgets/offline_cache_status.dart';
import '../../widgets/pledge_ledger_row.dart';

/// Shown when the device is offline and no saved center needs exist on this
/// device yet (first use).
const String _needsFirstUseOfflineMessage =
    "You're offline and no saved center needs are available on this device "
    'yet.\n\nConnect to the internet once to download and save them for offline '
    'viewing.';

class CenterNeedsScreen extends StatefulWidget {
  final int evacCenterId;

  const CenterNeedsScreen({super.key, required this.evacCenterId});

  @override
  State<CenterNeedsScreen> createState() => _CenterNeedsScreenState();
}

class _CenterNeedsScreenState extends State<CenterNeedsScreen>
    with HotlineReconnectMixin<CenterNeedsScreen> {
  bool isLoading = true;
  bool saving = false;
  String? errorMessage;
  String? centerName;
  DateTime? lastUpdated;
  bool showingSaved = false;
  bool offline = false;
  bool _loadInProgress = false;

  final Map<String, TextEditingController> profileCtrls = {};
  final List<Map<String, dynamic>> needRows = [];
  Map<String, dynamic>? incident;
  Map<String, dynamic>? computed;
  Map<String, dynamic>? savedProfile;
  bool useReportedTotals = false;
  List<dynamic> fulfillment = [];
  List<dynamic> ledger = [];

  static const List<String> _profileFields = [
    'Total Evacuees',
    'Families',
    'Pregnant',
    'Lactating Mothers',
    'Infants',
    'Children',
    'Older Persons',
    'PWD',
    'Sick',
    'Injured',
  ];

  /// Only the receiving barangay (Captain/Secretary) can countersign a
  /// delivered donation. The server re-checks this atomically.
  bool get _canConfirmReceived =>
      (AuthService.currentRole?.toLowerCase() == 'barangay') &&
      (AuthService.isCaptain || AuthService.isSecretary);

  /// Fulfillment state by declared need id (server payload: need_id -> received).
  Map<int, Map<String, dynamic>> get _byNeed {
    final map = <int, Map<String, dynamic>>{};
    for (final raw in fulfillment) {
      final f = Map<String, dynamic>.from(raw as Map);
      final key = int.tryParse(f['need_id']?.toString() ?? '') ?? -1;
      if (key > 0) map[key] = f;
    }
    return map;
  }

  /// A need is "Fulfilled" only once the barangay-confirmed received quantity
  /// reaches the needed quantity. New (unsaved, id 0) rows never count.
  bool _needFulfilled(int id, int qtyNeeded) {
    if (id <= 0 || qtyNeeded <= 0) return false;
    final received =
        int.tryParse(_byNeed[id]?['received']?.toString() ?? '0') ?? 0;
    return received >= qtyNeeded;
  }

  static String _fieldKey(String label) {
    switch (label) {
      case 'Total Evacuees':
        return 'total_evacuees';
      case 'Families':
        return 'families';
      case 'Pregnant':
        return 'pregnant';
      case 'Lactating Mothers':
        return 'lactating_mothers';
      case 'Infants':
        return 'infants';
      case 'Children':
        return 'children';
      case 'Older Persons':
        return 'older_persons';
      case 'PWD':
        return 'pwd';
      case 'Sick':
        return 'sick';
      case 'Injured':
        return 'injured';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    for (final label in _profileFields) {
      profileCtrls[_fieldKey(label)] = TextEditingController(text: '0');
    }
    loadData();
  }

  @override
  void onNetworkRestored() => loadData();

  @override
  void dispose() {
    for (final c in profileCtrls.values) {
      c.dispose();
    }
    for (final row in needRows) {
      (row['itemCtrl'] as TextEditingController).dispose();
      (row['qtyCtrl'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  Future<void> loadData() async {
    if (_loadInProgress) return;
    _loadInProgress = true;

    setState(() {
      isLoading = true;
      errorMessage = null;
      showingSaved = false;
    });

    final userId = AuthService.currentUserId ?? 0;

    final cached = await AssistanceRepository.instance.getCachedCenterNeeds(
      userId: userId,
      evacCenterId: widget.evacCenterId,
    );

    if (!mounted) {
      _loadInProgress = false;
      return;
    }

    if (cached.hasCache && cached.data != null) {
      setState(() {
        _applyCenterNeedsData(cached.data!);
        lastUpdated = cached.lastUpdated;
        isLoading = false;
      });
    }

    if (!await _isNetworkAvailable()) {
      if (!mounted) {
        _loadInProgress = false;
        return;
      }
      _applyNeedsFailure(cached);
      _loadInProgress = false;
      return;
    }

    final refreshed = await AssistanceRepository.instance.refreshCenterNeeds(
      userId: userId,
      evacCenterId: widget.evacCenterId,
    );

    if (!mounted) {
      _loadInProgress = false;
      return;
    }

    if (refreshed.offline || refreshed.data == null) {
      _applyNeedsFailure(cached);
      _loadInProgress = false;
      return;
    }

    setState(() {
      _applyCenterNeedsData(refreshed.data!);
      lastUpdated = refreshed.lastUpdated;
      showingSaved = false;
      offline = false;
      isLoading = false;
    });
    _loadInProgress = false;
  }

  /// Populates the form from a center-needs document (cached or live). Callers
  /// wrap this in [setState].
  void _applyCenterNeedsData(Map<String, dynamic> data) {
    final center = Map<String, dynamic>.from(data['center'] ?? {});
    final profile = (data['profile'] as Map?)?.cast<String, dynamic>() ?? {};
    final needs = (data['needs'] as List?) ?? const [];
    computed = (data['computed_headcount'] as Map?)?.cast<String, dynamic>();
    savedProfile = profile.isEmpty ? null : profile;

    for (final field in _profileFields) {
      final key = _fieldKey(field);
      var val = int.tryParse(profile[key]?.toString() ?? '') ?? 0;
      // No profile yet: pre-fill the three mappable fields from reported totals.
      if (profile.isEmpty) {
        final c = computed;
        if (c != null && key == 'total_evacuees') {
          val = int.tryParse(c['total_evacuees']?.toString() ?? '0') ?? 0;
        } else if (c != null && key == 'families') {
          val = int.tryParse(c['households']?.toString() ?? '0') ?? 0;
        } else if (c != null && key == 'children') {
          val = int.tryParse(c['children']?.toString() ?? '0') ?? 0;
        }
      }
      profileCtrls[key]!.text = val.toString();
    }

    needRows.clear();
    for (final raw in needs) {
      final need = Map<String, dynamic>.from(raw as Map);
      needRows.add({
        'id': int.tryParse(need['id']?.toString() ?? '0') ?? 0,
        'itemCtrl': TextEditingController(text: need['item']?.toString() ?? ''),
        'qtyCtrl': TextEditingController(
          text: need['qty_needed']?.toString() ?? '',
        ),
        'unit': need['unit']?.toString() ?? 'packs',
      });
    }
    if (needRows.isEmpty) {
      needRows.add({
        'id': 0,
        'itemCtrl': TextEditingController(),
        'qtyCtrl': TextEditingController(),
        'unit': 'packs',
      });
    }

    incident = (data['incident'] as Map?)?.cast<String, dynamic>();
    fulfillment = (data['fulfillment'] as List?) ?? const [];
    ledger = (data['ledger'] as List?) ?? const [];
    centerName = center['center_name']?.toString();
  }

  void _applyNeedsFailure(CenterNeedsLoadResult cached) {
    setState(() {
      isLoading = false;
      offline = true;
      if (cached.hasCache && cached.data != null) {
        _applyCenterNeedsData(cached.data!);
        lastUpdated = cached.lastUpdated;
        showingSaved = true;
      } else {
        errorMessage = _needsFirstUseOfflineMessage;
      }
    });
  }

  Future<bool> _isNetworkAvailable() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Future<void> _confirmReceived(int id, int declaredQty, String unit) async {
    if (!await _isNetworkAvailable()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reconnect to the internet to confirm a received donation.',
          ),
          backgroundColor: AppColors.warningYellow,
        ),
      );
      return;
    }
    if (!mounted) return;
    final qtyController = TextEditingController(text: declaredQty.toString());
    final approved = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final value = int.tryParse(qtyController.text.trim());
          final isValid = value != null && value >= 1 && value <= declaredQty;
          return AlertDialog(
            title: const Text('Confirm Received'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the quantity that actually arrived. A shortfall stays as still-needed.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Quantity received',
                    suffixText: unit.isEmpty ? null : unit,
                    helperText: 'Donor declared $declaredQty',
                    errorText: isValid
                        ? null
                        : (value == null
                              ? 'Enter a number'
                              : '1 to $declaredQty'),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isValid ? () => Navigator.of(ctx).pop(value) : null,
                child: const Text('Confirm Received'),
              ),
            ],
          );
        },
      ),
    );
    qtyController.dispose();
    if (approved == null || !mounted) return;

    final result = await AssistanceService.confirmReceived(
      assistanceId: id,
      qtyReceived: approved,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['message']?.toString() ??
              (result['success'] == true
                  ? 'Donation confirmed as received.'
                  : 'Could not confirm.'),
        ),
        backgroundColor: result['success'] == true ? Colors.green : Colors.red,
      ),
    );
    if (result['success'] == true) {
      await loadData();
    }
  }

  void _addNeedRow() {
    setState(() {
      needRows.add({
        'id': 0,
        'itemCtrl': TextEditingController(),
        'qtyCtrl': TextEditingController(),
        'unit': 'packs',
      });
    });
  }

  void _removeNeedRow(int index) {
    setState(() {
      final row = needRows.removeAt(index);
      (row['itemCtrl'] as TextEditingController).dispose();
      (row['qtyCtrl'] as TextEditingController).dispose();
    });
  }

  Future<void> _save() async {
    if (!await _isNetworkAvailable()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reconnect to the internet to save center needs. Your entries are '
            'kept.',
          ),
          backgroundColor: AppColors.warningYellow,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => saving = true);

    final profile = <String, dynamic>{};
    for (final field in _profileFields) {
      final key = _fieldKey(field);
      profile[key] = int.tryParse(profileCtrls[key]!.text.trim()) ?? 0;
    }

    final items = <Map<String, dynamic>>[];
    for (final row in needRows) {
      final item = (row['itemCtrl'] as TextEditingController).text.trim();
      final qty =
          int.tryParse((row['qtyCtrl'] as TextEditingController).text.trim()) ??
          0;
      if (item.isEmpty || qty <= 0) continue;
      items.add({'item': item, 'qty': qty, 'unit': row['unit']});
    }

    if (items.isEmpty) {
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one valid need (item and quantity).'),
          backgroundColor: AppColors.warningYellow,
        ),
      );
      return;
    }

    final result = await AssistanceService.saveCenterNeeds(
      evacCenterId: widget.evacCenterId,
      totalEvacuees: profile['total_evacuees'],
      families: profile['families'],
      pregnant: profile['pregnant'],
      lactatingMothers: profile['lactating_mothers'],
      infants: profile['infants'],
      children: profile['children'],
      olderPersons: profile['older_persons'],
      pwd: profile['pwd'],
      sick: profile['sick'],
      injured: profile['injured'],
      items: items,
      profileSource: useReportedTotals ? 'computed' : 'manual',
    );

    if (!mounted) return;
    setState(() => saving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Center needs saved.'),
          backgroundColor: AppColors.successGreen,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']?.toString() ?? 'Failed to save.'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
    }
  }

  Widget _incidentBanner(ThemeData theme) {
    final inc = incident!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.successGreen.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppColors.successGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Verified claim: backed by ${inc['disaster_type']} incident · ${inc['status_label'] ?? inc['status']}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.successGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noIncidentBanner(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warningYellow.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warningYellow,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unverified: no linked incident report. Higher-ups will flag these needs until a report is filed.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.warningYellow,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// At-a-glance "X of Y needs fully met" chip. Empty when the barangay has
  /// not yet saved any needs (so a fresh screen doesn't claim anything).
  List<Widget> _fulfillmentSummaryBanner(ThemeData theme) {
    var met = 0;
    var total = 0;
    for (final row in needRows) {
      final id = row['id'] as int? ?? 0;
      if (id <= 0) continue;
      total++;
      final qty =
          int.tryParse((row['qtyCtrl'] as TextEditingController).text) ?? 0;
      if (_needFulfilled(id, qty)) met++;
    }
    if (total == 0) return const [];

    final allMet = met == total;
    return [
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withValues(alpha: allMet ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.successGreen.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            Icon(
              allMet ? Icons.check_circle_outline : Icons.task_alt,
              color: AppColors.successGreen,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$met of $total needs fully met',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.successGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  bool get _showComputedBanner {
    final c = computed;
    if (c == null) return false;
    if ((int.tryParse(c['report_count']?.toString() ?? '0') ?? 0) <= 0)
      return false;
    final total = int.tryParse(c['total_evacuees']?.toString() ?? '0') ?? 0;
    final households = int.tryParse(c['households']?.toString() ?? '0') ?? 0;
    final children = int.tryParse(c['children']?.toString() ?? '0') ?? 0;
    final p = savedProfile;
    if (p == null) return true;
    final pTotal = int.tryParse(p['total_evacuees']?.toString() ?? '0') ?? 0;
    final pFamilies = int.tryParse(p['families']?.toString() ?? '0') ?? 0;
    final pChildren = int.tryParse(p['children']?.toString() ?? '0') ?? 0;
    return total != pTotal || households != pFamilies || children != pChildren;
  }

  void _useReportedTotals() {
    final c = computed;
    if (c == null) return;
    setState(() {
      profileCtrls['total_evacuees']!.text =
          (int.tryParse(c['total_evacuees']?.toString() ?? '0') ?? 0)
              .toString();
      profileCtrls['families']!.text =
          (int.tryParse(c['households']?.toString() ?? '0') ?? 0).toString();
      profileCtrls['children']!.text =
          (int.tryParse(c['children']?.toString() ?? '0') ?? 0).toString();
      useReportedTotals = true;
    });
  }

  Widget _computedBanner(ThemeData theme) {
    final c = computed!;
    final total = int.tryParse(c['total_evacuees']?.toString() ?? '0') ?? 0;
    final adults = int.tryParse(c['adults']?.toString() ?? '0') ?? 0;
    final children = int.tryParse(c['children']?.toString() ?? '0') ?? 0;
    final households = int.tryParse(c['households']?.toString() ?? '0') ?? 0;
    final count = int.tryParse(c['report_count']?.toString() ?? '0') ?? 0;
    final p = savedProfile;
    final hasProfile = p != null;
    final pTotal = hasProfile
        ? (int.tryParse(p['total_evacuees']?.toString() ?? '0') ?? 0)
        : 0;
    final pFamilies = hasProfile
        ? (int.tryParse(p['families']?.toString() ?? '0') ?? 0)
        : 0;
    final pChildren = hasProfile
        ? (int.tryParse(p['children']?.toString() ?? '0') ?? 0)
        : 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warningYellow.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reported headcounts',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.warningYellow,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasProfile
                ? 'Linked incident reports suggest $total total evacuees ($adults adults + $children children), $households families from $count credited report(s). Current profile shows $pTotal evacuees / $pFamilies families / $pChildren children. Please verify.'
                : 'Linked incident reports suggest $total total evacuees ($adults adults + $children children), $households families from $count credited report(s). No profile has been set yet \u2014 the inputs are pre-filled from the reports. Please verify and save.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.warningYellow,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _useReportedTotals,
              child: const Text('Fill Reported Totals'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warningYellow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fulfillmentPanel(ThemeData theme) {
    final byNeed = <int, Map<String, dynamic>>{};
    for (final raw in fulfillment) {
      final f = Map<String, dynamic>.from(raw as Map);
      final key = int.tryParse(f['need_id']?.toString() ?? '') ?? -1;
      byNeed[key] = f;
    }
    final rows = <Widget>[];
    for (final row in needRows) {
      final id = row['id'] as int? ?? 0;
      final f = byNeed[id];
      if (id == 0 || f == null) continue;
      final item = (row['itemCtrl'] as TextEditingController).text;
      final needed =
          int.tryParse((row['qtyCtrl'] as TextEditingController).text) ?? 0;
      final pledged = int.tryParse(f['pledged']?.toString() ?? '0') ?? 0;
      final sent = int.tryParse(f['sent']?.toString() ?? '0') ?? 0;
      final delivered = int.tryParse(f['delivered']?.toString() ?? '0') ?? 0;
      final received = int.tryParse(f['received']?.toString() ?? '0') ?? 0;
      final helpers = f['helpers']?.toString() ?? '';
      Widget cell(String label, String value, {Color? valueColor}) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
          ],
        ),
      );
      final rowFulfilled = _needFulfilled(id, needed);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: rowFulfilled
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
                        item,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (rowFulfilled) const FulfilledChip(),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    cell('Needed', '$needed'),
                    cell('Pledged', '$pledged'),
                    cell('Sent', '$sent'),
                    cell(
                      'Delivered',
                      '$delivered',
                      valueColor: AppColors.successGreen,
                    ),
                    cell(
                      'Received',
                      '$received',
                      valueColor: const Color(0xFF0E7A5F),
                    ),
                  ],
                ),
                if (helpers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Helpers: $helpers',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      rows.add(
        Text(
          'No pledge activity to display yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who\u2019s helping',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Read-only: only barangay-confirmed Received supply reduces what\u2019s still needed.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }

  Widget _ledgerPanel(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Who donated what',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Every pledge/donation to this center. When a donation arrives, tap Confirm Received to countersign it.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        ...ledger.map((raw) {
          final r = Map<String, dynamic>.from(raw as Map);
          return PledgeLedgerRow(
            row: r,
            onConfirmReceived: _canConfirmReceived && !offline
                ? _confirmReceived
                : null,
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(centerName ?? 'Center Needs')),
      body: isLoading
          ? const LoadingView()
          : errorMessage != null
          ? ErrorState(message: errorMessage!, onRetry: loadData)
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          OfflineCacheStatus(
            showingSaved: showingSaved,
            lastUpdated: lastUpdated,
          ),
          if (showingSaved)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SavedDataTag(fontSize: 11),
              ),
            ),
          if (incident != null) _incidentBanner(theme),
          if (incident == null) _noIncidentBanner(theme),
          if (_showComputedBanner) ...[
            const SizedBox(height: 8),
            _computedBanner(theme),
          ],
          ..._fulfillmentSummaryBanner(theme),
          const SizedBox(height: 8),
          Text(
            'Occupants',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Vulnerable sectors currently inside this center.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: _profileFields.map((label) {
              final key = _fieldKey(label);
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 42) / 2,
                child: TextField(
                  controller: profileCtrls[key],
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: label,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Needed Supplies',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.successGreen,
                ),
                tooltip: 'Add Need',
                onPressed: _addNeedRow,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...needRows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            final id = row['id'] as int? ?? 0;
            final rowQty =
                int.tryParse((row['qtyCtrl'] as TextEditingController).text) ??
                0;
            final rowFulfilled = _needFulfilled(id, rowQty);
            final rowFull = _byNeed[id];
            final rowReceived = rowFull == null
                ? 0
                : (int.tryParse(rowFull['received']?.toString() ?? '0') ?? 0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: rowFulfilled
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
                    if (id > 0 && rowFull != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: NeedProgressBar(
                          needed: rowQty,
                          received: rowReceived,
                          unit: row['unit'] as String,
                          fulfilled: rowFulfilled,
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller:
                                row['itemCtrl'] as TextEditingController,
                            decoration: const InputDecoration(
                              hintText: 'Item',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        if (rowFulfilled) ...[
                          const SizedBox(width: 6),
                          const FulfilledChip(fontSize: 10),
                        ],
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: row['qtyCtrl'] as TextEditingController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Qty',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: row['unit'] as String,
                          items:
                              const [
                                    'packs',
                                    'sacks',
                                    'boxes',
                                    'liters',
                                    'pcs',
                                    'kits',
                                  ]
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => row['unit'] = v);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: AppColors.primaryRed,
                          ),
                          onPressed: needRows.length > 1
                              ? () => _removeNeedRow(index)
                              : null,
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save Needs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          if (ledger.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ledgerPanel(theme),
          ],
          if (fulfillment.isNotEmpty) ...[
            const SizedBox(height: 16),
            _fulfillmentPanel(theme),
          ],
        ],
      ),
    );
  }
}
