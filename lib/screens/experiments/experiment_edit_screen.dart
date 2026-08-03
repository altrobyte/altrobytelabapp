import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/experiment_model.dart';
import '../../services/api_service.dart';

/// Admin editor for a single experiment: objective, step-by-step HTML
/// guide (with live preview), and tool-specific default config.
class ExperimentEditScreen extends StatefulWidget {
  final Experiment experiment;
  const ExperimentEditScreen({super.key, required this.experiment});

  @override
  State<ExperimentEditScreen> createState() => _ExperimentEditScreenState();
}

class _ExperimentEditScreenState extends State<ExperimentEditScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtl;
  late TextEditingController _titleCtl;
  late TextEditingController _objectiveCtl;
  late TextEditingController _guideCtl;

  // MQTT
  late TextEditingController _brokerCtl;
  late TextEditingController _topicCtl;
  // WebSocket
  late TextEditingController _wsUrlCtl;
  // BLE
  late TextEditingController _serviceUuidCtl;
  late TextEditingController _characteristicUuidCtl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.experiment;
    _tabCtl = TabController(length: 2, vsync: this);
    _titleCtl = TextEditingController(text: e.title);
    _objectiveCtl = TextEditingController(text: e.objective);
    _guideCtl = TextEditingController(text: e.guideHtml);
    _brokerCtl = TextEditingController(text: e.toolConfig['broker'] ?? 'broker.hivemq.com');
    _topicCtl = TextEditingController(text: e.toolConfig['topic'] ?? 'altrobyte/experiments/demo');
    _wsUrlCtl = TextEditingController(text: e.toolConfig['url'] ?? 'wss://echo.websocket.org');
    _serviceUuidCtl = TextEditingController(text: e.toolConfig['service_uuid'] ?? '');
    _characteristicUuidCtl = TextEditingController(text: e.toolConfig['characteristic_uuid'] ?? '');
  }

  @override
  void dispose() {
    _tabCtl.dispose();
    _titleCtl.dispose();
    _objectiveCtl.dispose();
    _guideCtl.dispose();
    _brokerCtl.dispose();
    _topicCtl.dispose();
    _wsUrlCtl.dispose();
    _serviceUuidCtl.dispose();
    _characteristicUuidCtl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildToolConfig() {
    switch (widget.experiment.toolType) {
      case 'mqtt':
        return {'broker': _brokerCtl.text.trim(), 'topic': _topicCtl.text.trim()};
      case 'websocket':
        return {'url': _wsUrlCtl.text.trim()};
      case 'ble':
        return {
          'service_uuid': _serviceUuidCtl.text.trim(),
          'characteristic_uuid': _characteristicUuidCtl.text.trim(),
        };
      default:
        return {};
    }
  }

  Future<void> _save() async {
    if (_titleCtl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiService.updateExperiment(widget.experiment.id, {
        'title': _titleCtl.text.trim(),
        'objective': _objectiveCtl.text.trim(),
        'guide_html': _guideCtl.text,
        'tool_config': _buildToolConfig(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.error));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Widget _toolConfigFields() {
    switch (widget.experiment.toolType) {
      case 'mqtt':
        return Column(children: [
          TextField(
            controller: _brokerCtl,
            decoration: InputDecoration(
                labelText: 'Broker host', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicCtl,
            decoration: InputDecoration(
                labelText: 'Default topic', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]);
      case 'websocket':
        return TextField(
          controller: _wsUrlCtl,
          decoration: InputDecoration(
              labelText: 'WebSocket URL (wss://...)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
        );
      case 'ble':
        return Column(children: [
          TextField(
            controller: _serviceUuidCtl,
            decoration: InputDecoration(
                labelText: 'Service UUID (optional hint)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _characteristicUuidCtl,
            decoration: InputDecoration(
                labelText: 'Characteristic UUID (optional hint)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Edit Experiment',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            label: Text('Save', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note_rounded, size: 18), text: 'Details'),
            Tab(icon: Icon(Icons.visibility_rounded, size: 18), text: 'Preview'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtl,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtl,
                  decoration: InputDecoration(
                      labelText: 'Title', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _objectiveCtl,
                  maxLines: 2,
                  decoration: InputDecoration(
                      labelText: 'Objective',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                ),
                const SizedBox(height: 20),
                Text('Tool configuration',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                _toolConfigFields(),
                const SizedBox(height: 20),
                Text('Step-by-step guide (HTML)',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                Container(
                  height: 320,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _guideCtl,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: GoogleFonts.firaCode(color: const Color(0xFFD4D4D4), fontSize: 13, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: '<h2>Step 1</h2><p>Connect to the broker...</p>',
                      hintStyle: TextStyle(color: Colors.white24),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            child: _guideCtl.text.isEmpty
                ? const Center(child: Text('Write a guide to see the preview'))
                : _GuidePreview(html: _guideCtl.text),
          ),
        ],
      ),
    );
  }
}

class _GuidePreview extends StatefulWidget {
  final String html;
  const _GuidePreview({required this.html});

  @override
  State<_GuidePreview> createState() => _GuidePreviewState();
}

class _GuidePreviewState extends State<_GuidePreview> {
  late final String _viewId;
  late final html.IFrameElement _iframe;

  @override
  void initState() {
    super.initState();
    _viewId = 'experiment-guide-preview-${identityHashCode(this)}';
    _iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('sandbox', 'allow-scripts allow-popups allow-forms')
      ..srcdoc = _wrap(widget.html);
    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) => _iframe);
  }

  @override
  void didUpdateWidget(covariant _GuidePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) _iframe.srcdoc = _wrap(widget.html);
  }

  String _wrap(String content) {
    if (content.toLowerCase().contains('<html')) return content;
    return '''
<!DOCTYPE html><html><head><meta charset="utf-8"><style>
body{font-family:Inter,sans-serif;padding:20px;color:#1a1a2e;line-height:1.7;}
pre{background:#1e1e1e;color:#d4d4d4;padding:14px;border-radius:8px;overflow:auto;}
img{max-width:100%;}
</style></head><body>$content</body></html>''';
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewId);
}
