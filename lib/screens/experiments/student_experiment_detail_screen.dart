import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/experiment_model.dart';
import '../../services/api_service.dart';
import '../tools/mqtt_tester_screen.dart';
import '../tools/websocket_tester_screen.dart';
import '../tools/ble_tester_screen.dart';

/// Student view of one experiment: objective, step-by-step guide, a
/// button to open the matching live tool (pre-filled from the
/// experiment's config), and a simple result-submission form.
class StudentExperimentDetailScreen extends StatefulWidget {
  final Experiment experiment;
  const StudentExperimentDetailScreen({super.key, required this.experiment});

  @override
  State<StudentExperimentDetailScreen> createState() => _StudentExperimentDetailScreenState();
}

class _StudentExperimentDetailScreenState extends State<StudentExperimentDetailScreen> {
  final _resultCtrl = TextEditingController();
  bool _submitting = false;
  bool? _lastVerified;

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  void _openTool() {
    final cfg = widget.experiment.toolConfig;
    Widget screen;
    switch (widget.experiment.toolType) {
      case 'mqtt':
        screen = MqttTesterScreen(
          initialHost: cfg['broker'] != null ? 'wss://${cfg['broker']}/mqtt' : null,
          initialTopic: cfg['topic'],
        );
        break;
      case 'websocket':
        screen = WebSocketTesterScreen(initialUrl: cfg['url']);
        break;
      case 'ble':
        final uuids = [cfg['service_uuid'], cfg['characteristic_uuid']]
            .where((v) => v != null && v.toString().isNotEmpty)
            .join(', ');
        screen = BleTesterScreen(initialServiceUuids: uuids.isNotEmpty ? uuids : null);
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// Parses simple "key=value, key2=value2" text into a result map so the
  /// backend's auto-verify rule (also flat key/value) can match against it.
  Map<String, dynamic> _parseResult(String text) {
    final map = <String, dynamic>{};
    for (final part in text.split(',')) {
      final kv = part.split('=');
      if (kv.length == 2) map[kv[0].trim()] = kv[1].trim();
    }
    if (map.isEmpty && text.trim().isNotEmpty) map['notes'] = text.trim();
    return map;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await ApiService.submitExperimentAttempt(
        widget.experiment.id,
        _parseResult(_resultCtrl.text),
        notes: _resultCtrl.text,
      );
      setState(() => _lastVerified = result['verified'] == true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_lastVerified == true ? 'Result recorded — verified!' : 'Result recorded.'),
          backgroundColor: _lastVerified == true ? AppColors.success : AppColors.primary,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Submit failed: $e'), backgroundColor: AppColors.error));
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _resultCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exp = widget.experiment;
    final color = _parseColor(exp.color);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: color,
        title: Text(exp.title,
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (exp.objective.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.flag_rounded, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text('Objective', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: color)),
                  ]),
                  const SizedBox(height: 8),
                  Text(exp.objective, style: GoogleFonts.inter(fontSize: 13.5, height: 1.5)),
                ]),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openTool,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('Open Tool', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Guide', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 10),
            if (exp.guideHtml.isNotEmpty)
              SizedBox(
                height: 420,
                child: Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12), borderRadius: BorderRadius.circular(12)),
                  clipBehavior: Clip.antiAlias,
                  child: _GuideView(html: exp.guideHtml),
                ),
              )
            else
              Text('No written guide for this experiment yet.',
                  style: GoogleFonts.inter(color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Text('Submit Your Result', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text('e.g., value=42, status=ok — or just describe what you observed.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: _resultCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'What happened when you ran the experiment?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitting || _resultCtrl.text.trim().isEmpty ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Submit Result', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _GuideView extends StatefulWidget {
  final String html;
  const _GuideView({required this.html});

  @override
  State<_GuideView> createState() => _GuideViewState();
}

class _GuideViewState extends State<_GuideView> {
  late final String _viewId;
  late final html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _viewId = 'experiment-guide-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('sandbox', 'allow-scripts allow-popups allow-forms')
      ..srcdoc = _wrap(widget.html);
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => _iframe);
  }

  String _wrap(String content) {
    if (content.toLowerCase().contains('<html')) return content;
    return '''
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body{font-family:Inter,sans-serif;padding:16px;color:#1a1a2e;line-height:1.7;}
pre{background:#1e1e1e;color:#d4d4d4;padding:14px;border-radius:8px;overflow:auto;}
img{max-width:100%;}
</style></head><body>$content</body></html>''';
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
