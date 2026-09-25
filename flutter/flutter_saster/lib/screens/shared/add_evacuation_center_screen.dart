import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/barangay_service.dart';
import '../../services/evacuation_center_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/section_title.dart';

class AddEvacuationCenterScreen extends StatefulWidget {
  const AddEvacuationCenterScreen({super.key});

  @override
  State<AddEvacuationCenterScreen> createState() => _AddEvacuationCenterScreenState();
}

class _AddEvacuationCenterScreenState extends State<AddEvacuationCenterScreen> {
  final formKey = GlobalKey<FormState>();
  final centerNameController = TextEditingController();
  final typeController = TextEditingController(text: 'Evacuation Center');
  final capacityController = TextEditingController(text: '0');
  final contactPersonController = TextEditingController();
  final contactNumberController = TextEditingController();
  final latitudeController = TextEditingController();
  final longitudeController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  bool lockBarangay = false;
  List<Map<String, dynamic>> barangays = [];
  Map<String, dynamic>? selectedBarangay;
  String status = 'Available';

  final statuses = const ['Available', 'Open', 'Full', 'Closed', 'Needs Supplies'];

  @override
  void initState() {
    super.initState();
    loadBarangays();
  }

  @override
  void dispose() {
    centerNameController.dispose();
    typeController.dispose();
    capacityController.dispose();
    contactPersonController.dispose();
    contactNumberController.dispose();
    latitudeController.dispose();
    longitudeController.dispose();
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

        // Barangay Chairmen can only assign centers to their own barangay.
        if (AuthService.isCaptain) {
          final ownId = AuthService.currentBarangayId;
          final ownName = AuthService.currentBarangayName;
          barangays = barangays
              .where((b) =>
                  (int.tryParse(b['id']?.toString() ?? '') == ownId) ||
                  (b['name']?.toString() == ownName))
              .toList();
          if (barangays.isNotEmpty) {
            selectedBarangay = barangays.first;
            lockBarangay = true;
          }
        }
      }
    });
  }

  Future<void> saveCenter() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select barangay.'), backgroundColor: AppColors.primaryRed));
      return;
    }

    setState(() => isSaving = true);
    final result = await EvacuationCenterService.saveEvacuationCenter(
      barangay: selectedBarangay!['name'].toString(),
      barangayId: int.tryParse(selectedBarangay!['id'].toString()),
      centerName: centerNameController.text.trim(),
      centerType: typeController.text.trim(),
      capacity: int.tryParse(capacityController.text.trim()) ?? 0,
      status: status,
      contactPerson: contactPersonController.text.trim(),
      contactNumber: contactNumberController.text.trim(),
      latitude: double.tryParse(latitudeController.text.trim()),
      longitude: double.tryParse(longitudeController.text.trim()),
    );
    if (!mounted) return;
    setState(() => isSaving = false);

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Saved.'), backgroundColor: AppColors.successGreen));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']?.toString() ?? 'Failed to save.'), backgroundColor: AppColors.primaryRed));
    }
  }

  InputDecoration decoration(String label, IconData icon) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: const Text('Add Evacuation Center')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SectionTitle(title: 'Assignment'),
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: selectedBarangay,
                isExpanded: true,
                decoration: decoration('Assigned Barangay', Icons.location_on_outlined),
                items: barangays.map((barangay) => DropdownMenuItem(value: barangay, child: Text('${barangay['name']} (${barangay['municipality']})'))).toList(),
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
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(controller: typeController, enabled: !isSaving, decoration: decoration('Center Type', Icons.category_outlined)),
              const SizedBox(height: 12),
              TextFormField(controller: capacityController, enabled: !isSaving, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: decoration('Capacity', Icons.groups_outlined), validator: (v) { final n = int.tryParse((v ?? '').trim()); return n == null ? 'Enter a valid number' : null; }),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: status,
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
              const SectionTitle(title: 'Map Coordinates'),
              TextFormField(controller: latitudeController, enabled: !isSaving, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[^0-9.\-]'))], decoration: decoration('Latitude', Icons.my_location_outlined), validator: (v) { final t = (v ?? '').trim(); if (t.isEmpty) return null; final d = double.tryParse(t); if (d == null) return 'Enter a valid number'; if (d < -90 || d > 90) return 'Latitude must be between -90 and 90'; return null; }),
              const SizedBox(height: 12),
              TextFormField(controller: longitudeController, enabled: !isSaving, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[^0-9.\-]'))], decoration: decoration('Longitude', Icons.my_location_outlined), validator: (v) { final t = (v ?? '').trim(); if (t.isEmpty) return null; final d = double.tryParse(t); if (d == null) return 'Enter a valid number'; if (d < -180 || d > 180) return 'Longitude must be between -180 and 180'; return null; }),
              const SizedBox(height: 22),
              isSaving ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)) : AppButton(text: 'Save Evacuation Center', icon: Icons.save_outlined, onPressed: saveCenter),
            ],
          ),
        ),
      ),
    );
  }
}
