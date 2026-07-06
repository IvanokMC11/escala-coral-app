class MonthlyReport {
  final int memberId;
  final String memberName;
  final int totalRehearsals;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int totalLateMinutes;
  final double totalFine;
  final double attendancePercentage;

  MonthlyReport({
    required this.memberId,
    required this.memberName,
    required this.totalRehearsals,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.totalLateMinutes,
    required this.totalFine,
    required this.attendancePercentage,
  });

  factory MonthlyReport.fromJson(Map<String, dynamic> json) => MonthlyReport(
        memberId: json['member_id'],
        memberName: json['member_name'],
        totalRehearsals: json['total_rehearsals'],
        presentCount: json['present_count'],
        lateCount: json['late_count'],
        absentCount: json['absent_count'],
        totalLateMinutes: json['total_late_minutes'],
        totalFine: (json['total_fine'] ?? 0).toDouble(),
        attendancePercentage: (json['attendance_percentage'] ?? 0).toDouble(),
      );
}

class Top10Response {
  final int month;
  final int year;
  final int totalRehearsals;
  final List<MonthlyReport> ranking;

  Top10Response({
    required this.month,
    required this.year,
    required this.totalRehearsals,
    required this.ranking,
  });

  factory Top10Response.fromJson(Map<String, dynamic> json) => Top10Response(
        month: json['month'],
        year: json['year'],
        totalRehearsals: json['total_rehearsals'],
        ranking: (json['ranking'] as List)
            .map((r) => MonthlyReport.fromJson(r))
            .toList(),
      );
}
