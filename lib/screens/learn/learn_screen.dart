import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_colors.dart';
import '../../models/training_module_model.dart';
import '../../providers/training_module_provider.dart';
import '../student/student_module_detail_screen.dart';

/// Public roadmap with a free start (29 Oct 2026, founder): anyone sees the whole curriculum by level, starts the
/// free modules right here with Altron explaining them, and is offered the plans (/unlock) after.
///
/// A topic points at the module that teaches it (ids of the published modules on the Altrobyte institute); a topic
/// with no module yet says "coming soon". The server decides what is free (the first five published modules) and
/// locks the rest, so a wrong badge here can never open anything.
class _Topic {
  final String title;
  final int? moduleId;
  const _Topic(this.title, [this.moduleId]);
}

class _Level {
  final String name, line;
  final Color color;
  final List<_Topic> topics;
  const _Level(this.name, this.line, this.color, this.topics);
}

const _levels = [
  _Level('Beginner', 'Electronics and your first microcontroller', Color(0xFF1E8E3E), [
    _Topic('Voltage, current and resistance', 4),
    _Topic('Basic electronic components', 4),
    _Topic('Microcontrollers and processors', 5),
    _Topic('Arduino, ESP32 and Raspberry Pi', 5),
    _Topic('Programming for hardware'),
  ]),
  _Level('Basic', 'Embedded C, embedded systems and IoT', Color(0xFF1A73E8), [
    _Topic('Embedded C', 5),
    _Topic('Embedded systems', 5),
    _Topic('Internet of Things (IoT)', 8),
    _Topic('Git for embedded projects', 10),
  ]),
  _Level('Advance', 'Industrial-grade firmware', Color(0xFFD4500A), [
    _Topic('STM32'),
    _Topic('Industrial IoT (IIoT)', 9),
    _Topic('FreeRTOS'),
    _Topic('Robotics'),
  ]),
  _Level('Pro', 'Edge AI and shipping a product', Color(0xFF7B1FA2), [
    _Topic('Edge AI / ML', 8),
    _Topic('Product development', 6),
    _Topic('Embedded Linux'),
    _Topic('Computer vision'),
    _Topic('AWS IoT'),
    _Topic('App and web for devices'),
  ]),
];

const freeModules = 5;

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<TrainingModuleProvider>().ensureModulesForStudent());
  }

  /// The modules the server gives away: the first five published, in course order (training_modules._free_module_ids).
  Set<int> _free(List<TrainingModule> mods) {
    // The list comes in the server's course order (order_index, then id), the same order it picks the free ones in.
    return mods.where((m) => m.isPublished).map((m) => m.id).take(freeModules).toSet();
  }

  void _start(TrainingModule m) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentModuleDetailScreen(module: m, completedIds: const {})));
  }

  void _notify(String topic) => launchUrl(
      Uri.parse('https://wa.me/917222977927').replace(queryParameters: {'text': 'Hi, please tell me when "$topic" is ready on Altrobyte.'}),
      mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TrainingModuleProvider>();
    final byId = {for (final m in p.modules) m.id: m};
    final free = _free(p.modules);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Altrobyte Roadmap', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () => context.push('/unlock'),
              child: const Text('Plans', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 40), children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _hero(),
              const SizedBox(height: 22),
              if (p.isLoading && p.modules.isEmpty)
                const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
              for (var i = 0; i < _levels.length; i++) _level(i, _levels[i], byId, free),
              const SizedBox(height: 10),
              _unlockCard(),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primaryLight]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('From your first LED to a shipped IoT product',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700, height: 1.25)),
          const SizedBox(height: 8),
          Text('Start free: $freeModules modules, with Altron, our AI trainer, explaining every lesson to you by voice. '
              'No payment needed to begin.',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14.5, height: 1.5)),
        ]),
      );

  Widget _level(int i, _Level l, Map<int, TrainingModule> byId, Set<int> free) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
                color: l.color.withValues(alpha: .08), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              CircleAvatar(
                  radius: 15,
                  backgroundColor: l.color,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.name, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: l.color)),
                  Text(l.line, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                ]),
              ),
            ]),
          ),
          for (final t in l.topics) _topic(t, byId, free),
        ]),
      );

  Widget _topic(_Topic t, Map<int, TrainingModule> byId, Set<int> free) {
    final m = t.moduleId == null ? null : byId[t.moduleId];
    final isFree = m != null && free.contains(m.id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFF0F1F3)))),
      child: Row(children: [
        Icon(m == null ? Icons.schedule_rounded : (isFree ? Icons.play_circle_fill_rounded : Icons.lock_rounded),
            size: 20, color: m == null ? Colors.grey : (isFree ? AppColors.success : AppColors.accent)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (m != null)
              Text(m.title, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        if (m == null)
          TextButton(onPressed: () => _notify(t.title), child: const Text('Coming soon · Notify me'))
        else if (isFree)
          FilledButton(
              onPressed: () => _start(m),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Start learning · Free'))
        else
          OutlinedButton(onPressed: () => _start(m), child: const Text('Unlock to learn')),
      ]),
    );
  }

  Widget _unlockCard() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.accent)),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: AppColors.accent, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Want every module, an industry expert, or a lab at home?',
                style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
              onPressed: () => context.push('/unlock'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('See all plans')),
        ]),
      );
}
