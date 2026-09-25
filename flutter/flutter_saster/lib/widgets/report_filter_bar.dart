import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/status_labels.dart';

class ReportFilterBar extends StatefulWidget {
  final String searchQuery;
  final String statusFilter;
  final ValueChanged<String?> onStatusChanged;
  final String typeFilter;
  final ValueChanged<String?> onTypeChanged;
  final String dateFilter;
  final ValueChanged<String?> onDateChanged;
  final ValueChanged<String> onSearchChanged;
  final List<String>? statusOptions;

  const ReportFilterBar({
    super.key,
    required this.searchQuery,
    required this.statusFilter,
    required this.onStatusChanged,
    required this.typeFilter,
    required this.onTypeChanged,
    required this.dateFilter,
    required this.onDateChanged,
    required this.onSearchChanged,
    this.statusOptions,
  });

  @override
  State<ReportFilterBar> createState() => _ReportFilterBarState();
}

class _ReportFilterBarState extends State<ReportFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const defaultStatusOptions = ['All', 'Pending', 'Verified', 'Responding', 'Resolved', 'Dismissed', 'Referred to PHO'];
    final statusOptions = widget.statusOptions ?? defaultStatusOptions;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search by description or location...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdown(
                  label: 'Status',
                  value: widget.statusFilter,
                  options: statusOptions,
                  onChanged: widget.onStatusChanged,
                  itemText: statusFilterLabel,
                ),
                const SizedBox(width: 8),
                _buildDropdown(
                  label: 'Type',
                  value: widget.typeFilter,
                  options: ['All', 'Flood', 'Fire', 'Earthquake', 'Accident / Mass Casualty Incident', 'Medical', 'Other'],
                  onChanged: widget.onTypeChanged,
                ),
                const SizedBox(width: 8),
                _buildDropdown(
                  label: 'Date',
                  value: widget.dateFilter,
                  options: ['All Time', 'Today', 'Last 7 Days', 'Last 30 Days'],
                  onChanged: widget.onDateChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    String Function(String)? itemText,
  }) {
    // Ensure value is in options, otherwise fallback to options.first
    final safeValue = options.contains(value) ? value : options.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label:', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: safeValue,
            isDense: true,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w500),
            items: options.map((opt) {
              return DropdownMenuItem(value: opt, child: Text(itemText?.call(opt) ?? opt));
            }).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
