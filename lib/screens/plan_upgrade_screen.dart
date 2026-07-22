import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class PlanUpgradeScreen extends StatefulWidget {
  const PlanUpgradeScreen({super.key});

  @override
  State<PlanUpgradeScreen> createState() => _PlanUpgradeScreenState();
}

class _PlanUpgradeScreenState extends State<PlanUpgradeScreen> {
  List<Map<String, dynamic>> _plans = [];
  Map<String, dynamic>? _currentSub;
  bool _loading = true;
  bool _paying = false;
  bool _verifying = false;
  bool _awaitingVerify = false; // show verify button after payment link opened
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final results = await Future.wait([
        ApiService.getAvailablePlans(),
        if (auth.instituteId != null)
          ApiService.getSubscription(auth.instituteId!)
        else
          Future.value(<String, dynamic>{}),
      ]);
      setState(() {
        _plans = List<Map<String, dynamic>>.from(results[0]['plans'] ?? []);
        _currentSub = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String get _currentPlan => _currentSub?['plan'] ?? 'starter';

  bool _isCurrentPlan(Map<String, dynamic> plan) =>
      plan['plan_key'] == _currentPlan;

  Future<void> _subscribe(Map<String, dynamic> plan, int months) async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    setState(() => _paying = true);
    try {
      final res = await ApiService.createSubscriptionLink(
        auth.instituteId!,
        plan['plan_key'],
        durationMonths: months,
      );
      final url = (res['link_url'] ?? '').toString();
      if (url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // Auto-poll in background — show banner + keep polling until paid
          if (mounted) {
            setState(() => _awaitingVerify = true);
            _autoPollVerify();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _paying = false);
  }

  Future<void> _autoPollVerify() async {
    // Poll every 4 seconds for up to 5 minutes
    for (int i = 0; i < 75; i++) {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted || !_awaitingVerify) return;
      try {
        final res = await ApiService.verifySubscriptionPayment(
            context.read<AuthProvider>().instituteId!);
        if ((res['status'] ?? '') == 'paid') {
          if (!mounted) return;
          setState(() => _awaitingVerify = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Plan activated successfully!'),
            backgroundColor: AppColors.success,
          ));
          _load();
          return;
        }
      } catch (_) {}
    }
  }

  Future<void> _verifyPayment() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    setState(() => _verifying = true);
    try {
      final res = await ApiService.verifySubscriptionPayment(auth.instituteId!);
      final status = res['status'] ?? '';
      if (status == 'paid') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment verified! Plan activated.'),
            backgroundColor: AppColors.success,
          ));
          setState(() => _awaitingVerify = false);
          _load(); // refresh subscription state
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Payment not confirmed yet (status: $status). Try again in a moment.'),
            backgroundColor: AppColors.warning,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
    if (mounted) setState(() => _verifying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Plan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _selectedIndex != null
              ? _buildComparison(_plans[_selectedIndex!])
              : _buildPlanList(),
    );
  }

  Widget _buildPlanList() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_awaitingVerify) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Waiting for payment confirmation...',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('Plan will activate automatically once payment is received.',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                ])),
                TextButton(
                  onPressed: _verifying ? null : _verifyPayment,
                  child: const Text('Check now'),
                ),
              ]),
            ),
            const SizedBox(height: 20),
          ],
          Text('Select the plan that works for you',
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          ..._plans.asMap().entries.map((entry) {
            final i = entry.key;
            final plan = entry.value;
            final isCurrent = _isCurrentPlan(plan);
            final isRecommended = plan['plan_key'] == 'pro';
            return _PlanCard(
              plan: plan,
              isCurrent: isCurrent,
              isRecommended: isRecommended,
              onTap: isCurrent ? null : () => setState(() => _selectedIndex = i),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComparison(Map<String, dynamic> newPlan) {
    final currentPlanData = _plans.firstWhere(
      (p) => p['plan_key'] == _currentPlan,
      orElse: () => _plans.first,
    );
    final newFeatures = _getFeatureList(newPlan);
    final currentFeatures = _getFeatureList(currentPlanData);
    final gained = newFeatures.where((f) => !currentFeatures.contains(f)).toList();
    final kept = newFeatures.where((f) => currentFeatures.contains(f)).toList();

    final currentPrice = currentPlanData['price_monthly'] ?? 0;
    final newPrice = newPlan['price_monthly'] ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => setState(() => _selectedIndex = null),
            ),
            Expanded(
              child: Text(
                'Switching to ${newPlan['display_name']}',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          if (gained.isNotEmpty) ...[
            Text('YOU WILL GAIN',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.success, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            ...gained.map((f) => _FeatureRow(f, AppColors.success, Icons.add_circle_rounded)),
            const SizedBox(height: 20),
          ],

          if (kept.isNotEmpty) ...[
            Text('YOU ALREADY HAVE',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            ...kept.map((f) => _FeatureRow(f, AppColors.textSecondary, Icons.check_rounded)),
            const SizedBox(height: 20),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              _PriceRow('Current', '₹$currentPrice/mo', AppColors.textSecondary),
              _PriceRow('New', '₹$newPrice/mo', AppColors.primary),
              const Divider(),
              _PriceRow(
                'Difference',
                '${newPrice > currentPrice ? '+' : ''}₹${newPrice - currentPrice}/mo',
                newPrice > currentPrice ? AppColors.accent : AppColors.success,
              ),
            ]),
          ),
          const SizedBox(height: 24),

          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _selectedIndex = null),
                child: const Text('Go Back'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _paying ? null : () => _showPaymentOptions(newPlan),
                icon: _paying
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: Text('Upgrade to ${newPlan['display_name']}'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showPaymentOptions(Map<String, dynamic> plan) {
    final monthly = plan['price_monthly'] ?? 0;
    final yearly = plan['price_yearly'] ?? (monthly * 12);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Pay for ${plan['display_name']}',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Valid for 30 days from today',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          _PayOption(
            label: 'Monthly',
            price: '₹$monthly',
            subtitle: 'Billed every month',
            onTap: () { Navigator.pop(context); _subscribe(plan, 1); },
          ),
          const SizedBox(height: 10),
          _PayOption(
            label: 'Yearly (Save ${((1 - yearly / (monthly * 12)) * 100).toStringAsFixed(0)}%)',
            price: '₹$yearly',
            subtitle: 'Billed once per year',
            highlight: true,
            onTap: () { Navigator.pop(context); _subscribe(plan, 12); },
          ),
        ]),
      ),
    );
  }

  List<String> _getFeatureList(Map<String, dynamic> plan) {
    final features = <String>[];
    final maxS = plan['max_students'] ?? 50;
    features.add(maxS == -1 ? 'Unlimited students' : 'Up to $maxS students');
    final maxB = plan['max_batches'] ?? 5;
    features.add(maxB == -1 ? 'Unlimited batches' : 'Up to $maxB batches');
    features.add('${plan['max_managers'] ?? 1} manager accounts');
    if (plan['ai_test_generation'] == true) {
      final limit = plan['ai_tests_per_month'] ?? 20;
      features.add(limit == -1 ? 'Unlimited AI tests' : '$limit AI tests/month');
    }
    if (plan['whatsapp_broadcasts'] == true) features.add('WhatsApp broadcasts');
    if (plan['analytics_advanced'] == true) features.add('Advanced analytics');
    if (plan['pwa_custom_branding'] == true) features.add('Custom PWA branding');
    if (plan['priority_support'] == true) features.add('Priority support');
    if (plan['custom_domain'] == true) features.add('Custom domain');
    return features;
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final bool isCurrent;
  final bool isRecommended;
  final VoidCallback? onTap;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isRecommended,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final price = plan['price_monthly'] ?? 0;
    final maxS = plan['max_students'] ?? 50;
    final studentLabel = maxS == -1 ? 'Unlimited students' : 'Up to $maxS students';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isCurrent
            ? const BorderSide(color: AppColors.success, width: 2)
            : isRecommended
                ? const BorderSide(color: AppColors.accent, width: 1.5)
                : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(plan['display_name'] ?? '',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Current',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ),
                if (isRecommended && !isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Recommended',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600)),
                  ),
              ]),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹$price',
                      style: GoogleFonts.poppins(
                          fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('/month',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(studentLabel,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              if (plan['ai_test_generation'] == true)
                Text(
                  (plan['ai_tests_per_month'] == -1)
                      ? 'Unlimited AI tests'
                      : '${plan['ai_tests_per_month']} AI tests/month',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  const _FeatureRow(this.text, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 10),
        Text(text, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary)),
      ]),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PriceRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _PayOption extends StatelessWidget {
  final String label;
  final String price;
  final String subtitle;
  final bool highlight;
  final VoidCallback onTap;
  const _PayOption({
    required this.label, required this.price,
    required this.subtitle, this.highlight = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlight ? AppColors.accent : Colors.grey.shade300,
            width: highlight ? 2 : 1,
          ),
          color: highlight ? AppColors.accent.withValues(alpha: 0.04) : null,
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          Text(price, style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: highlight ? AppColors.accent : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}
