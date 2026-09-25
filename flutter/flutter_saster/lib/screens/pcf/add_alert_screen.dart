import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/disaster_type_config.dart';
import '../../services/alert_service.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/barangay_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/section_title.dart';
import '../../widgets/server_required_notice.dart';

class AddAlertScreen extends StatefulWidget {
  /// When true (used by Provincial), the alert always targets all barangays and the
  /// barangay picker is hidden. Provincial cannot target selected barangays.
  final bool forceAllBarangays;

  const AddAlertScreen({super.key, this.forceAllBarangays = false});

  @override
  State<AddAlertScreen> createState() => _AddAlertScreenState();
}

class _AddAlertScreenState extends State<AddAlertScreen> {
  final formKey = GlobalKey<FormState>();
  final titleController = TextEditingController();
  final messageController = TextEditingController();
  final instructionsController = TextEditingController();

  String alertType = 'Typhoon';
  String severity = 'Low';
  DateTime startDateTime = DateTime.now();
  DateTime endDateTime = DateTime.now().add(const Duration(days: 3));
  bool isSaving = false;
  bool isLoadingBarangays = true;
  bool targetAllBarangays = false;
  String? barangayError;
  String? mdrScope;
  List<dynamic> barangays = [];
  final Set<int> selectedBarangayIds = {};

  final alertTypes = const [
    'Typhoon',
    'Flood',
    'Storm Surge',
    'Earthquake',
    'Landslide',
    'Fire',
    'Disease Outbreak',
    'Other',
  ];

  final severities = const ['Low', 'Moderate', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    if (widget.forceAllBarangays) targetAllBarangays = true;
    loadBarangays();
  }

  @override
  void dispose() {
    titleController.dispose();
    messageController.dispose();
    instructionsController.dispose();
    super.dispose();
  }

  Future<void> loadBarangays() async {
    setState(() {
      isLoadingBarangays = true;
      barangayError = null;
    });

    final result = await BarangayService.getBarangays();
    if (!mounted) return;

    if (result['success'] != true) {
      setState(() {
        isLoadingBarangays = false;
        barangayError = ApiService.userMessage(result['message']?.toString() ?? 'Failed to load barangays.');
      });
      return;
    }

    setState(() {
      barangays = result['data'] ?? [];
      mdrScope = result['scope']?.toString();
      if (mdrScope != null && mdrScope!.isEmpty) mdrScope = null;
      isLoadingBarangays = false;
    });
  }

