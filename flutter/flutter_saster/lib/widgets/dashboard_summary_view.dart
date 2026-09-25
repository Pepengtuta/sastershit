import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../screens/barangay/create_incident_screen.dart';
import '../screens/barangay/evacuation_centers_screen.dart';
import '../screens/shared/assistance_board_screen.dart';
import '../services/auth_service.dart';
import '../services/dashboard_repository.dart';
import 'saved_data_banner.dart';
import 'error_state.dart';
import 'info_card.dart';
import 'loading_view.dart';

class DashboardSummaryView extends StatefulWidget {
  final String role;
  final int? barangayId;
  final String title;
  final String phoLabel;
  final String subRole;
  final int? userId;

  const DashboardSummaryView({
    super.key,
    required this.role,
    this.barangayId,
    required this.title,
    this.phoLabel = 'Provincial',
    this.subRole = '',
    this.userId,
  });

  @override
  State<DashboardSummaryView> createState() => _DashboardSummaryViewState();
}

class _DashboardSummaryViewState extends State<DashboardSummaryView> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? data;
  DateTime? lastUpdated;
  bool hasCache = false;
  bool offline = false;

  late int selectedMonth;
  late int selectedYear;

  /// Month/year that [data] belongs to. Rendering checks the match so a stale
  /// summary from another month is never shown under the current month header.
  late int dataMonth;
  late int dataYear;

  final List<String> monthNames = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  int? get _userId => widget.userId ?? AuthService.currentUserId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedMonth = now.month;
    selectedYear = now.year;
    dataMonth = selectedMonth;
    dataYear = selectedYear;
    loadCachedFirst();
    loadSummary();
  }

  /// Shows the last saved summary for the selected month immediately (no
  /// network), so the dashboard works on a cold offline open.
  Future<void> loadCachedFirst() async {
    final cached = await _repoGetCached();
    if (!mounted || cached.data == null) return;
    // A refresh already delivered fresh data for this month: keep it instead of
    // the pre-write snapshot.
    if (!isLoading && data != null) return;
    setState(() {
      data = cached.data;
      lastUpdated = cached.lastUpdated;
      hasCache = true;
      dataMonth = selectedMonth;
      dataYear = selectedYear;
      isLoading = false;
    });
  }

  Future<DashboardLoadResult> _repoGetCached() {
    return DashboardRepository.instance.getCached(
      userId: _userId ?? 0,
      role: widget.role,
      barangayId: widget.barangayId,
      municipality: AuthService.effectiveMunicipality,
      subRole: widget.subRole,
      month: selectedMonth,
      year: selectedYear,
    );
  }

  Future<void> loadSummary() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final result = await DashboardRepository.instance.refresh(
      userId: _userId ?? 0,
      role: widget.role,
      barangayId: widget.barangayId,
      municipality: AuthService.effectiveMunicipality,
      subRole: widget.subRole,
      month: selectedMonth,
      year: selectedYear,
    );

    if (!mounted) return;

    setState(() {
      isLoading = false;
      if (result.data != null) {
        data = result.data;
        lastUpdated = result.lastUpdated;
        hasCache = result.hasCache;
        offline = false;
        errorMessage = null;
        dataMonth = selectedMonth;
        dataYear = selectedYear;
      } else if (result.offline) {
        offline = true;
        final stillShowingSelected =
            data != null && dataMonth == selectedMonth && dataYear == selectedYear;
        if (data == null || !stillShowingSelected) {
          errorMessage =
              'No saved dashboard for ${monthNames[selectedMonth - 1]} $selectedYear yet. '
              'Connect to the server once to save it for offline use.';
        }
      }
    });
  }

  int intValue(String key) {
    final value = data?[key];
    if (value == null) return 0;
    return int.tryParse(value.toString()) ?? 0;
  }

  List<dynamic> listValue(String key) {
    final value = data?[key];
    if (value is List) return value;
    return [];
  }

  Map<String, dynamic> mapValue(String key) {
    final value = data?[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LoadingView();

    final saveMismatch =
        data != null && (dataMonth != selectedMonth || dataYear != selectedYear);
    if (errorMessage != null || data == null || saveMismatch) {
      return ErrorState(
        message: errorMessage ?? 'No dashboard data available.',
        onRetry: () {
          loadCachedFirst();
          loadSummary();
        },
      );
    }

    final scope = data?['scope_label']?.toString() ?? widget.title;
    final subtitle = '$scope · ${monthNames[selectedMonth - 1]} $selectedYear';
    final isSecretary = widget.subRole == 'secretary';
    final isTanod = widget.subRole == 'tanod';

    List<_DashboardMetric> metrics;
    if (isSecretary) {
      final impactAffected = mapValue('impact')['affected'];
      metrics = [
        _DashboardMetric(label: 'Pending', value: intValue('pending')),
        _DashboardMetric(label: 'Alerts', value: intValue('forwarded_to_pho')),
        _DashboardMetric(label: 'EC Open', value: intValue('evacuation_centers')),
        _DashboardMetric(label: 'Affected', value: impactAffected is num ? impactAffected.toInt() : 0),
      ];
    } else if (isTanod) {
      final impactAffected = mapValue('impact')['affected'];
      metrics = [
        _DashboardMetric(label: 'My Reports', value: intValue('my_reports')),
        _DashboardMetric(label: 'People Affected', value: impactAffected is num ? impactAffected.toInt() : 0),
        _DashboardMetric(label: 'Pending', value: intValue('pending')),
        _DashboardMetric(label: 'Alerts', value: intValue('forwarded_to_pho')),
      ];
    } else {
      metrics = [
        _DashboardMetric(label: 'Total', value: intValue('total_reports')),
        _DashboardMetric(label: 'Pending', value: intValue('pending')),
        _DashboardMetric(label: widget.phoLabel, value: intValue('forwarded_to_pho')),
        _DashboardMetric(label: 'EC', value: intValue('evacuation_centers')),
      ];
    }

    return RefreshIndicator(
      onRefresh: loadSummary,
      color: AppColors.primaryRed,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (offline && hasCache)
            SavedDataBanner(
              title: 'Saved dashboard',
              lastUpdated: lastUpdated,
              detail: 'Last successful synchronization. Refresh needs a server connection.',
            ),
          Text(
            'Dashboard',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          _MonthYearFilter(
            monthNames: monthNames,
            selectedMonth: selectedMonth,
            selectedYear: selectedYear,
            onMonthChanged: (value) => setState(() {
              selectedMonth = value;
              isLoading = true;
              errorMessage = null;
            }),
            onYearChanged: (value) => setState(() {
              selectedYear = value;
              isLoading = true;
              errorMessage = null;
            }),
            onView: () {
              loadCachedFirst();
              loadSummary();
            },
          ),
          const SizedBox(height: 12),
          _WeatherCard(weather: mapValue('weather')),
          const SizedBox(height: 12),
          _CompactMetricsRow(metrics: metrics),
          if (widget.role == 'pcf' || widget.role == 'pho' || widget.role == 'superadmin') ...[
            const SizedBox(height: 14),
            _NeedsAssistancePanel(
              unmetNeeds: intValue('unmet_needs'),
              incomingPledges: intValue('incoming_pledges'),
              myPledges: intValue('my_pledges'),
              zeroPledgeCount: intValue('zero_pledge_count'),
            ),
          ],
          if (isSecretary) ...[
            const SizedBox(height: 14),
            _EvacCenterStatusList(centers: listValue('evac_centers_list')),
          ],
          if (isTanod) ...[
            const SizedBox(height: 14),
            _TanodCreateReportCTA(),
          ],
          if (!isSecretary && !isTanod) ...[
            const SizedBox(height: 14),
            _DisasterBarChart(items: listValue('disaster_summary')),
            const SizedBox(height: 14),
            _StatusBreakdown(items: listValue('status_summary')),
            const SizedBox(height: 14),
            _ImpactTally(impact: mapValue('impact')),
            const SizedBox(height: 14),
            _DailyTrend(items: listValue('daily_trend')),
          ],
        ],
      ),
    );
  }
}

