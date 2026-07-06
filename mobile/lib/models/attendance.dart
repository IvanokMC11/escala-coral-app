class Attendance {
  final int id;
  final int memberId;
  final int rehearsalId;
  final String arrivalTime;
  final String status;
  final int lateMinutes;
  final double fineAmount;
  final String? notes;
  final String? memberName;
  final String? date;
  final String? startTime;
  final String? endTime;

  Attendance({
    required this.id,
    required this.memberId,
    required this.rehearsalId,
    required this.arrivalTime,
    required this.status,
    this.lateMinutes = 0,
    this.fineAmount = 0,
    this.notes,
    this.memberName,
    this.date,
    this.startTime,
    this.endTime,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) => Attendance(
        id: json['id'] ?? 0,
        memberId: json['member_id'],
        rehearsalId: json['rehearsal_id'],
        arrivalTime: json['arrival_time'],
        status: json['status'],
        lateMinutes: json['late_minutes'] ?? 0,
        fineAmount: (json['fine_amount'] ?? 0).toDouble(),
        notes: json['notes'],
        memberName: json['member_name'],
        date: json['date'],
        startTime: json['start_time'],
        endTime: json['end_time'],
      );

  bool get isLate => status == 'late';
  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
}