  String formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min:00';
  }

  String displayDateTime(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour12 = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
    final ampm = value.hour >= 12 ? 'PM' : 'AM';
    final minute = value.minute.toString().padLeft(2, '0');
    return '${months[value.month - 1]} ${value.day}, ${value.year} • $hour12:$minute $ampm';
  }

  Future<DateTime?> pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> saveAlert() async {
    if (!formKey.currentState!.validate()) return;

    // Publishing alerts is online-only: while the server is unreachable the
    // create screen stays blocked with a clear explanation.
    if (isServerUnreachable()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(kOfflineWriteMessage),
          backgroundColor: AppColors.primaryRed,
        ),
      );
      return;
    }

    final userId = AuthService.currentUserId;
    if (userId == null) return;

    if (endDateTime.isBefore(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date/time must be after start date/time.'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
      return;
    }

    if (!targetAllBarangays && selectedBarangayIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one barangay or choose All Barangays.'),
          backgroundColor: AppColors.primaryRed,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    final result = await AlertService.saveAlert(
      createdBy: userId,
      title: titleController.text.trim(),
      alertType: alertType,
      severity: severity,
      message: messageController.text.trim(),
      instructions: instructionsController.text.trim(),
      startDatetime: formatDateTime(startDateTime),
      endDatetime: formatDateTime(endDateTime),
      targetType: targetAllBarangays ? 'all' : 'selected',
      barangayIds: selectedBarangayIds.toList(),
    );

    if (!mounted) return;
    setState(() => isSaving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Alert saved.'),
        backgroundColor: result['success'] == true ? AppColors.successGreen : AppColors.primaryRed,
      ),
    );

    if (result['success'] == true) Navigator.pop(context, true);
  }

  InputDecoration fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  // Renders a dropdown menu item with a colored dot + tinted background.
  Widget _coloredOption(String value, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget barangayTargetSelector() {
    if (widget.forceAllBarangays) {
      return InfoCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.campaign_outlined, color: AppColors.primaryRed),
          title: const Text('All Barangays', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Provincial alerts are always sent to every barangay.'),
        ),
      );
    }
    if (isLoadingBarangays) return const LoadingView();
    if (barangayError != null) return ErrorState(message: barangayError!, onRetry: loadBarangays);
    if (barangays.isEmpty) return const EmptyState(icon: Icons.location_city_outlined, message: 'No barangays found.');

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('All Barangays', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Turn on only if every barangay must receive this alert.'),
            value: targetAllBarangays,
            activeColor: AppColors.primaryRed,
            onChanged: isSaving
                ? null
                : (value) {
                    setState(() {
                      targetAllBarangays = value;
                      if (value) selectedBarangayIds.clear();
                    });
                  },
          ),
          if (!targetAllBarangays) ...[
            const Divider(),
            if (mdrScope != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Showing $mdrScope barangays for your MDR account.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ),
            Text(
              'Selected: ${selectedBarangayIds.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...barangays.map((item) {
              final barangay = Map<String, dynamic>.from(item);
              final id = int.tryParse(barangay['id'].toString()) ?? 0;
              final name = barangay['name']?.toString() ?? 'Barangay';
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: selectedBarangayIds.contains(id),
                title: Text(name),
                activeColor: AppColors.primaryRed,
                onChanged: isSaving
                    ? null
                    : (checked) {
                        setState(() {
                          if (checked == true) {
                            selectedBarangayIds.add(id);
                          } else {
                            selectedBarangayIds.remove(id);
                          }
                        });
                      },
              );
            }),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Alert')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle(title: 'Alert Details'),
              TextFormField(
                controller: titleController,
                enabled: !isSaving,
                decoration: fieldDecoration('Title', Icons.title_outlined),
                validator: (value) => value == null || value.trim().isEmpty ? 'Title is required' : null,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: alertType,
                isExpanded: true,
                decoration: fieldDecoration('Alert Type', Icons.warning_amber_outlined),
                style: TextStyle(color: DisasterTypeConfig.getIconColor(alertType)),
                items: alertTypes.map((e) {
                  return DropdownMenuItem(
                    value: e,
                    child: _coloredOption(e, DisasterTypeConfig.getIconColor(e)),
                  );
                }).toList(),
                onChanged: isSaving ? null : (v) => setState(() => alertType = v ?? alertType),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: severity,
                isExpanded: true,
                decoration: fieldDecoration('Severity', Icons.priority_high_outlined),
                items: severities.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: isSaving ? null : (v) => setState(() => severity = v ?? severity),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: messageController,
                enabled: !isSaving,
                minLines: 3,
                maxLines: 5,
                decoration: fieldDecoration('Message', Icons.message_outlined),
                validator: (value) => value == null || value.trim().isEmpty ? 'Message is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: instructionsController,
                enabled: !isSaving,
                minLines: 2,
                maxLines: 4,
                decoration: fieldDecoration('Instructions', Icons.fact_check_outlined),
              ),
              const SectionTitle(title: 'Target Barangays'),
              barangayTargetSelector(),
              const SectionTitle(title: 'Alert Validity'),
              InfoCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_outline, color: AppColors.successGreen),
                      title: Text(displayDateTime(startDateTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Start date and time'),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: isSaving
                          ? null
                          : () async {
                              final picked = await pickDateTime(startDateTime);
                              if (picked != null) setState(() => startDateTime = picked);
                            },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.stop_circle_outlined, color: AppColors.primaryRed),
                      title: Text(displayDateTime(endDateTime), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('End date and time'),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: isSaving
                          ? null
                          : () async {
                              final picked = await pickDateTime(endDateTime);
                              if (picked != null) setState(() => endDateTime = picked);
                            },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              isSaving
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                  : AppButton(text: 'Publish Alert', icon: Icons.send_outlined, onPressed: saveAlert),
            ],
          ),
        ),
      ),
    );
  }
}
