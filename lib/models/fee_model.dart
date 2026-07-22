class Fee {
  final int id;
  final int studentId;
  final int instituteId;
  final double amount;
  final String dueDate;
  final String? paidDate;
  final String status;
  final String? paymentMode;
  final String? studentName;
  final String? studentPhone;
  final String? parentPhone;
  final String? batchName;

  Fee({
    required this.id,
    required this.studentId,
    required this.instituteId,
    required this.amount,
    required this.dueDate,
    this.paidDate,
    required this.status,
    this.paymentMode,
    this.studentName,
    this.studentPhone,
    this.parentPhone,
    this.batchName,
  });

  factory Fee.fromJson(Map<String, dynamic> j) => Fee(
        id: j['id'] ?? 0,
        studentId: j['student_id'] ?? 0,
        instituteId: j['institute_id'] ?? 0,
        amount: (j['amount'] ?? 0).toDouble(),
        dueDate: j['due_date']?.toString() ?? '',
        paidDate: j['paid_date']?.toString(),
        status: j['status'] ?? 'pending',
        paymentMode: j['payment_mode'],
        studentName: j['student_name'],
        studentPhone: j['student_phone'],
        parentPhone: j['parent_phone'],
        batchName: j['batch_name'],
      );

  bool get isOverdue {
    try {
      final due = DateTime.parse(dueDate);
      return status == 'pending' && due.isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }
}