class _MonthYearFilter extends StatelessWidget {
  final List<String> monthNames;
  final int selectedMonth;
  final int selectedYear;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;
  final VoidCallback onView;

  const _MonthYearFilter({
    required this.monthNames,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: DropdownButtonFormField<int>(
            value: selectedMonth,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Month', border: OutlineInputBorder()),
            items: List.generate(12, (index) {
              final value = index + 1;
              return DropdownMenuItem(value: value, child: Text(monthNames[index]));
            }),
            onChanged: (value) {
              if (value != null) onMonthChanged(value);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: DropdownButtonFormField<int>(
            value: selectedYear,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
            items: List.generate(6, (index) {
              final year = DateTime.now().year - 3 + index;
              return DropdownMenuItem(value: year, child: Text(year.toString()));
            }),
            onChanged: (value) {
              if (value != null) onYearChanged(value);
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            onPressed: onView,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: const Text('View'),
          ),
        ),
      ],
    );
  }
}

class _DashboardMetric {
  final String label;
  final int value;

  const _DashboardMetric({required this.label, required this.value});
}

/// Needs & Assistance quick panel for PCF / PHO / Superadmin dashboards.
class _NeedsAssistancePanel extends StatelessWidget {
  final int unmetNeeds;
  final int incomingPledges;
  final int myPledges;
  final int zeroPledgeCount;

