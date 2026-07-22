class Batch {
  final int id;
  final int instituteId;
  final String name;
  final String subject;
  final String schedule;
  final String teacherName;
  final bool isActive;
  final int? studentCount;

  Batch({
    required this.id,
    required this.instituteId,
    required this.name,
    required this.subject,
    required this.schedule,
    required this.teacherName,
    required this.isActive,
    this.studentCount,
  });

  factory Batch.fromJson(Map<String, dynamic> j) => Batch(
        id: j['id'] ?? 0,
        instituteId: j['institute_id'] ?? 0,
        name: j['name'] ?? '',
        subject: j['subject'] ?? '',
        schedule: j['schedule'] ?? '',
        teacherName: j['teacher_name'] ?? '',
        isActive: j['is_active'] ?? true,
        studentCount: j['student_count'],
      );
}
