import 'package:flutter/material.dart';


import '../constants/app_colors.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/offline_sync_coordinator.dart';
import 'barangay/barangay_main_screen.dart';
import 'pcf/pcf_main_screen.dart';
import 'pho/pho_main_screen.dart';
import 'superadmin/superadmin_main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void openRoleScreen(String role) {
    if (role == 'barangay' || role == 'brgy') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const BarangayMainScreen()));
      return;
    }

    if (role == 'pcf' || role == 'pfc') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PcfMainScreen()));
      return;
    }

    if (role == 'pho') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PhoMainScreen()));
      return;
    }

    if (role == 'superadmin' || role == 'admin') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SuperadminMainScreen()));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unknown role: $role'), backgroundColor: AppColors.primaryRed),
    );
  }

  Future<void> handleLogin() async {
    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username and password.'), backgroundColor: AppColors.primaryRed),
      );
      return;
    }

    setState(() => isLoading = true);
    final result = await AuthService.login(username: username, password: password);
    if (!mounted) return;
    setState(() => isLoading = false);

    if (result['success'] != true) {
      final message = result['message']?.toString() ?? 'Login failed.';
      final friendly = ApiService.isConnectionFailure(message: message)
          ? 'Cannot reach the server. , then try again.'
          : message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly), backgroundColor: AppColors.primaryRed),
      );
      return;
    }

    final data = result['data'];
    final role = data is Map ? data['role']?.toString().toLowerCase() : null;

    if (role == null || role.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login success, but role was not found.'), backgroundColor: AppColors.primaryRed),
      );
      return;
    }

    // Kick off the global offline-first bootstrap: quietly save hotlines,
    // disaster types, centers, needs, board, and map markers so they are
    // available offline without the user opening those pages first.
    OfflineSyncCoordinator.instance.refreshFromStore();
    OfflineSyncCoordinator.instance.syncNow();

    openRoleScreen(role);
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.textTheme.bodySmall?.color;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: 390,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: theme.dividerColor),
                boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/login_logo_pin.png',
                    height: 120,
                    width: 120,
                    fit: BoxFit.contain,
                  ),

                  
                  const SizedBox(height: 18),
                  Text(
                    'Ugyon',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'BRGY to Municipal to Provincial',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  TextField(controller: usernameController, enabled: !isLoading, decoration: _fieldDecoration('Username', Icons.person_outline)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    enabled: !isLoading,
                    obscureText: hidePassword,
                    decoration: _fieldDecoration('Password', Icons.lock_outline).copyWith(
                      suffixIcon: IconButton(
                        onPressed: isLoading ? null : () => setState(() => hidePassword = !hidePassword),
                        icon: Icon(hidePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : handleLogin,
                      child: isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Demo Only',
                    style: theme.textTheme.bodySmall?.copyWith(color: mutedColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
