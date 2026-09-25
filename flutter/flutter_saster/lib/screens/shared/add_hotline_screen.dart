import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/barangay_service.dart';
import '../../services/hotline_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/section_title.dart';

class AddHotlineScreen extends StatefulWidget {
  const AddHotlineScreen({super.key});

  @override
  State<AddHotlineScreen> createState() => _AddHotlineScreenState();
}

class _AddHotlineScreenState extends State<AddHotlineScreen> {
  final formKey = GlobalKey<FormState>();
  final officeController = TextEditingController();
  final municipalityController = TextEditingController(text: 'Kalibo');
  final telephoneController = TextEditingController();
  final cellphoneController = TextEditingController();
  final hotlineController = TextEditingController();
  final remarksController = TextEditingController();

  bool isLoading = true;
  bool isSaving = false;
  String scope = 'Municipal';
  String category = 'Other';
  Map<String, dynamic>? selectedBarangay;
  List<Map<String, dynamic>> barangays = [];

  final scopes = const ['Municipal', 'Barangay'];
  final categories = const ['Barangay', 'Municipal', 'PNP', 'Fire', 'Medical', 'Hospital', 'MDRRMO', 'PHO', 'Coast Guard', 'Other'];

  @override
  void initState() {
    super.initState();
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
      }
    });
  }

  Future<void> saveHotline() async {
    if (!formKey.currentState!.validate()) return;
    if (scope == 'Barangay' && selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select barangay.'), backgroundColor: AppColors.primaryRed));
      return;
    }

    setState(() => isSaving = true);
    final barangayId = scope == 'Barangay' ? int.tryParse(selectedBarangay!['id'].toString()) : null;
    final muni = scope == 'Barangay'
        ? (selectedBarangay!['municipality']?.toString() ?? municipalityController.text.trim())
        : municipalityController.text.trim();
    final result = await HotlineService.saveHotline(
      hotlineScope: scope,
      barangayId: barangayId,
      officeName: officeController.text.trim(),
      municipality: muni,
      category: category,
      telephoneNumbers: telephoneController.text.trim(),
      cellphoneNumbers: cellphoneController.text.trim(),
      hotlineNumber: hotlineController.text.trim(),
      remarks: remarksController.text.trim(),
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

  InputDecoration decoration(String label, IconData icon) => InputDecoration(labelText: label, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: const Text('Add Hotline')),
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
                onChanged: isSaving ? null : (value) => setState(() { scope = value ?? 'Municipal'; if (scope != 'Barangay') selectedBarangay = null; }),
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
              TextFormField(controller: municipalityController, enabled: !isSaving, decoration: decoration('Municipality', Icons.location_city_outlined)),
              const SizedBox(height: 12),
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
              const SizedBox(height: 22),
              isSaving ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)) : AppButton(text: 'Save Hotline', icon: Icons.save_outlined, onPressed: saveHotline),
            ],
          ),
        ),
      ),
    );
  }
}
