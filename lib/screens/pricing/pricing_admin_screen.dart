import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Super-admin editor for subscription plan display: price labels,
/// billing notes and feature lists — all without a code deploy.
class PricingAdminScreen extends StatefulWidget {
  const PricingAdminScreen({super.key});

  @override
  State<PricingAdminScreen> createState() => _PricingAdminScreenState();
}

class _PricingAdminScreenState extends State<PricingAdminScreen> {
  List<dynamic> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _plans = await ApiService.getSubscriptionPlansAdmin();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editPlan(Map<String, dynamic> plan) async {
    final nameCtrl = TextEditingController(text: plan['display_name'] ?? '');
    final priceCtrl = TextEditingController(text: plan['price_label'] ?? '');
    final noteCtrl = TextEditingController(text: plan['billing_note'] ?? '');
    final features = List<String>.from(plan['features'] ?? []);
    final featuresCtrl = TextEditingController(text: features.join('\n'));
    bool highlighted = plan['is_highlighted'] == true;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Edit ${plan['tier_key']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 14),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
              const SizedBox(height: 10),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Price Label (e.g. ₹999/month, Free, Contact for pricing)')),
              const SizedBox(height: 10),
              TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Billing Note (e.g. per month)')),
              const SizedBox(height: 10),
              TextField(controller: featuresCtrl, maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Features (one per line)', alignLabelWithHint: true)),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Highlight this plan'),
                value: highlighted,
                onChanged: (v) => setSheetState(() => highlighted = v),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await ApiService.updateSubscriptionPlan(plan['tier_key'], {
                        'display_name': nameCtrl.text.trim(),
                        'price_label': priceCtrl.text.trim(),
                        'billing_note': noteCtrl.text.trim(),
                        'features': featuresCtrl.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                        'is_highlighted': highlighted,
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Subscription Plans — Admin', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _plans.length,
              itemBuilder: (context, i) {
                final p = _plans[i] as Map<String, dynamic>;
                final features = List<String>.from(p['features'] ?? []);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('${p['display_name']} — ${p['price_label']}',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    subtitle: Text('${features.length} features${p['is_highlighted'] == true ? ' · Highlighted' : ''}',
                        style: GoogleFonts.inter(fontSize: 12)),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editPlan(p),
                  ),
                );
              },
            ),
    );
  }
}
