import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  // Login — returns error string or null on success
  static Future<String?> login(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  static Future<void> logout() async {
    try {
      // Sign out from Supabase
      await _client.auth.signOut();
      
      // Clear any cached data if needed
      // Note: Supabase automatically clears the session
    } catch (e) {
      // Even if logout fails, we should still clear local session
      print('Logout error: $e');
      // Force clear session by reinitializing client if needed
      rethrow;
    }
  }

  static User? get currentUser => _client.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  // Read role from user_metadata (set during profile update — no extra DB call)
  static String? getRoleSync() {
    final meta = currentUser?.userMetadata;
    return meta?['role'] as String?;
  }

  // Fetch role from profiles table with a timeout
  static Future<String?> getRole() async {
    final user = currentUser;
    if (user == null) return null;

    // Try metadata first (instant, no network)
    final metaRole = getRoleSync();
    if (metaRole != null) return metaRole;

    // Fallback: fetch from DB with 8s timeout
    try {
      final data = await _client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single()
          .timeout(const Duration(seconds: 8));
      return data['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  // Fetch full profile with timeout
  static Future<Map<String, dynamic>?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;
    try {
      return await _client
          .from('profiles')
          .select('id, name, role')
          .eq('id', user.id)
          .single()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return null;
    }
  }

  // Stream auth state changes
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;
}
