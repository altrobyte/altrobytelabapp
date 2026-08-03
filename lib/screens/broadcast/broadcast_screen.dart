import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/batch_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/institute_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/custom_button_widget.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadBatches();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _postTitleCtrl.dispose();
    _postContentCtrl.dispose();
    _postLinkCtrl.dispose();
    super.dispose();
  }

  // ── WhatsApp Broadcast ──────────────────────────────────────────────────────

  List<Batch> _batches = [];
  int? _selectedBatchId;
  String _mode = 'all';
  final _msgCtrl = TextEditingController();
  bool _sending = false;

  Future<void> _loadBatches() async {
    final auth = context.read<AuthProvider>();
    if (auth.instituteId == null) return;
    await context.read<InstituteProvider>().ensureBatches(auth.instituteId!);
    if (!mounted) return;
    setState(() => _batches = context.read<InstituteProvider>().batches);
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.broadcastMessage),
          backgroundColor: AppColors.error));
      return;
    }
    setState(() => _sending = true);
    final auth = context.read<AuthProvider>();
    try {
      final result = await ApiService.broadcast(
        auth.instituteId!,
        _msgCtrl.text.trim(),
        batchId: _mode == 'batch' ? _selectedBatchId : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Sent to ${result['sent']}/${result['total']} students ✅'),
        backgroundColor: AppColors.success,
      ));
      _msgCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _sending = false);
  }

  // ── Post to Feed ────────────────────────────────────────────────────────────

  String _postType = 'notice'; // 'notice' | 'video'
  String _postCategory = 'general'; // 'general' | 'placement'
  String _postSegment = 'all'; // 'all' | 'subscribers'
  final _postTitleCtrl = TextEditingController();
  final _postContentCtrl = TextEditingController();
  final _postLinkCtrl = TextEditingController();
  bool _posting = false;

  Future<void> _postToFeed() async {
    if (_postTitleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Title required'), backgroundColor: AppColors.error));
      return;
    }
    if (_postType == 'video' && _postLinkCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Video URL required'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _posting = true);
    final auth = context.read<AuthProvider>();
    try {
      await ApiService.postNotice(
        auth.instituteId!,
        _postTitleCtrl.text.trim(),
        content: _postContentCtrl.text.trim(),
        type: _postType,
        linkUrl: _postLinkCtrl.text.trim(),
        category: _postCategory,
        segment: _postSegment,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Posted to student feed ✅'),
        backgroundColor: AppColors.success,
      ));
      _postTitleCtrl.clear();
      _postContentCtrl.clear();
      _postLinkCtrl.clear();
      setState(() {
        _postType = 'notice';
        _postCategory = 'general';
        _postSegment = 'all';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
    if (mounted) setState(() => _posting = false);
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        TabBar(
          controller: _tabCtrl,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 13),
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Post to Feed'),
            Tab(text: 'WhatsApp Broadcast'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildPostTab(),
              _buildBroadcastTab(l10n),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Post to Student Feed',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Students will see this in their home feed',
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
          const SizedBox(height: 20),

          // Type selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Post Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  _typeChip('Announcement', 'notice', Icons.campaign_rounded,
                      AppColors.warning),
                  const SizedBox(width: 10),
                  _typeChip('Video', 'video', Icons.play_circle_filled_rounded,
                      AppColors.error),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Category + audience segment
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Category', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  _categoryChip('General', 'general', Icons.campaign_rounded),
                  const SizedBox(width: 10),
                  _categoryChip('Placement Update', 'placement', Icons.work_rounded),
                ]),
                const SizedBox(height: 18),
                Text('Audience', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(children: [
                  _segmentChip('Everyone', 'all', Icons.public_rounded),
                  const SizedBox(width: 10),
                  _segmentChip('Subscribers only', 'subscribers', Icons.workspace_premium_rounded),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Form fields
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _postTitleCtrl,
                  decoration: InputDecoration(
                    labelText: _postType == 'video' ? 'Video Title' : 'Announcement Title',
                    prefixIcon: Icon(
                      _postType == 'video'
                          ? Icons.play_circle_outline_rounded
                          : Icons.title_rounded,
                    ),
                  ),
                ),
                if (_postType == 'notice') ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _postContentCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Content (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                TextField(
                  controller: _postLinkCtrl,
                  decoration: InputDecoration(
                    labelText: _postType == 'video'
                        ? 'YouTube / Video URL *'
                        : 'Link URL (optional)',
                    hintText: _postType == 'video'
                        ? 'https://youtube.com/watch?v=...'
                        : 'https://...',
                    prefixIcon: Icon(
                      _postType == 'video'
                          ? Icons.smart_display_rounded
                          : Icons.link_rounded,
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                // YouTube thumbnail preview
                if (_postType == 'video' && _postLinkCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _YoutubeThumbnail(url: _postLinkCtrl.text.trim()),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 20),
          OrangeButton(
            label: _postType == 'video' ? 'Post Video' : 'Post Announcement',
            icon: _postType == 'video'
                ? Icons.play_circle_filled_rounded
                : Icons.campaign_rounded,
            onPressed: _postToFeed,
            loading: _posting,
          ),
        ]),
      ),
    );
  }

  Widget _buildBroadcastTab(AppLocalizations l10n) {
    final templates = {
      l10n.broadcastTemplateTestReminder:
          'Dear {name}, a new test has been uploaded for {batch}. Please complete it at your earliest convenience.',
      l10n.broadcastTemplateFeeReminder:
          'Dear {name}, your fee of ₹{amount} is due on {date}. Please make the payment to avoid disruption.',
      l10n.broadcastTemplateResult:
          'Congratulations {name}! Your test results are out. Login to view your performance.',
      l10n.broadcastTemplateHoliday:
          'Dear Students, classes on {date} are cancelled. Classes will resume on the next working day.',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.broadcastTitle,
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text('Send WhatsApp messages to your students',
              style: GoogleFonts.inter(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Recipients', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(children: [
                  _modeChip(l10n.broadcastAllStudents, 'all'),
                  const SizedBox(width: 10),
                  _modeChip('By Batch', 'batch'),
                ]),
                if (_mode == 'batch' && _batches.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    value: _selectedBatchId,
                    decoration: InputDecoration(labelText: l10n.broadcastSelectBatch),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Batches')),
                      ..._batches.map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name))),
                    ],
                    onChanged: (v) => setState(() => _selectedBatchId = v),
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Message Templates',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: templates.keys.map((t) => ActionChip(
                    label: Text(t),
                    onPressed: () => setState(() => _msgCtrl.text = templates[t]!),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    labelStyle: GoogleFonts.inter(color: AppColors.primary, fontSize: 12),
                  )).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: l10n.broadcastMessage,
                    hintText: 'Type your message... Use {name}, {batch}, {amount}, {date}',
                    alignLabelWithHint: true,
                    suffixText: '${_msgCtrl.text.length} chars',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text('Variables: {name} = student name, {batch} = batch name',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          OrangeButton(
            label: l10n.broadcastSend,
            icon: Icons.send_rounded,
            onPressed: _send,
            loading: _sending,
          ),
        ]),
      ),
    );
  }

  Widget _typeChip(String label, String value, IconData icon, Color color) {
    final active = _postType == value;
    return GestureDetector(
      onTap: () => setState(() => _postType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _categoryChip(String label, String value, IconData icon) {
    const color = AppColors.primary;
    final active = _postCategory == value;
    return GestureDetector(
      onTap: () => setState(() => _postCategory = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _segmentChip(String label, String value, IconData icon) {
    const color = AppColors.success;
    final active = _postSegment == value;
    return GestureDetector(
      onTap: () => setState(() => _postSegment = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? Colors.white : color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: active ? Colors.white : color)),
        ]),
      ),
    );
  }

  Widget _modeChip(String label, String value) {
    final active = _mode == value;
    return GestureDetector(
      onTap: () => setState(() => _mode = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(label,
            style: GoogleFonts.inter(
                color: active ? Colors.white : AppColors.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

// ── YouTube thumbnail preview ────────────────────────────────────────────────

class _YoutubeThumbnail extends StatelessWidget {
  final String url;
  const _YoutubeThumbnail({required this.url});

  String? _extractVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) return uri.pathSegments.first;
      if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final id = _extractVideoId(url);
    if (id == null || id.isEmpty) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(child: Text('Preview not available for this URL',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey))),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(alignment: Alignment.center, children: [
        Image.network(
          'https://img.youtube.com/vi/$id/hqdefault.jpg',
          width: double.infinity, height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 160, color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
          ),
        ),
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
        ),
      ]),
    );
  }
}
