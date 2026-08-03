import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// TEMPORARY pre-launch shortcut: opening this URL directly logs in as
/// admin or super admin with zero credentials (via the debug auto-login
/// endpoints) and redirects straight to the dashboard. Remove this screen
/// and its routes before real launch.
class DebugAccessScreen extends StatefulWidget {
  final bool superAdmin;
  const DebugAccessScreen({super.key, required this.superAdmin});

  @override
  State<DebugAccessScreen> createState() => _DebugAccessScreenState();
}

class _DebugAccessScreenState extends State<DebugAccessScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    final auth = context.read<AuthProvider>();
    try {
      final data = widget.superAdmin
          ? await ApiService.debugAutoLoginSuperAdmin()
          : await ApiService.debugAutoLoginAdmin();
      await auth.setFromResponse(data);
      if (!mounted) return;
      context.go(widget.superAdmin ? '/super/dashboard' : '/dashboard');
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: _error == null
            ? const CircularProgressIndicator(color: Colors.white)
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_error!, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _go, child: const Text('Retry')),
                ]),
              ),
      ),
    );
  }
}
