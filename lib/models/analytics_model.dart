class InstituteAnalytics {
  final int totalStudents;
  final int activeBatches;
  final int totalTests;
  final double avgTestScore;
  final double attendanceRate;
  final double feeTotal;
  final double feeCollected;
  final double feePending;
  final double feeCollectionRate;
  final List<Map<String, dynamic>> topPerformers;
  final List<Map<String, dynamic>> weakPerformers;
  final List<Map<String, dynamic>> subjectPerformance;

  InstituteAnalytics({
    required this.totalStudents,
    required this.activeBatches,
    required this.totalTests,
    required this.avgTestScore,
    required this.attendanceRate,
    required this.feeTotal,
    required this.feeCollected,
    required this.feePending,
    required this.feeCollectionRate,
    required this.topPerformers,
    required this.weakPerformers,
    required this.subjectPerformance,
  });

  factory InstituteAnalytics.fromJson(Map<String, dynamic> j) =>
      InstituteAnalytics(
        totalStudents: j['total_students'] ?? 0,
        activeBatches: j['active_batches'] ?? 0,
        totalTests: j['total_tests'] ?? 0,
        avgTestScore: (j['avg_test_score'] ?? 0).toDouble(),
        attendanceRate: (j['attendance_rate'] ?? 0).toDouble(),
        feeTotal: (j['fee_total'] ?? 0).toDouble(),
        feeCollected: (j['fee_collected'] ?? 0).toDouble(),
        feePending: (j['fee_pending'] ?? 0).toDouble(),
        feeCollectionRate: (j['fee_collection_rate'] ?? 0).toDouble(),
        topPerformers: List<Map<String, dynamic>>.from(
            j['top_performers']?.map((e) => Map<String, dynamic>.from(e)) ?? []),
        weakPerformers: List<Map<String, dynamic>>.from(
            j['weak_performers']?.map((e) => Map<String, dynamic>.from(e)) ?? []),
        subjectPerformance: List<Map<String, dynamic>>.from(
            j['subject_performance']?.map((e) => Map<String, dynamic>.from(e)) ?? []),
      );
}
