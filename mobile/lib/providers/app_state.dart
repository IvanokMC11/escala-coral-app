import 'package:flutter/material.dart';
import '../models/member.dart';
import '../services/api_service.dart';

class AppState extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _loading = false;
  String? _token;
  Map<String, dynamic>? _user;
  List<Member> _members = [];
  List<Member> _filteredMembers = [];
  String? _error;

  bool get loading => _loading;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  List<Member> get members => _filteredMembers;
  List<Member> get allMembers => _members;
  String? get error => _error;
  bool get isLoggedIn => _token != null;
  bool get isAdmin => _user?['role'] == 'admin';

  void setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    setLoading(true);
    _error = null;
    try {
      final result = await _api.login(email, password);
      _token = result['token'];
      _user = result['user'];
      _api.setToken(_token);
      await loadMembers();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      setLoading(false);
    }
  }

  Future<void> register(
      String name, String email, String password, String? phone) async {
    setLoading(true);
    _error = null;
    try {
      final result = await _api.register(name, email, password, phone);
      _token = result['token'];
      _user = result['user'];
      _api.setToken(_token);
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      setLoading(false);
    }
  }

  void logout() {
    _token = null;
    _user = null;
    _members = [];
    _filteredMembers = [];
    _api.setToken(null);
    notifyListeners();
  }

  Future<void> loadMembers() async {
    try {
      _members = await _api.getMembers();
      _filteredMembers = _members;
      notifyListeners();
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  void filterMembers(String query) {
    if (query.isEmpty) {
      _filteredMembers = _members;
    } else {
      _filteredMembers = _members
          .where((m) => m.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    notifyListeners();
  }

  Future<void> addMember(String name, String? email, String? phone) async {
    try {
      await _api.createMember(name, email, phone);
      await loadMembers();
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  Future<void> editMember(int id, Map<String, dynamic> data) async {
    try {
      await _api.updateMember(id, data);
      await loadMembers();
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  Future<void> removeMember(int id) async {
    try {
      await _api.deleteMember(id);
      await loadMembers();
    } on ApiException catch (e) {
      _error = e.message;
    }
  }

  ApiService get api => _api;
}
