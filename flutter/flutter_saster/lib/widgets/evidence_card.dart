import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../screens/pho/evidence_reports_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/dashboard_service.dart';

/// Scope of an [EvidenceCard]: the Governor sees the whole province, each Mayor
/// sees only their own municipality.
enum EvidenceScope { province, municipality }

/// Read-only evidence summary card (decision support) for the Governor
/// (province-wide) and the two Mayor observers (municipality-wide). Aggregates
/// ALL incidents for the current month regardless of referral status, plus
/// shelter status/occupancy.
///
/// Collapsible (default collapsed): header + Human Impact tiles are always
/// visible; tapping the header reveals the rest. Disaster-type chips and the
/// breakdown rows (per municipality for the Governor, per barangay for a
/// Mayor) drill down into the underlying reports.
class EvidenceCard extends StatefulWidget {
  final EvidenceScope scope;
  final String title;
  final String role;
  final String subRole;
  final String? municipality;

  const EvidenceCard({
    super.key,
    required this.scope,
    required this.title,
    required this.role,
    required this.subRole,
    this.municipality,
  });

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _evidence;
  bool _expanded = false;

  bool get _isProvince => widget.scope == EvidenceScope.province;

  String get _evidenceKey =>
      _isProvince ? 'province_evidence' : 'municipality_evidence';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final now = DateTime.now();
    final result = await DashboardService.getDashboardSummary(
      role: widget.role,
      subRole: widget.subRole,
      userId: AuthService.currentUserId,
      month: now.month,
      year: now.year,
      municipality: widget.municipality,
    );
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        _loading = false;
        _error = ApiService.userMessage(result['message']?.toString() ?? 'Failed to load the summary.');
      });
      return;
    }
    setState(() {
      _evidence =
          Map<String, dynamic>.from(result['data']?[_evidenceKey] ?? <String, dynamic>{});
      _loading = false;
    });
  }

  String get _monthLabel {
    final e = _evidence;
    final month = int.tryParse(e?['month']?.toString() ?? '') ?? DateTime.now().month;
    final year = int.tryParse(e?['year']?.toString() ?? '') ?? DateTime.now().year;
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final m = month >= 1 && month <= 12 ? month : 1;
    return '${names[m - 1]} $year';
  }

  int get _windowMonth =>
      int.tryParse(_evidence?['month']?.toString() ?? '') ?? DateTime.now().month;

  int get _windowYear =>
      int.tryParse(_evidence?['year']?.toString() ?? '') ?? DateTime.now().year;

  Map<String, dynamic> _impact() =>
      Map<String, dynamic>.from(_evidence?['impact'] ?? <String, dynamic>{});

  void _openDrillDown({
    String? municipality,
    String? disasterType,
    int? barangayId,
    String? barangay,
  }) {
    final label = barangay ?? municipality ?? disasterType ?? '';
    if (label.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EvidenceReportsScreen(
          title: label,
          scope: widget.scope,
          role: widget.role,
          municipality: _isProvince ? municipality : widget.municipality,
          barangayId: barangayId,
          disasterType: disasterType,
          month: _windowMonth,
          year: _windowYear,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.insights, size: 18, color: AppColors.primaryBlue),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _isProvince
                  ? '$_monthLabel · All municipalities · All referral statuses · Dismissed excluded'
                  : '$_monthLabel · All barangays · All referral statuses · Dismissed excluded',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              )
            else if (_error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(_error!, style: const TextStyle(color: AppColors.primaryRed, fontSize: 12)),
                  ),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              )
            else ...[
              _sectionTitle('Human Impact'),
              Row(
                children: [
                  _statTile(int.tryParse(_impact()['affected']?.toString() ?? '') ?? 0, 'Affected', AppColors.primaryRed),
                  _statTile(int.tryParse(_impact()['injured']?.toString() ?? '') ?? 0, 'Injured', AppColors.primaryOrange),
                  _statTile(int.tryParse(_impact()['dead']?.toString() ?? '') ?? 0, 'Dead', AppColors.textDark),
                  _statTile(int.tryParse(_impact()['missing']?.toString() ?? '') ?? 0, 'Missing', AppColors.primaryBlue),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionTitle('Active Incidents by Disaster Type'),
                            _disasterChips(),
                            const SizedBox(height: 12),
                            _sectionTitle(_isProvince ? 'Per Municipality' : 'Per Barangay'),
                            ..._breakdownRows(),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _sectionTitle('Evacuation Centers by Status'),
                                      _evacChips(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _sectionTitle('Shelter Capacity'),
                                      _capacityBanner(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
        ),
      );

  Widget _statTile(int value, String label, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _disasterChips() {
    final map = _evidence?['disaster_summary'] as Map<String, dynamic>?;
    final total = int.tryParse(_evidence?['total_reports']?.toString() ?? '0') ?? 0;
    if ((map?.length ?? 0) == 0 || total == 0) {
      return const Text('No active incidents this month.', style: TextStyle(fontSize: 12, color: AppColors.textMuted));
    }
    final entries = map!.entries.where((e) => (int.tryParse(e.value?.toString() ?? '0') ?? 0) > 0).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: entries.map((e) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openDrillDown(disasterType: e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${e.key} × ${e.value}',
                style: const TextStyle(fontSize: 11, color: AppColors.textDark),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<Widget> _breakdownRows() {
    final list = _evidence?[_isProvince ? 'municipality_summary' : 'barangay_summary']
            as List<dynamic>? ??
        [];
    if (list.isEmpty) {
      return const [
        Text('No incidents recorded this month.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      ];
    }
    return list.map<Widget>((raw) {
      final m = Map<String, dynamic>.from(raw);
      final urgency = m['urgency']?.toString() ?? 'normal';
      final color = switch (urgency) {
        'high' => AppColors.primaryRed,
        'elevated' => AppColors.warningYellow,
        _ => AppColors.successGreen,
      };
      final label = urgency == 'high' ? 'High' : (urgency == 'elevated' ? 'Elevated' : 'Normal');
      final name = _isProvince
          ? (m['municipality']?.toString() ?? '')
          : (m['barangay']?.toString() ?? '');
      final int? barangayId = _isProvince
          ? null
          : (int.tryParse(m['barangay_id']?.toString() ?? '0') ?? 0);
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openDrillDown(
            municipality: _isProvince ? name : widget.municipality,
            barangayId: barangayId,
            barangay: _isProvince ? null : name,
          ),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                  ),
                ),
                Text(
                  '${m['incident_count']} incidents · ${m['affected']} affected',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _evacChips() {
    final statuses = _evidence?['evac_status_summary'] as Map<String, dynamic>? ?? {};
    const order = ['Open', 'Available', 'Needs Supplies', 'Full', 'Closed'];
    final colors = {
      'Open': AppColors.successGreen,
      'Available': AppColors.primaryBlue,
      'Needs Supplies': AppColors.primaryOrange,
      'Full': AppColors.primaryRed,
      'Closed': AppColors.textMuted,
    };
    final total = int.tryParse(_evidence?['evac_total']?.toString() ?? '0') ?? 0;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...order.map((s) {
          final count = int.tryParse(statuses[s]?.toString() ?? '0') ?? 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: colors[s] ?? AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '$s $count',
              style: TextStyle(fontSize: 10, color: colors[s] ?? AppColors.textDark),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('$total total', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ),
      ],
    );
  }

  Widget _capacityBanner() {
    final list = _evidence?['evac_over_capacity'] as List<dynamic>? ?? [];
    final atRisk = list.where((raw) {
      final m = Map<String, dynamic>.from(raw);
      return (int.tryParse(m['at_risk_count']?.toString() ?? '0') ?? 0) > 0;
    }).toList();

    if (atRisk.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _isProvince
              ? 'No municipality over the 80% threshold.'
              : 'No shelter over the 80% threshold.',
          style: const TextStyle(fontSize: 11, color: AppColors.successGreen, fontWeight: FontWeight.w500),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warningYellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Shelters over 80% capacity:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
          ),
          ...atRisk.map((raw) {
            final m = Map<String, dynamic>.from(raw);
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${m['municipality']}: ${m['at_risk_count']}/${m['center_count']} over 80%'
                ' (${m['occupants']}/${m['capacity']}, ${m['occupancy_pct']}%)',
                style: const TextStyle(fontSize: 10, color: AppColors.textDark),
              ),
            );
          }),
        ],
      ),
    );
  }
}