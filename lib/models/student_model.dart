class Student {
  final int id;
  final int instituteId;
  final String name;
  final String phone;
  final String email;
  final int? batchId;
  final String? batchName;
  final String parentPhone;
  final String feeStatus;
  final DateTime? enrolledAt;

  Student({
    required this.id,
    required this.instituteId,
    required this.name,
    required this.phone,
    required this.email,
    this.batchId,
    this.batchName,
    required this.parentPhone,
    required this.feeStatus,
    this.enrolledAt,
  });

  factory Student.fromJson(Map<String, dynamic> j) => Student(
        id: j['id'] ?? 0,
        instituteId: j['institute_id'] ?? 0,
        name: j['name'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        batchId: j['batch_id'],
        batchName: j['batch_name'],
        parentPhone: j['parent_phone'] ?? '',
        feeStatus: j['fee_status'] ?? 'pending',
        enrolledAt: j['enrolled_at'] != null
            ? DateTime.tryParse(j['enrolled_at'])
            : null,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'email': email,
        'batch_id': batchId,
        'parent_phone': parentPhone,
        'fee_status': feeStatus,
      };

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
