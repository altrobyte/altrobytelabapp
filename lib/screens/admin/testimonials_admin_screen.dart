import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// Where reviews are collected and published.
///
/// The collecting is the hard half. Nobody writes a review unasked, so this
/// screen carries the ask: paste a number, send the message, and add what
/// comes back. Every row starts unpublished, so a half-typed quote never
/// reaches the site.
class TestimonialsAdminScreen extends StatefulWidget {
  const TestimonialsAdminScreen({super.key});

  @override
  State<TestimonialsAdminScreen> createState() =>
      _TestimonialsAdminScreenState();
}

class _TestimonialsAdminScreenState extends State<TestimonialsAdminScreen> {
  List _items = const [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await ApiService.adminGetTestimonials();
      _error = '';
    } catch (e) {
      _error = e is ApiException ? e.message : '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// The message that actually gets a review written.
  ///
  /// Short, names what we want, and gives them something to react to rather
  /// than a blank page — "how was it" gets no reply, three questions get a
  /// paragraph.
  static const _ask =
      'Hi! You did a workshop with Altrobyte Lab.\n\n'
      'Could you send us two or three lines about it? These help other '
      'students decide, and we put them on our site with your name and '
      'college.\n\n'
      'If it helps, answer any of these:\n'
      '· What did you build?\n'
      '· What could you do afterwards that you could not before?\n'
      '· Who would you tell to join?\n\n'
      'Thank you.';

  Future<void> _askSomeone() async {
    final ctrl = TextEditingController();
    final phone = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ask for a review'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp number',
              helperText: '10 digits, or with 91',
            ),
          ),
          const SizedBox(height: 12),
          Text(_ask,
              style: GoogleFonts.inter(
                  fontSize: 11.5, height: 1.5, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, ctrl.text.trim()),
              child: const Text('Open WhatsApp')),
        ],
      ),
    );
    if (phone == null || phone.isEmpty) return;

    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final full = digits.length == 10 ? '91$digits' : digits;
    await launchUrl(
        Uri.parse('https://wa.me/$full?text=${Uri.encodeComponent(_ask)}'),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final where =
        TextEditingController(text: '${existing?['affiliation'] ?? ''}');
    final role = TextEditingController(text: '${existing?['role'] ?? ''}');
    final quote = TextEditingController(text: '${existing?['quote'] ?? ''}');
    var rating = (existing?['rating'] as num?)?.toInt() ?? 5;
    var published = existing?['is_published'] == true;
    var onHome = existing?['show_on_home'] != false;
    var onRoadmap = existing?['show_on_roadmap'] != false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 18,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 18),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(existing == null ? 'Add a review' : 'Edit review',
                  style: GoogleFonts.poppins(
                      fontSize: 16.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name *')),
              const SizedBox(height: 10),
              TextField(
                  controller: where,
                  decoration: const InputDecoration(
                      labelText: 'College or company',
                      helperText: 'The part a reader recognises')),
              const SizedBox(height: 10),
              TextField(
                  controller: role,
                  decoration: const InputDecoration(
                      labelText: 'Branch or role',
                      hintText: 'ECE, 3rd year')),
              const SizedBox(height: 10),
              TextField(
                controller: quote,
                maxLines: 5,
                decoration: const InputDecoration(
                    labelText: 'What they said *',
                    alignLabelWithHint: true,
                    helperText: 'Their words, not ours'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text('Rating',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(width: 10),
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setSheetState(() => rating = i),
                    icon: Icon(
                        i <= rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: const Color(0xFFF5A623)),
                  ),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Published'),
                subtitle: const Text('Off until you are happy with it',
                    style: TextStyle(fontSize: 12)),
                value: published,
                activeColor: AppColors.accent,
                onChanged: (v) => setSheetState(() => published = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on home page'),
                value: onHome,
                activeColor: AppColors.accent,
                onChanged: (v) => setSheetState(() => onHome = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Show on roadmap page'),
                value: onRoadmap,
                activeColor: AppColors.accent,
                onChanged: (v) => setSheetState(() => onRoadmap = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () async {
                    if (name.text.trim().isEmpty ||
                        quote.text.trim().isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('A review needs a name and their words')));
                      return;
                    }
                    Navigator.pop(sheetContext, true);
                  },
                  child: const Text('Save'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    if (saved != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.adminSaveTestimonial({
        'name': name.text.trim(),
        'affiliation': where.text.trim(),
        'role': role.text.trim(),
        'quote': quote.text.trim(),
        'rating': rating,
        'is_published': published,
        'show_on_home': onHome,
        'show_on_roadmap': onRoadmap,
        'order_index': (existing?['order_index'] as num?)?.toInt() ?? 0,
      }, id: existing?['id'] as int?);
      _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e is ApiException ? e.message : '$e')));
    }
  }

  Future<void> _delete(Map<String, dynamic> t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete review?'),
        content: Text('Remove the review from ${t['name']}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ApiService.adminDeleteTestimonial(t['id'] as int);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e is ApiException ? e.message : '$e')));
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Reviews',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: 'Ask someone for a review',
            onPressed: _askSomeone,
            icon: const Icon(Icons.forum_rounded),
          ),
          IconButton(
              tooltip: 'Add a review',
              onPressed: () => _edit(),
              icon: const Icon(Icons.add)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error))
              : _items.isEmpty
                  ? _empty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) =>
                          _row(Map<String, dynamic>.from(_items[i])),
                    ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.format_quote_rounded,
                size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('No reviews yet',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
                'Ask somebody who has already done a workshop. Their name and '
                'college is what makes the next student believe it.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 13)),
              onPressed: _askSomeone,
              icon: const Icon(Icons.forum_rounded, size: 17),
              label: const Text('Ask for a review on WhatsApp'),
            ),
          ]),
        ),
      );

  Widget _row(Map<String, dynamic> t) {
    final live = t['is_published'] == true;
    final rating = (t['rating'] as num?)?.toInt() ?? 5;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('${t['name']}',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: (live ? AppColors.success : AppColors.textSecondary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(live ? 'PUBLISHED' : 'DRAFT',
                style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: live ? AppColors.success : AppColors.textSecondary)),
          ),
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _edit(t),
              icon: const Icon(Icons.edit_rounded,
                  size: 18, color: AppColors.primary)),
          IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _delete(t),
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppColors.error)),
        ]),
        Row(children: [
          for (var i = 0; i < 5; i++)
            Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 13, color: const Color(0xFFF5A623)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
                [t['role'], t['affiliation']]
                    .map((e) => '${e ?? ''}'.trim())
                    .where((e) => e.isNotEmpty)
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ),
        ]),
        const SizedBox(height: 8),
        Text('"${t['quote']}"',
            style: GoogleFonts.inter(
                fontSize: 12.5, height: 1.5, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          _where('Home', t['show_on_home'] != false),
          const SizedBox(width: 7),
          _where('Roadmap', t['show_on_roadmap'] != false),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Copy the quote',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '${t['quote']}'));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quote copied')));
            },
            icon: const Icon(Icons.copy_rounded,
                size: 15, color: AppColors.textSecondary),
          ),
        ]),
      ]),
    );
  }

  Widget _where(String label, bool on) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: on
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: on
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : const Color(0xFFE6EBF3)),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.primary : AppColors.textSecondary)),
      );
}
