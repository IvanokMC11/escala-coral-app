import 'attendance.dart';

class Rehearsal {
  final int id;
  final String date;
  final String startTime;
  final String endTime;
  final String? description;
  final String? createdAt;
  final List<Attendance>? attendance;

  Rehearsal({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    this.description,
    this.createdAt,
    this.attendance,
  });

  factory Rehearsal.fromJson(Map<String, dynamic> json) => Rehearsal(
        id: json['id'],
        date: json['date'],
        startTime: json['start_time'],
        endTime: json['end_time'],
        description: json['description'],
        createdAt: json['created_at'],
        attendance: json['attendance'] != null
            ? (json['attendance'] as List)
                .map((a) => Attendance.fromJson(a))
                .toList()
            : null,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'start_time': startTime,
        'end_time': endTime,
        'description': description,
      };
}
