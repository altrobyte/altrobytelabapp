import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../models/experiment_model.dart';
import '../../services/api_service.dart';
import 'student_experiment_detail_screen.dart';

/// Student-facing list of published experiments for the (single) institute.
class StudentExperimentsScreen extends StatefulWidget {
  const StudentExperimentsScreen({super.key});

  @override
  State<StudentExperimentsScreen> createState() => _StudentExperimentsScreenState();
}

class _StudentExperimentsScreenState extends State<StudentExperimentsScreen> {
  List<Experiment> _experiments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final instituteId = prefs.getInt('student_institute_id');
    if (instituteId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final raw = await ApiService.getExperimentsStudent(instituteId);
      setState(() {
        _experiments = raw.map((e) => Experiment.fromJson(e)).toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _toolIcon(String toolType) {
    switch (toolType) {
      case 'mqtt':
        return Icons.developer_board_rounded;
      case 'websocket':
        return Icons.swap_horiz_rounded;
      case 'ble':
        return Icons.bluetooth_rounded;
      default:
        return Icons.science_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text('Experiments',
            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _experiments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.science_rounded, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 14),
                      Text('No experiments yet',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Text('Guided hardware experiments will show up here.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _experiments.length,
                  itemBuilder: (context, index) {
                    final exp = _experiments[index];
                    final color = _parseColor(exp.color);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => StudentExperimentDetailScreen(experiment: exp))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(_toolIcon(exp.toolType), color: color, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(exp.title,
                                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600)),
                                      if (exp.objective.isNotEmpty)
                                        Text(exp.objective,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[400]),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
