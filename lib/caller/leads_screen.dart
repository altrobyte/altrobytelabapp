// Leads: everyone in the CRM (a caller sees their own), hottest first, to search and look through. Today is what to call
// next; this is the whole list.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_api.dart';
import 'caller_controller.dart';
import 'models.dart';
import 'today_screen.dart';
import 'widgets.dart';

class LeadsScreen extends StatefulWidget {
  const LeadsScreen({super.key});

  @override
  State<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends State<LeadsScreen> {
  final _search = TextEditingController();
  String _heat = '';
  List<Lead>? _leads;
  int _total = 0;
  Map<String, dynamic> _counts = {};
  String? _problem;
  Timer? _typing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _typing?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _problem = null);
    try {
      final r = await context.read<CallerController>().api.browse(q: _search.text.trim(), heat: _heat);
      if (!mounted) return;
      setState(() {
        _leads = ((r['leads'] as List?) ?? const []).whereType<Map>().map((e) => Lead.fromJson(e.cast<String, dynamic>())).toList();
        _total = (r['total'] as num?)?.toInt() ?? 0;
        _counts = Map<String, dynamic>.from((r['heat_counts'] as Map?) ?? const {});
      });
    } on CallerError catch (e) {
      if (mounted) setState(() => _problem = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = context.watch<CallerController>().now;
    final all = _counts.values.fold<int>(0, (a, b) => a + ((b as num?)?.toInt() ?? 0));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: TextField(
          controller: _search,
          decoration: InputDecoration(
            hintText: 'Search name or number',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onChanged: (_) {
            _typing?.cancel();
            _typing = Timer(const Duration(milliseconds: 400), _load);
          },
        ),
      ),
      SizedBox(
        height: 44,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          for (final h in const ['', 'hot', 'warm', 'cold', 'customer'])
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 4),
              child: ChoiceChip(
                label: Text('${h.isEmpty ? 'All' : heatLabels[h]} ${h.isEmpty ? all : (_counts[h] ?? 0)}'),
                selected: _heat == h,
                onSelected: (_) {
                  setState(() => _heat = h);
                  _load();
                },
              ),
            ),
        ]),
      ),
      Expanded(
        child: _problem != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_problem!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ]))
            : _leads == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _leads!.length + 1,
                      itemBuilder: (context, i) => i == 0
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                              child: Text('$_total lead${_total == 1 ? '' : 's'}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                            )
                          : LeadCard(_leads![i - 1], now: now, key: ValueKey('all_${_leads![i - 1].phone}')),
                    ),
                  ),
      ),
    ]);
  }
}
