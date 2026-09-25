import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/barangay_service.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_state.dart';
import '../../widgets/info_card.dart';
import '../../widgets/loading_view.dart';
import '../../widgets/search_box.dart';
import '../../widgets/server_required_notice.dart';

const Map<String, String> kRoleLabels = {
  'superadmin': 'Super Admin',
  'pcf': 'Municipal',
  'pho': 'Provincial',
  'barangay': 'Barangay Account',
};

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final searchController = TextEditingController();
  bool isLoading = true;
  String? errorMessage;
  List<dynamic> users = [];
  List<dynamic> barangays = [];
  int? selectedBarangayId;
  int? population;
  bool savingPopulation = false;

  @override
  void initState() {
    super.initState();
    loadBarangays();
    loadUsers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadBarangays() async {
    final result = await BarangayService.getBarangays();
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() => barangays = result['data'] ?? []);
    }
  }

  Future<void> _savePopulation() async {
    if (selectedBarangayId == null || population == null) {
      showMessage('Select a barangay and enter a population.', error: true);
      return;
    }
    setState(() => savingPopulation = true);
    final result = await BarangayService.updatePopulation(
      barangayId: selectedBarangayId!,
      population: population!,
    );
    if (!mounted) return;
    setState(() => savingPopulation = false);
    showMessage(result['message']?.toString() ?? 'Done', error: result['success'] != true);
  }

  Future<void> loadUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    final result = await UserService.getUsers(search: searchController.text.trim());
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() {
        isLoading = false;
        errorMessage = ApiService.userMessage(result['message']?.toString() ?? 'Failed to load users.');
      });
      return;
    }
    setState(() {
      users = result['data'] ?? [];
      isLoading = false;
    });
  }

  void showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    final text = ApiService.isConnectionFailure(message: message)
        ? kOfflineWriteMessage
        : message;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.primaryRed : AppColors.successGreen,
      ),
    );
  }

  /// Runs [action] only while the server is reachable. While offline, user
  /// management is online-only: a clear explanation is shown instead.
  void guardOffline(VoidCallback action) {
    if (isServerUnreachable()) {
      showMessage(kOfflineWriteMessage, error: true);
      return;
    }
    action();
  }

  Widget statusBadge(String status) {
    final isActive = status == 'Active';
    final color = isActive ? AppColors.successGreen : AppColors.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Future<void> openUserForm({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameController = TextEditingController(text: existing?['name']?.toString() ?? '');
    final usernameController = TextEditingController(text: existing?['username']?.toString() ?? '');
    final passwordController = TextEditingController();
    String role = existing?['role']?.toString() ?? 'barangay';
    if (!kRoleLabels.containsKey(role)) role = 'barangay';
    String subRole = existing?['sub_role']?.toString() ?? 'captain';
    int? barangayId = int.tryParse(existing?['barangay_id']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit User' : 'Add User'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Full name'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(labelText: 'Username'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: isEdit ? 'New password (use Reset Password)' : 'Password',
                          enabled: !isEdit,
                        ),
                        obscureText: true,
                        enabled: !isEdit,
                        validator: (v) {
                          if (isEdit) return null;
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: role,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: kRoleLabels.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setDialogState(() => role = v ?? role),
                      ),
                       if (role == 'barangay') ...[
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: subRole,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Sub-Role'),
                          items: const [
                            DropdownMenuItem(value: 'captain', child: Text('Chairman')),
                            DropdownMenuItem(value: 'secretary', child: Text('Secretary')),
                            DropdownMenuItem(value: 'tanod', child: Text('BHERT')),
                          ],
                          onChanged: (v) => setDialogState(() => subRole = v ?? subRole),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: barangayId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Barangay'),
                          items: barangays
                              .map((b) => DropdownMenuItem<int>(
                                    value: int.tryParse(b['id'].toString()),
                                    child: Text(b['name']?.toString() ?? ''),
                                  ))
                              .toList(),
                          onChanged: (v) => setDialogState(() => barangayId = v),
                          validator: (v) => (role == 'barangay' && v == null) ? 'Choose a barangay' : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => submitting = true);
                          final Map<String, dynamic> result;
                          if (isEdit) {
                            result = await UserService.updateUser(
                              userId: int.parse(existing['id'].toString()),
                              name: nameController.text.trim(),
                              username: usernameController.text.trim(),
                              role: role,
                              subRole: role == 'barangay' ? subRole : null,
                              barangayId: role == 'barangay' ? barangayId : null,
                            );
                          } else {
                            result = await UserService.createUser(
                              name: nameController.text.trim(),
                              username: usernameController.text.trim(),
                              password: passwordController.text,
                              role: role,
                              subRole: role == 'barangay' ? subRole : null,
                              barangayId: role == 'barangay' ? barangayId : null,
                            );
                          }
                          if (!dialogContext.mounted) return;
                          if (result['success'] == true) {
                            Navigator.pop(dialogContext, true);
                          } else {
                            setDialogState(() => submitting = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(result['message']?.toString() ?? 'Action failed.'),
                                backgroundColor: AppColors.primaryRed,
                              ),
                            );
                          }
                        },
                  child: Text(isEdit ? 'Save' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      showMessage(isEdit ? 'User updated successfully.' : 'User created successfully.');
      loadUsers();
    }
  }

  Future<void> openResetPassword(Map<String, dynamic> user) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final done = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        bool submitting = false;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Reset Password — @${user['username']}'),
              content: Form(
                key: formKey,
                child: TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'New password'),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => submitting = true);
                          final result = await UserService.resetPassword(
                            userId: int.parse(user['id'].toString()),
                            password: passwordController.text,
                          );
                          if (!dialogContext.mounted) return;
                          if (result['success'] == true) {
                            Navigator.pop(dialogContext, true);
                          } else {
                            setDialogState(() => submitting = false);
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(result['message']?.toString() ?? 'Action failed.'),
                                backgroundColor: AppColors.primaryRed,
                              ),
                            );
                          }
                        },
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );

    if (done == true) showMessage('Password reset successfully.');
  }

  Future<void> confirmToggle(Map<String, dynamic> user) async {
    final isActive = (user['status']?.toString() ?? 'Active') == 'Active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${isActive ? 'Deactivate' : 'Reactivate'} account'),
        content: Text('${isActive ? 'Deactivate' : 'Reactivate'} @${user['username']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await UserService.toggleStatus(userId: int.parse(user['id'].toString()));
    if (!mounted) return;
    if (result['success'] == true) {
      showMessage(result['message']?.toString() ?? 'Status updated.');
      loadUsers();
    } else {
      showMessage(result['message']?.toString() ?? 'Action failed.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ServerRequiredNotice(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: InfoCard(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.groups, color: AppColors.primaryRed),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: selectedBarangayId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Barangay',
                      isDense: true,
                    ),
                    items: barangays
                        .map((b) => DropdownMenuItem<int>(
                              value: int.tryParse(b['id'].toString()),
                              child: Text(b['name']?.toString() ?? ''),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() {
                      selectedBarangayId = v;
                      for (final b in barangays) {
                        if (b is Map &&
                            int.tryParse(b['id'].toString()) == v) {
                          population = int.tryParse(b['population'].toString());
                          return;
                        }
                      }
                      population = null;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextField(
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    onChanged: (v) => population = int.tryParse(v) ?? 0,
                    decoration: const InputDecoration(
                      labelText: 'Population',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: savingPopulation
                      ? null
                      : () => guardOffline(_savePopulation),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SearchBox(controller: searchController, hint: 'Search users...', onChanged: (_) => loadUsers()),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => guardOffline(() => openUserForm()),
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (isLoading) return const LoadingView();
              if (errorMessage != null) return ErrorState(message: errorMessage!, onRetry: loadUsers);
              if (users.isEmpty) return const EmptyState(icon: Icons.people_outline, message: 'No users found.');
              return RefreshIndicator(
                onRefresh: loadUsers,
                color: AppColors.primaryRed,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = Map<String, dynamic>.from(users[index]);
                    final status = user['status']?.toString() ?? 'Active';
                    final isSelf = AuthService.currentUserId != null &&
                        AuthService.currentUserId == int.tryParse(user['id'].toString());
                    final roleLabel = kRoleLabels[user['role']?.toString()] ?? (user['role']?.toString() ?? '');
                    return InfoCard(
                      child: Row(
                        children: [
                          const CircleAvatar(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white, child: Icon(Icons.person_outline)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(child: Text(user['name']?.toString() ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                                    if (isSelf) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                        child: const Text('You', style: TextStyle(fontSize: 10, color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('@${user['username'] ?? ''} • $roleLabel', style: const TextStyle(fontSize: 12)),
                                if ((user['sub_role']?.toString() ?? '').isNotEmpty)
                                  Text('Sub-Role: ${user['sub_role'].toString() == 'tanod' ? 'BHERT' : '${user['sub_role'].toString()[0].toUpperCase()}${user['sub_role'].toString().substring(1)}'}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                if ((user['barangay_name']?.toString() ?? '').isNotEmpty) Text('Barangay: ${user['barangay_name']}', style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 6),
                                statusBadge(status),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') guardOffline(() => openUserForm(existing: user));
                              if (value == 'reset') guardOffline(() => openResetPassword(user));
                              if (value == 'toggle') guardOffline(() => confirmToggle(user));
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              const PopupMenuItem(value: 'reset', child: Text('Reset Password')),
                              if (!isSelf)
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(status == 'Active' ? 'Deactivate' : 'Reactivate'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
