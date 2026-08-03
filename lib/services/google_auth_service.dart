import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

/// Single "Sign in with Google" entry point covering all three roles
/// (super_admin / admin / student). WhatsApp OTP delivery has proven
/// unreliable, so this is the primary working login path — the backend
/// resolves the role from the Google account's email.
class GoogleAuthResult {
  final String role; // 'super_admin' | 'admin' | 'student'
  final Map<String, dynamic> data;
  GoogleAuthResult(this.role, this.data);
}

class GoogleAuthService {
  static Future<GoogleAuthResult> signIn() async {
    final googleProvider = GoogleAuthProvider();
    final credential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
    final idToken = await credential.user?.getIdToken();
    if (idToken == null) {
      throw Exception('Google sign-in did not return a token');
    }

    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['detail']?.toString() ?? 'Google sign-in failed');
    }

    final role = body['role'] as String? ?? 'student';
    if (role == 'student') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('student_token', body['token'] ?? '');
      await prefs.setInt('student_user_id', body['student_user_id'] ?? 0);
      await prefs.setInt('student_id', body['student_id'] ?? 0);
      await prefs.setInt('student_institute_id', body['institute_id'] ?? 0);
      await prefs.setString('student_name', body['name'] ?? '');
      await prefs.setString('student_institute_name', body['institute_name'] ?? '');
    }
    // admin / super_admin: caller stores via AuthProvider.setFromResponse(body),
    // same shape as the existing password-login response.

    return GoogleAuthResult(role, body);
  }

  static Future<void> signOutGoogle() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
}
