import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  // Initialize with your Supabase URL and anon key
  static const String supabaseUrl = 'https://tyctugbqmruvsawanygk.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR5Y3R1Z2JxbXJ1dnNhd2FueWdrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjUyNzY1MjgsImV4cCI6MjA4MDg1MjUyOH0.ra8cZ6XLd8dxfWREOewcdYX7n4vLbsLBL9i-7Qa2p3M';

  SupabaseClient get client => Supabase.instance.client;

  // Auth methods
  Future<void> sendOTP(String email) async {
    await client.auth.signInWithOtp(email: email);
  }

  Future<AuthResponse> verifyOTP(String email, String token) async {
    return await client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  Future<User?> getCurrentUser() async {
    return client.auth.currentUser;
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Google Sign-In
  Future<bool> signInWithGoogle() async {
    return await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'com.xeroflow.xeroflow://login-callback',
    );
  }

  // Student methods
  Future<Student?> getStudentByEmail(String email) async {
    try {
      final response = await client
          .from('students')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) return null;
      return Student.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching student: $e');
    }
  }

  Future<Student?> getStudentById(String id) async {
    try {
      final response = await client
          .from('students')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Student.fromJson(response);
    } catch (e) {
      throw Exception('Error fetching student: $e');
    }
  }

  Future<Student> createStudent(Student student, String userId) async {
    try {
      final studentData = student.toJson();
      studentData['id'] = userId; // Link student record with auth user ID

      final response = await client
          .from('students')
          .insert(studentData)
          .select()
          .single();

      return Student.fromJson(response);
    } catch (e) {
      throw Exception('Error creating student: $e');
    }
  }

  Future<Student> updateStudent(String id, Map<String, dynamic> updates) async {
    try {
      final response = await client
          .from('students')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return Student.fromJson(response);
    } catch (e) {
      throw Exception('Error updating student: $e');
    }
  }

  // Check if user has completed profile
  Future<bool> hasCompletedProfile(String userId) async {
    try {
      final student = await getStudentById(userId);
      return student != null;
    } catch (e) {
      return false;
    }
  }
}
