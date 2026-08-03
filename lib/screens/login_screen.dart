import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../widgets/custom_button_widget.dart';
import '../utils/validators.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Login
  final _loginKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _showPass = false;

  // Register
  final _regKey = GlobalKey<FormState>();
  final _regNameCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regOwnerCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regCityCtrl = TextEditingController();
  bool _showRegPass = false;
  bool _registering = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _regNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPassCtrl.dispose();
    _regOwnerCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regCityCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      context.go('/dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.error ?? 'Login failed'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  Future<void> _register() async {
    if (!_regKey.currentState!.validate()) return;
    setState(() => _registering = true);
    try {
      final data = await ApiService.registerInstitute(
        name: _regNameCtrl.text.trim(),
        email: _regEmailCtrl.text.trim(),
        password: _regPassCtrl.text,
        ownerName: _regOwnerCtrl.text.trim(),
        ownerPhone: _regPhoneCtrl.text.trim(),
        city: _regCityCtrl.text.trim(),
      );
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.setFromResponse(data);
      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: AppColors.error,
      ));
    }
    setState(() => _registering = false);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;

    if (isMobile) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 32),
              _logo(),
              const SizedBox(height: 24),
              _FormCard(
                tabs: _tabs,
                loginKey: _loginKey,
                emailCtrl: _emailCtrl,
                passCtrl: _passCtrl,
                showPass: _showPass,
                togglePass: () => setState(() => _showPass = !_showPass),
                onLogin: _login,
                regKey: _regKey,
                regNameCtrl: _regNameCtrl,
                regEmailCtrl: _regEmailCtrl,
                regPassCtrl: _regPassCtrl,
                regOwnerCtrl: _regOwnerCtrl,
                regPhoneCtrl: _regPhoneCtrl,
                regCityCtrl: _regCityCtrl,
                showRegPass: _showRegPass,
                toggleRegPass: () => setState(() => _showRegPass = !_showRegPass),
                onRegister: _register,
                registering: _registering,
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: w * 0.4, child: _BrandPanel()),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: _FormCard(
                  tabs: _tabs,
                  loginKey: _loginKey,
                  emailCtrl: _emailCtrl,
                  passCtrl: _passCtrl,
                  showPass: _showPass,
                  togglePass: () => setState(() => _showPass = !_showPass),
                  onLogin: _login,
                  regKey: _regKey,
                  regNameCtrl: _regNameCtrl,
                  regEmailCtrl: _regEmailCtrl,
                  regPassCtrl: _regPassCtrl,
                  regOwnerCtrl: _regOwnerCtrl,
                  regPhoneCtrl: _regPhoneCtrl,
                  regCityCtrl: _regCityCtrl,
                  showRegPass: _showRegPass,
                  toggleRegPass: () => setState(() => _showRegPass = !_showRegPass),
                  onRegister: _register,
                  registering: _registering,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo() {
    return Column(children: [
      Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(30)),
        child: const Center(
          child: Text('EHL',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ),
      ),
      const SizedBox(height: 10),
      Text('AltrobyteLab',
          style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary)),
    ]);
  }
}

class _FormCard extends StatelessWidget {
  final TabController tabs;
  final GlobalKey<FormState> loginKey, regKey;
  final TextEditingController emailCtrl, passCtrl;
  final TextEditingController regNameCtrl, regEmailCtrl, regPassCtrl;
  final TextEditingController regOwnerCtrl, regPhoneCtrl, regCityCtrl;
  final bool showPass, showRegPass, registering;
  final VoidCallback togglePass, toggleRegPass, onLogin, onRegister;

