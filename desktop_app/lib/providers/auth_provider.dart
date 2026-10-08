import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  // Educator / Manager fields
  String? token;
  String? jwtToken;
  int? instituteId;
  String? instituteName;
  String role = 'admin'; // 'admin' | 'manager' | 'super_admin'
  bool isLoading = false;
  String? error;

  bool isInitialized = false; // true after tryAutoLogin completes

  bool get isLoggedIn => token != null && (instituteId != null || role == 'super_admin');
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isSuperAdmin => role == 'super_admin';
  bool get canBroadcast => role == 'admin' || role == 'super_admin';
  bool get canDelete => role == 'admin' || role == 'super_admin';
  bool get canAccessSettings => role == 'admin' || role == 'super_admin';

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    jwtToken = prefs.getString('jwt_token');
    instituteId = prefs.getInt('institute_id');
    instituteName = prefs.getString('institute_name');
    role = prefs.getString('role') ?? 'admin';
    isInitialized = true;
    notifyListeners();
  }

  Future<void> setFromResponse(Map<String, dynamic> data) async {
    token = data['token'];
    jwtToken = data['jwt_token'];
    role = data['role'] ?? 'admin';
    instituteId = data['institute_id'];
    instituteName = data['name'] ?? data['institute_name'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token!);
    if (jwtToken != null) await prefs.setString('jwt_token', jwtToken!);
    await prefs.setString('role', role);
    if (instituteId != null) await prefs.setInt('institute_id', instituteId!);
    if (instituteName != null) await prefs.setString('institute_name', instituteName!);
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiService.login(email, password);
      await setFromResponse(data);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> managerLogin(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiService.managerLogin(email, password);
      await setFromResponse(data);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> superAdminLogin(String email, String password) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiService.superAdminLogin(email, password);
      await setFromResponse(data);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateInstituteName(String name) async {
    instituteName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('institute_name', name);
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    jwtToken = null;
    instituteId = null;
    instituteName = null;
    role = 'admin';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('jwt_token');
    await prefs.remove('role');
    await prefs.remove('institute_id');
    await prefs.remove('institute_name');
    await prefs.remove('user_role');
    notifyListeners();
  }
}
