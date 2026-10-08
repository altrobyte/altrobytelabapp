import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/html_frame.dart';

/// The pictures the AI Lab assistant drew from a module's notes (the wiring, the ideas behind it), shown as a page.
/// They are the same pictures the assistant shows beside the editor while it guides the experiment.
class AiLabVisualsScreen extends StatefulWidget {
  final int moduleId;
  final int labId;
  final String title;
  const AiLabVisualsScreen({super.key, required this.moduleId, required this.labId, required this.title});

  @override
  State<AiLabVisualsScreen> createState() => _AiLabVisualsScreenState();
}

class _AiLabVisualsScreenState extends State<AiLabVisualsScreen> {
  List<Map<String, dynamic>> _visuals = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    () async {
      try {
        final r = await ApiService.aiLabVisuals(widget.moduleId, widget.labId);
        _visuals = [for (final v in (r['visuals'] as List? ?? const [])) Map<String, dynamic>.from(v as Map)];
      } catch (e) {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
      if (mounted) setState(() => _loading = false);
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: ListView(padding: const EdgeInsets.all(16), children: [
                      for (final v in _visuals) ...[
                        Text('${v['title']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 8),
                        Card(
                          elevation: 0,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                          child: HtmlFrame(body: '${v['html']}', height: 380),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ]),
                  ),
                ),
    );
  }
}
