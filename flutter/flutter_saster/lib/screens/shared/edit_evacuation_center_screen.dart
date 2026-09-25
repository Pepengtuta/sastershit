import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/barangay_service.dart';
import '../../services/evacuation_center_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/section_title.dart';

class EditEvacuationCenterScreen extends StatefulWidget {
  final Map<String, dynamic> center;

  const EditEvacuationCenterScreen({super.key, required this.center});

  @override
  State<EditEvacuationCenterScreen> createState() => _EditEvacuationCenterScreenState();
}

class _EditEvacuationCenterScreenState extends State<EditEvacuationCenterScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController centerNameController;
  late final TextEditingController typeController;
  late final TextEditingController capacityController;
  late final TextEditingController currentEvacueesController;
  late final TextEditingController contactPersonController;
  late final TextEditingController contactNumberController;

  bool isLoading = true;
  bool isSaving = false;
  bool lockBarangay = false;
  List<Map<String, dynamic>> barangays = [];
  Map<String, dynamic>? selectedBarangay;
  late String status;

  final statuses = const ['Available', 'Open', 'Full', 'Closed', 'Needs Supplies'];

  @override
  void initState() {
    super.initState();
    final c = widget.center;
    status                   = c['status']?.toString() ?? 'Available';
    centerNameController     = TextEditingController(text: c['center_name']?.toString() ?? '');
    typeController           = TextEditingController(text: c['center_type']?.toString() ?? 'Evacuation Center');
    capacityController       = TextEditingController(text: (c['capacity'] ?? 0).toString());
    currentEvacueesController = TextEditingController(text: (c['current_evacuees'] ?? 0).toString());
    contactPersonController  = TextEditingController(text: c['contact_person']?.toString() ?? '');
    contactNumberController  = TextEditingController(text: c['contact_number']?.toString() ?? '');

    if (!statuses.contains(status)) status = 'Available';
    loadBarangays();
  }

  @override
  void dispose() {
    centerNameController.dispose();
    typeController.dispose();
    capacityController.dispose();
    currentEvacueesController.dispose();
    contactPersonController.dispose();
    contactNumberController.dispose();
    super.dispose();
  }

  Future<void> loadBarangays() async {
    final result = await BarangayService.getBarangays();
    if (!mounted) return;
    setState(() {
      isLoading = false;
      if (result['success'] == true && result['data'] is List) {
        final all = (result['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final forcedMuni = AuthService.effectiveMunicipality;
        barangays = (forcedMuni == null || forcedMuni.isEmpty)
            ? all
            : all.where((b) => b['municipality']?.toString() == forcedMuni).toList();
        // Pre-select the current barangay by name + municipality
        final currentBarangayName = widget.center['barangay']?.toString() ?? '';
        final currentMunicipality = widget.center['municipality']?.toString() ?? '';
        if (currentBarangayName.isNotEmpty) {
          selectedBarangay = barangays.firstWhere(
            (b) => b['name'].toString() == currentBarangayName && b['municipality'].toString() == currentMunicipality,
            orElse: () => barangays.firstWhere(
              (b) => b['name'].toString() == currentBarangayName,
              orElse: () => barangays.isNotEmpty ? barangays.first : <String, dynamic>{},
            ),
          );
          if (selectedBarangay!.isEmpty) selectedBarangay = null;
        }

        // Barangay Chairmen can only edit centers inside their own barangay.
        if (AuthService.isCaptain) {
          final ownId = AuthService.currentBarangayId;
          final ownName = AuthService.currentBarangayName;
          barangays = barangays
              .where((b) =>
                  (int.tryParse(b['id']?.toString() ?? '') == ownId) ||
                  (b['name']?.toString() == ownName))
              .toList();
          if (barangays.isNotEmpty) {
            selectedBarangay = barangays.firstWhere(
              (b) => b['name'].toString() == (widget.center['barangay']?.toString() ?? ''),
              orElse: () => barangays.first,
            );
            lockBarangay = true;
          }
        }
      }
    });
  }

  Future<void> updateCenter() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a barangay.'), backgroundColor: AppColors.primaryRed));
      return;
    }

    setState(() => isSaving = true);
    final result = await EvacuationCenterService.updateEvacuationCenter(
      id: (widget.center['id'] as num).toInt(),
      barangay: selectedBarangay!['name'].toString(),
      barangayId: int.tryParse(selectedBarangay!['id'].toString()),
      centerName: centerNameController.text.trim(),
      centerType: typeController.text.trim(),
      capacity: int.tryParse(capacityController.text.trim()) ?? 0,
      currentEvacuees: int.tryParse(currentEvacueesController.text.trim()) ?? 0,
      status: status,
      contactPerson: contactPersonController.text.trim(),
      contactNumber: contactNumberController.text.trim(),
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
      appBar: AppBar(title: const Text('Edit Evacuation Center')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle(title: 'Assignment'),
              DropdownButtonFormField<Map<String, dynamic>>(
                value: selectedBarangay,
                isExpanded: true,
                decoration: decoration('Assigned Barangay', Icons.location_on_outlined),
                items: barangays.map((b) => DropdownMenuItem(value: b, child: Text('${b['name']} (${b['municipality']})'))).toList(),
                onChanged: (isSaving || lockBarangay) ? null : (value) => setState(() => selectedBarangay = value),
                validator: (value) => value == null ? 'Select barangay' : null,
              ),
              if (lockBarangay)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Locked to your own barangay.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              const SectionTitle(title: 'Center Details'),
              TextFormField(
                controller: centerNameController,
                enabled: !isSaving,
                decoration: decoration('Center Name', Icons.location_city_outlined),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: typeController, enabled: !isSaving, decoration: decoration('Center Type', Icons.category_outlined)),
              const SizedBox(height: 12),
              TextFormField(controller: capacityController, enabled: !isSaving, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: decoration('Capacity', Icons.groups_outlined), validator: (v) { final n = int.tryParse((v ?? '').trim()); return n == null ? 'Enter a valid number' : null; }),
              const SizedBox(height: 12),
              TextFormField(controller: currentEvacueesController, enabled: !isSaving, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: decoration('Current Evacuees', Icons.people_outline), validator: (v) { final n = int.tryParse((v ?? '').trim()); return n == null ? 'Enter a valid number' : null; }),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: decoration('Status', Icons.info_outline),
                items: statuses
                    .map(
                      (s) => DropdownMenuItem<String>(
                        value: s,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.evacuationCenterStatusColor(s),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              s,
                              style: TextStyle(
                                color: AppColors.evacuationCenterStatusColor(s),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: isSaving ? null : (value) => setState(() => status = value ?? 'Available'),
              ),
              const SectionTitle(title: 'Contact'),
              TextFormField(controller: contactPersonController, enabled: !isSaving, decoration: decoration('Contact Person', Icons.person_outline)),
              const SizedBox(height: 12),
              TextFormField(controller: contactNumberController, enabled: !isSaving, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[^0-9+\-\s()]'))], decoration: decoration('Contact Number', Icons.phone_outlined), validator: (v) { final t = (v ?? '').trim(); if (t.isEmpty) return null; return t.contains(RegExp(r'[0-9]')) ? null : 'Contact number must contain digits'; }),
              const SizedBox(height: 22),
              isSaving
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed))
                  : AppButton(text: 'Update Evacuation Center', icon: Icons.save_outlined, onPressed: updateCenter),
            ],
          ),
        ),
      ),
    );
  }
}
