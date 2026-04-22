import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/auth_service.dart';
import 'splash_screen.dart';
import 'login_screen.dart';
import 'admin/admin_home_screen.dart';
import 'mde/mde_home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      // Wait a bit for Supabase to restore session from storage
      await Future.delayed(const Duration(milliseconds: 500));
      
      final isLoggedIn = AuthService.isLoggedIn;
      String? role;
      
      if (isLoggedIn) {
        role = await AuthService.getRole();
      }
      
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _userRole = role;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _userRole = null;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return kIsWeb 
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : const SplashScreen();
    }

    if (!_isLoggedIn) {
      return const LoginScreen();
    }

    // User is logged in, navigate to appropriate home screen
    if (_userRole == 'admin') {
      return const AdminHomeScreen();
    } else {
      return const MdeHomeScreen();
    }
  }
}