  const _NeedsAssistancePanel({
    required this.unmetNeeds,
    required this.incomingPledges,
    required this.myPledges,
    required this.zeroPledgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final figures = [
      {'label': 'Unmet', 'value': unmetNeeds, 'color': AppColors.primaryRed},
      {'label': 'Incoming', 'value': incomingPledges, 'color': AppColors.warningYellow},
      {'label': 'My Pledges', 'value': myPledges, 'color': AppColors.primaryBlue},
      {'label': 'No Pledges', 'value': zeroPledgeCount, 'color': AppColors.textMuted},
    ];

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Needs & Assistance',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Needs & Assistance')),
                        body: const AssistanceBoardScreen(),
                      ),
                    ),
                  );
                },
                child: const Text('Open Board'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Evacuation center needs vs. pledged/sent supply.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          if (zeroPledgeCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFF92400E), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Centers have needs but no pledges yet.',
                      style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: figures.map((figure) {
              final color = figure['color'] as Color;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        figure['value'].toString(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        figure['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CompactMetricsRow extends StatelessWidget {
  final List<_DashboardMetric> metrics;

  const _CompactMetricsRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final compact = available < 360;
        final cardWidth = compact ? 82.0 : (available - 18) / 4;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: metrics.map((metric) {
              return Container(
                width: cardWidth,
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metric.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      metric.value.toString(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: compact ? 16 : 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _DisasterBarChart extends StatelessWidget {
  final List<dynamic> items;

  const _DisasterBarChart({required this.items});

  static const List<String> disasterOrder = [
    'Typhoon',
    'Flood',
    'Storm Surge',
    'Earthquake',
    'Landslide',
    'Fire',
    'Drought / El Niño',
    'Disease Outbreak',
    'Accident / Mass Casualty Incident',
    'Others',
  ];

  List<Map<String, dynamic>> get mappedItems {
    final Map<String, int> counts = {};

    for (final item in items) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final label = _normalizeLabel(map['label']?.toString() ?? 'Others');
      final count = int.tryParse(map['count']?.toString() ?? '0') ?? 0;
      counts[label] = (counts[label] ?? 0) + count;
    }

    return disasterOrder.map((label) {
      return {
        'label': label,
        'count': counts[label] ?? 0,
      };
    }).toList();
  }

  static String _normalizeLabel(String value) {
    final clean = value.trim();

    if (clean.toLowerCase() == 'drought / el niho') {
      return 'Drought / El Niño';
    }

    if (disasterOrder.contains(clean)) {
      return clean;
    }

    return 'Others';
  }

  @override
  Widget build(BuildContext context) {
    final mapped = mappedItems;
    final maxValue = mapped.fold<int>(0, (max, item) {
      final count = item['count'] as int;
      return count > max ? count : max;
    });

    // Build a fixed number scale so bar lengths reflect the real count,
    // instead of always making the biggest one full length.
    int chartStep;
    if (maxValue <= 25) {
      chartStep = 5;
    } else if (maxValue <= 50) {
      chartStep = 10;
    } else if (maxValue <= 150) {
      chartStep = 25;
    } else {
      chartStep = 50;
    }
    // Ceiling sits one step above the highest value, so the longest bar always
    // leaves a little headroom (it is never pinned to the very end).
    final chartCeiling = ((maxValue > 0 ? maxValue : 0) ~/ chartStep + 1) * chartStep;
    final ticks = <int>[];
    for (int t = 0; t <= chartCeiling; t += chartStep) {
      ticks.add(t);
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disaster Type Summary',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...mapped.map((item) {
            return _DisasterProgressItem(
              label: item['label'] as String,
              count: item['count'] as int,
              ceiling: chartCeiling,
            );
          }),
          const SizedBox(height: 2),
          _ChartScaleAxis(ticks: ticks),
        ],
      ),
    );
  }
}

class _DisasterProgressItem extends StatelessWidget {
  final String label;
  final int count;
  final int ceiling;

  const _DisasterProgressItem({
    required this.label,
    required this.count,
    required this.ceiling,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    double progress = 0.0;

    if (count > 0 && ceiling > 0) {
      progress = count / ceiling;

      // Keep very small values visible without making them look empty.
      if (progress < 0.04) {
        progress = 0.04;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                count.toString(),
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                count > 0 ? AppColors.primaryRed : colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartScaleAxis extends StatelessWidget {
  final List<int> ticks;

  const _ChartScaleAxis({required this.ticks});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (ticks.length < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: ticks
            .map(
              (tick) => Text(
                tick.toString(),
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Shows how many reports sit at each stage, colored by urgency so the
/// list reads at a glance (red-ish = waiting, green = handled).
class _StatusBreakdown extends StatelessWidget {
  final List<dynamic> items;

  const _StatusBreakdown({required this.items});

  Color _statusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'Pending':
        return const Color(0xFFF59E0B);
      case 'Verified':
        return const Color(0xFF0D6EFD);
      case 'Responding':
        return const Color(0xFF6F42C1);
      case 'Referred to PHO':
      case '→ PRVCL':
        return const Color(0xFFD63384);
      case 'Under PHO Review':
        return const Color(0xFFFD7E14);
      case 'Resolved':
        return const Color(0xFF198754);
      default:
        return scheme.outline;
    }
  }

  String _statusDisplayName(String status) => status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final rows = items.whereType<Map>().map((item) {
      return {
        'label': item['label']?.toString() ?? 'Unknown',
        'count': int.tryParse(item['count']?.toString() ?? '0') ?? 0,
      };
    }).toList();

    final maxValue = rows.fold<int>(0, (max, row) {
      final count = row['count'] as int;
      return count > max ? count : max;
    });

    // Round the scale up to a "nice" ceiling so a small count never fills the
    // whole bar (matches the disaster chart behavior).
    final chartStep = maxValue <= 25
        ? 5
        : (maxValue <= 50 ? 10 : (maxValue <= 150 ? 25 : 50));
    final chartCeiling =
        ((maxValue > 0 ? maxValue : 0) ~/ chartStep + 1) * chartStep;
    final ticks = <int>[];
    for (int t = 0; t <= chartCeiling; t += chartStep) {
      ticks.add(t);
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Status',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'What needs action vs. handled.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Text(
              'No reports for this month.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
            )
          else ...[
            ...rows.map((row) {
              final label = row['label'] as String;
              final count = row['count'] as int;

              double progress = 0;
              if (count > 0 && chartCeiling > 0) {
                progress = count / chartCeiling;
                if (progress < 0.03) progress = 0.03;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _statusDisplayName(label),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          count.toString(),
                          style: textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          count > 0
                              ? _statusColor(label, colorScheme)
                              : colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 2),
            _ChartScaleAxis(ticks: ticks),
          ],
        ],
      ),
    );
  }
}

/// Four plain numbers showing the real cost in people for the month.
class _ImpactTally extends StatelessWidget {
  final Map<String, dynamic> impact;

  const _ImpactTally({required this.impact});

  int _value(String key) => int.tryParse(impact[key]?.toString() ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final figures = [
      {'label': 'Affected', 'value': _value('affected')},
      {'label': 'Injured', 'value': _value('injured')},
      {'label': 'Dead', 'value': _value('dead')},
      {'label': 'Missing', 'value': _value('missing')},
    ];

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Human Impact',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Total people affected this month.',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Row(
            children: figures.map((figure) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Column(
                    children: [
                      Text(
                        (figure['value'] as int).toString(),
                        style: textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        figure['label'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// A row of thin bars (one per day) so report spikes are easy to spot.
class _DailyTrend extends StatelessWidget {
  final List<dynamic> items;

  const _DailyTrend({required this.items});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final days = items.whereType<Map>().map((item) {
      return {
        'day': int.tryParse(item['day']?.toString() ?? '0') ?? 0,
        'count': int.tryParse(item['count']?.toString() ?? '0') ?? 0,
      };
    }).toList();

    final maxValue = days.fold<int>(0, (max, day) {
      final count = day['count'] as int;
      return count > max ? count : max;
    });

    // Round the scale up to a "nice" ceiling and build y-axis numbers, so a
    // quiet day is measured against a fixed scale (not the busiest day).
    final trendStep = maxValue <= 25
        ? 5
        : (maxValue <= 50 ? 10 : (maxValue <= 150 ? 25 : 50));
    final trendCeiling =
        ((maxValue > 0 ? maxValue : 0) ~/ trendStep + 1) * trendStep;
    final trendTicks = <int>[];
    for (int t = trendCeiling; t >= 0; t -= trendStep) {
      trendTicks.add(t);
    }

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Report Trend',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Reports per day (spot the spikes).',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
          ),
          const SizedBox(height: 12),
          if (maxValue == 0)
            Text(
              'No reports for this month.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
            )
          else ...[
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Y-axis numbers (top = scale ceiling, bottom = 0).
                  SizedBox(
                    width: 22,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: trendTicks.map((tick) {
                        return Text(
                          tick.toString(),
                          style: textTheme.labelSmall
                              ?.copyWith(color: colorScheme.outline),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: days.map((day) {
                        final count = day['count'] as int;

                        // Each day's height is measured against the fixed
                        // ceiling, with a small floor so any non-zero day shows.
                        int pct = 0;
                        if (count > 0 && trendCeiling > 0) {
                          pct = ((count / trendCeiling) * 100).round();
                          if (pct < 3) pct = 3;
                        }

                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1),
                            child: Column(
                              children: [
                                Expanded(
                                  flex: 100 - pct,
                                  child: const SizedBox(),
                                ),
                                Expanded(
                                  flex: pct,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryRed,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Day 1',
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                  Text(
                    'Day ${days.length}',
                    style: textTheme.labelSmall
                        ?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Evacuation center status list for Secretary dashboard.
class _EvacCenterStatusList extends StatelessWidget {
  final List<dynamic> centers;
  const _EvacCenterStatusList({required this.centers});

  Color _statusColor(String status) {
    return AppColors.evacuationCenterStatusColor(status);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final items = centers.whereType<Map>().map((c) {
      return {
        'name': c['name']?.toString() ?? '',
        'status': c['status']?.toString() ?? '',
        'capacity': int.tryParse(c['capacity']?.toString() ?? '0') ?? 0,
      };
    }).toList();

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evacuation Center Status', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Current status of centers in your barangay.', style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const Text('No evacuation centers found.')
          else
            ...items.map((item) {
              final status = item['status'] as String;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Evacuation Centers')),
                        body: const EvacuationCentersScreen(),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(item['name'] as String, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _statusColor(status).withValues(alpha: 0.3)),
                        ),
                        child: Text(status, style: TextStyle(fontSize: 12, color: _statusColor(status), fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text('Cap: ${item['capacity']}', style: textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.outline),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Prominent CTA for BHERT to create a new report.
class _TanodCreateReportCTA extends StatelessWidget {
  const _TanodCreateReportCTA();

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 40, color: AppColors.primaryRed),
          const SizedBox(height: 10),
          Text('Spotted something?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('File a disaster report right away.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateIncidentScreen()));
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Create Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Weather card (Open-Meteo): current conditions, a few-day look-ahead,
/// and a single heads-up banner for heavy rain or wind.
class _WeatherCard extends StatelessWidget {
  final Map<String, dynamic> weather;
  const _WeatherCard({required this.weather});

  static String _txt(dynamic v) => v == null ? '--' : v.toString();

  @override
  Widget build(BuildContext context) {
    // No data (e.g. server had no internet) -> just hide the card.
    if (weather['available'] != true) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final current = (weather['current'] as Map?)?.cast<String, dynamic>() ?? {};
    final days = (weather['days'] as List?) ?? const [];
    final alert = (weather['alert'] as Map?)?.cast<String, dynamic>() ?? {};
    final alertLevel = (alert['level'] ?? 'none').toString();

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alertLevel != 'none')
            _buildAlert(alertLevel, _txt(alert['message'])),
          Row(
            children: [
              Text(_txt(current['emoji']), style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_txt(current['temp'])}°C',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _txt(current['condition']),
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Feels ${_txt(current['feels_like'])}°  ·  Humidity ${_txt(current['humidity'])}%  ·  Wind ${_txt(current['wind'])} km/h',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
          if (days.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: _WeatherDay(day: (d as Map).cast<String, dynamic>()),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Updated ${_txt(weather['updated_at'])}${weather['stale'] == true ? ' (offline — last saved)' : ''}  ·  Source: Open-Meteo',
            style: theme.textTheme.bodySmall
                ?.copyWith(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAlert(String level, String message) {
    final bool severe = level == 'warning';
    final Color bg = severe ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7);
    final Color fg = severe ? const Color(0xFF991B1B) : const Color(0xFF92400E);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${severe ? '⚠️' : '🌧️'}  $message',
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}

/// One day chip inside the weather look-ahead row.
class _WeatherDay extends StatelessWidget {
  final Map<String, dynamic> day;
  const _WeatherDay({required this.day});

  @override
  Widget build(BuildContext context) {
    String txt(dynamic v) => v == null ? '--' : v.toString();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFECEFF3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            txt(day['label']),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(txt(day['emoji']), style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 2),
          Text(
            '${txt(day['temp_max'])}° / ${txt(day['temp_min'])}°',
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
          Text(
            '💧 ${txt(day['rain_chance'])}%',
            style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }
}