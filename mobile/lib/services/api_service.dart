import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/member.dart';
import '../models/rehearsal.dart';
import '../models/attendance.dart';
import '../models/report.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
}

class ApiService {
  String? _token;
  final _client = http.Client();

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: queryParams);

    late http.Response response;
    try {
      response = await _client
          .send(http.Request(method, uri)..headers.addAll(_headers)
            ..body = body != null ? jsonEncode(body) : '')
          .then((r) => http.Response.fromStream(r))
          .timeout(ApiConfig.timeout);
    } catch (e) {
      throw ApiException('Error de conexion: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    }

    final error = _parseError(response.body);
    throw ApiException(error, statusCode: response.statusCode);
  }

  String _parseError(String body) {
    try {
      return jsonDecode(body)['error'] ?? 'Error desconocido';
    } catch (_) {
      return 'Error del servidor';
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _request('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    });
    _token = result['token'];
    return result;
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password, String? phone) async {
    final result = await _request('POST', '/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
      if (phone != null) 'phone': phone,
    });
    _token = result['token'];
    return result;
  }

  Future<List<Member>> getMembers() async {
    final result = await _request('GET', '/members');
    return (result as List).map((m) => Member.fromJson(m)).toList();
  }

  Future<Member> getMember(int id) async {
    final result = await _request('GET', '/members/$id');
    return Member.fromJson(result);
  }

  Future<Member> createMember(
      String name, String? email, String? phone) async {
    final result = await _request('POST', '/members', body: {
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    });
    return Member.fromJson(result);
  }

  Future<Member> updateMember(int id, Map<String, dynamic> data) async {
    final result = await _request('PUT', '/members/$id', body: data);
    return Member.fromJson(result);
  }

  Future<void> deleteMember(int id) async {
    await _request('DELETE', '/members/$id');
  }

  Future<List<Rehearsal>> getRehearsals({String? month, String? year}) async {
    final params = <String, String>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;
    final result = await _request('GET', '/rehearsals', queryParams: params);
    return (result as List).map((r) => Rehearsal.fromJson(r)).toList();
  }

  Future<Rehearsal> getRehearsal(int id) async {
    final result = await _request('GET', '/rehearsals/$id');
    return Rehearsal.fromJson(result);
  }

  Future<Rehearsal> createRehearsal(
      String date, String startTime, String endTime, String? description) async {
    final result = await _request('POST', '/rehearsals', body: {
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      if (description != null) 'description': description,
    });
    return Rehearsal.fromJson(result);
  }

  Future<Map<String, dynamic>> generateRehearsals(
      int year, int month) async {
    return await _request('POST', '/rehearsals/generate', body: {
      'year': year,
      'month': month,
    });
  }

  Future<List<Attendance>> getRehearsalAttendance(int rehearsalId) async {
    final result =
        await _request('GET', '/attendance/rehearsal/$rehearsalId');
    return (result as List).map((a) => Attendance.fromJson(a)).toList();
  }

  Future<Attendance> markAttendance(
      int memberId, int rehearsalId, String arrivalTime,
      {String? notes}) async {
    final result = await _request('POST', '/attendance', body: {
      'member_id': memberId,
      'rehearsal_id': rehearsalId,
      'arrival_time': arrivalTime,
      if (notes != null) 'notes': notes,
    });
    return Attendance.fromJson(result);
  }

  Future<Map<String, dynamic>> markBatchAttendance(
      int rehearsalId, List<Map<String, dynamic>> records) async {
    return await _request('POST', '/attendance/batch', body: {
      'rehearsal_id': rehearsalId,
      'records': records,
    });
  }

  Future<List<MonthlyReport>> getMonthlyReport(
      int year, int month, {int? memberId}) async {
    final params = <String, String>{};
    if (memberId != null) params['member_id'] = memberId.toString();
    final result = await _request(
        'GET', '/reports/monthly/$year/$month',
        queryParams: params);
    return (result as List).map((r) => MonthlyReport.fromJson(r)).toList();
  }

  Future<Top10Response> getTop10(int year, int month) async {
    final result = await _request('GET', '/reports/top10/$year/$month');
    return Top10Response.fromJson(result);
  }

  Future<Map<String, dynamic>> getSettings() async {
    return await _request('GET', '/reports/settings');
  }

  Future<Map<String, dynamic>> updateSettings(
      Map<String, dynamic> settings) async {
    return await _request('PUT', '/reports/settings', body: settings);
  }
}