  const _FormCard({
    required this.tabs,
    required this.loginKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.showPass,
    required this.togglePass,
    required this.onLogin,
    required this.regKey,
    required this.regNameCtrl,
    required this.regEmailCtrl,
    required this.regPassCtrl,
    required this.regOwnerCtrl,
    required this.regPhoneCtrl,
    required this.regCityCtrl,
    required this.showRegPass,
    required this.toggleRegPass,
    required this.onRegister,
    required this.registering,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tab bar
          Container(
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: TabBar(
              controller: tabs,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'Sign In'), Tab(text: 'Register')],
            ),
          ),
          SizedBox(
            height: 480,
            child: TabBarView(
              controller: tabs,
              children: [
                _LoginTab(
                  formKey: loginKey,
                  emailCtrl: emailCtrl,
                  passCtrl: passCtrl,
                  showPass: showPass,
                  togglePass: togglePass,
                  onLogin: onLogin,
                ),
                _RegisterTab(
                  formKey: regKey,
                  nameCtrl: regNameCtrl,
                  emailCtrl: regEmailCtrl,
                  passCtrl: regPassCtrl,
                  ownerCtrl: regOwnerCtrl,
                  phoneCtrl: regPhoneCtrl,
                  cityCtrl: regCityCtrl,
                  showPass: showRegPass,
                  togglePass: toggleRegPass,
                  onRegister: onRegister,
                  loading: registering,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passCtrl;
  final bool showPass;
  final VoidCallback togglePass, onLogin;

  const _LoginTab({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.showPass,
    required this.togglePass,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome Back! 👋',
                style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Sign in to your AltrobyteLab dashboard',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            TextFormField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => Validators.required(v, 'Email'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: passCtrl,
              obscureText: !showPass,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      showPass ? Icons.visibility_off : Icons.visibility),
                  onPressed: togglePass,
                ),
              ),
              validator: (v) => Validators.required(v, 'Password'),
              onFieldSubmitted: (_) => onLogin(),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => context.go('/forgot-password'),
                child: Text('Forgot password?',
                    style: GoogleFonts.inter(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            GradientButton(
              label: 'Sign In',
              icon: Icons.login_rounded,
              onPressed: onLogin,
              loading: auth.isLoading,
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('or',
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.whatsapp,
                  side: const BorderSide(color: AppColors.whatsapp),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => context.go('/whatsapp-login'),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: Text('Login with WhatsApp OTP',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  try {
                    final result = await GoogleAuthService.signIn();
                    if (result.role == 'admin' || result.role == 'super_admin') {
                      // ignore: use_build_context_synchronously
                      await context.read<AuthProvider>().setFromResponse(result.data);
                      if (context.mounted) {
                        context.go(result.role == 'super_admin' ? '/super/dashboard' : '/dashboard');
                      }
                    } else if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('That Google account is registered as a student, not an admin.')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
                icon: const Icon(Icons.g_mobiledata_rounded, size: 22),
                label: Text('Sign in with Google',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('New here? Click Register tab above',
                  style: GoogleFonts.inter(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegisterTab extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl, emailCtrl, passCtrl;
  final TextEditingController ownerCtrl, phoneCtrl, cityCtrl;
  final bool showPass, loading;
  final VoidCallback togglePass, onRegister;

  const _RegisterTab({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.passCtrl,
    required this.ownerCtrl,
    required this.phoneCtrl,
    required this.cityCtrl,
    required this.showPass,
    required this.togglePass,
    required this.onRegister,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create Account 🚀',
                style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text('Set up your coaching institute',
                style: GoogleFonts.inter(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextFormField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: 'Institute Name *',
                  prefixIcon: Icon(Icons.business_rounded)),
              validator: (v) => Validators.required(v, 'Institute name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: emailCtrl,
              decoration: const InputDecoration(
                  labelText: 'Email *',
                  prefixIcon: Icon(Icons.email_outlined)),
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email required';
                return Validators.email(v);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: passCtrl,
              obscureText: !showPass,
              decoration: InputDecoration(
                labelText: 'Password *',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                      showPass ? Icons.visibility_off : Icons.visibility),
                  onPressed: togglePass,
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: ownerCtrl,
              decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Phone', prefixIcon: Icon(Icons.phone)),
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: cityCtrl,
                  decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city)),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            OrangeButton(
              label: 'Create Account',
              icon: Icons.rocket_launch_rounded,
              onPressed: onRegister,
              loading: loading,
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sidebar,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(36)),
            child: const Center(
              child: Text('EHL',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20)),
            ),
          ),
          const SizedBox(height: 24),
          Text('AltrobyteLab',
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Coaching Management + AI Platform',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 15)),
          const SizedBox(height: 48),
          _feature(Icons.auto_awesome_rounded, 'AI Test Series Generator',
              'Generate 100 MCQs in seconds'),
          const SizedBox(height: 20),
          _feature(Icons.bar_chart_rounded, 'Student Analytics',
              'Track every student\'s progress'),
          const SizedBox(height: 20),
          _feature(Icons.chat_bubble_rounded, 'WhatsApp Integration',
              'Results & fees on WhatsApp'),
          const SizedBox(height: 20),
          _feature(Icons.account_balance_wallet_rounded, 'Fee Management',
              'Track payments & send reminders'),
          const Spacer(),
          Text('Powered by Altrobyte Automation',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String title, String sub) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.accentLight, size: 18),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
        Text(sub,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
      ]),
    ]);
  }
}
