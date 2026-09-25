import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/barangay_service.dart';
import '../../services/hotline_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/section_title.dart';

class EditHotlineScreen extends StatefulWidget {
  final Map<String, dynamic> hotline;

  const EditHotlineScreen({super.key, required this.hotline});

  @override
  State<EditHotlineScreen> createState() => _EditHotlineScreenState();
}

class _EditHotlineScreenState extends State<EditHotlineScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController officeController;
  late final TextEditingController municipalityController;
  late final TextEditingController telephoneController;
  late final TextEditingController cellphoneController;
  late final TextEditingController hotlineController;
  late final TextEditingController remarksController;

  bool isLoading = true;
  bool isSaving = false;
  late String scope;
  late String category;
  late String status;
  Map<String, dynamic>? selectedBarangay;
  List<Map<String, dynamic>> barangays = [];

  final scopes = const ['Municipal', 'Barangay'];
  final categories = const ['Barangay', 'Municipal', 'PNP', 'Fire', 'Medical', 'Hospital', 'MDRRMO', 'PHO', 'Coast Guard', 'Other'];
  final statuses = const ['Active', 'Inactive'];

  @override
  void initState() {
    super.initState();
    final h = widget.hotline;
    scope             = h['hotline_scope']?.toString() ?? 'Municipal';
    category          = h['category']?.toString() ?? 'Other';
    status            = h['status']?.toString() ?? 'Active';
    officeController  = TextEditingController(text: h['office_name']?.toString() ?? '');
    municipalityController = TextEditingController(text: h['municipality']?.toString() ?? 'Kalibo');
    telephoneController    = TextEditingController(text: h['telephone_numbers']?.toString() ?? '');
    cellphoneController    = TextEditingController(text: h['cellphone_numbers']?.toString() ?? '');
    hotlineController      = TextEditingController(text: h['hotline_number']?.toString() ?? '');
    remarksController      = TextEditingController(text: h['remarks']?.toString() ?? '');

    if (!scopes.contains(scope)) scope = 'Municipal';
    if (!categories.contains(category)) category = 'Other';
    if (!statuses.contains(status)) status = 'Active';

    loadBarangays();
  }

  @override
  void dispose() {
    officeController.dispose();
    municipalityController.dispose();
    telephoneController.dispose();
    cellphoneController.dispose();
    hotlineController.dispose();
    remarksController.dispose();
    super.dispose();
  }

  Future<void> loadBarangays() async {
    final result = await BarangayService.getBarangays();
    if (!mounted) return;
    setState(() {
      isLoading = false;
      if (result['success'] == true && result['data'] is List) {
        barangays = (result['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        // Pre-select the current barangay
        final currentBarangayId = widget.hotline['barangay_id'];
        if (currentBarangayId != null) {
          selectedBarangay = barangays.firstWhere(
            (b) => b['id'].toString() == currentBarangayId.toString(),
            orElse: () => barangays.isNotEmpty ? barangays.first : <String, dynamic>{},
          );
          if (selectedBarangay!.isEmpty) selectedBarangay = null;
        }
      }
    });
  }

  Future<void> updateHotline() async {
    if (!formKey.currentState!.validate()) return;
    if (scope == 'Barangay' && selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a barangay.'), backgroundColor: AppColors.primaryRed));
      return;
    }

    setState(() => isSaving = true);
    final barangayId = scope == 'Barangay' ? int.tryParse(selectedBarangay!['id'].toString()) : null;
    final muni = scope == 'Barangay'
        ? (selectedBarangay!['municipality']?.toString() ?? municipalityController.text.trim())
        : municipalityController.text.trim();
    final result = await HotlineService.updateHotline(
      id: (widget.hotline['id'] as num).toInt(),
      hotlineScope: scope,
      barangayId: barangayId,
      officeName: officeController.text.trim(),
      municipality: muni,
      category: category,
      telephoneNumbers: telephoneController.text.trim(),
      cellphoneNumbers: cellphoneController.text.trim(),
      hotlineNumber: hotlineController.text.trim(),
      remarks: remarksController.text.trim(),
      status: status,
    );
    if (!mounted) return;
    setState(() => isSaving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Updated.'), backgroundColor: AppColors.successGreen));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Failed to update.'), backgroundColor: AppColors.primaryRed));
    }
  }

  InputDecoration decoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Hotline')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle(title: 'Hotline Scope'),
              DropdownButtonFormField<String>(
                value: scope,
                decoration: decoration('Scope', Icons.public_outlined),
                items: scopes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: isSaving ? null : (value) => setState(() {
                  scope = value ?? 'Municipal';
                  if (scope != 'Barangay') selectedBarangay = null;
                }),
              ),
              if (scope == 'Barangay') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<Map<String, dynamic>>(
                  value: selectedBarangay,
                  isExpanded: true,
                  decoration: decoration('Barangay', Icons.location_on_outlined),
                  items: barangays.map((b) => DropdownMenuItem(value: b, child: Text(b['name'].toString()))).toList(),
                  onChanged: isSaving ? null : (value) => setState(() => selectedBarangay = value),
                ),
              ],
              const SectionTitle(title: 'Hotline Details'),
              TextFormField(controller: officeController, enabled: !isSaving, decoration: decoration('Office Name', Icons.business_outlined), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              if (scope != 'Barangay') ...[
                TextFormField(controller: municipalityController, enabled: !isSaving, decoration: decoration('Municipality', Icons.location_city_outlined)),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<String>(
                value: category,
                isExpanded: true,
                decoration: decoration('Category', Icons.category_outlined),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: isSaving ? null : (value) => setState(() => category = value ?? 'Other'),
              ),
              const SectionTitle(title: 'Numbers'),
              TextFormField(controller: telephoneController, enabled: !isSaving, keyboardType: TextInputType.phone, decoration: decoration('Telephone Numbers', Icons.phone_outlined)),
              const SizedBox(height: 12),
              TextFormField(controller: cellphoneController, enabled: !isSaving, keyboardType: TextInputType.phone, decoration: decoration('Cellphone Numbers', Icons.smartphone_outlined)),
              const SizedBox(height: 12),
              TextFormField(controller: hotlineController, enabled: !isSaving, keyboardType: TextInputType.phone, decoration: decoration('Hotline Number', Icons.support_agent_outlined)),
              const SizedBox(height: 12),
              TextFormField(controller: remarksController, enabled: !isSaving, minLines: 2, maxLines: 4, decoration: decoration('Remarks', Icons.notes_outlined)),
              const SectionTitle(title: 'Status'),
              DropdownButtonFormField<String>(
                value: status,
                decoration: decoration('Status', Icons.toggle_on_outlined),
                items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: isSaving ? null : (value) => setState(() => status = value ?? 'Active'),
              ),
              const SizedBox(height: 22),
              isSaving
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                  : AppButton(text: 'Update Hotline', icon: Icons.save_outlined, onPressed: updateHotline),
            ],
          ),
        ),
      ),
    );
  }
}
