// Quick Logout Test Widget
// Add this to any screen to test immediate logout

import 'package:flutter/material.dart';
import 'app_shell.dart';

class QuickLogoutButton extends StatelessWidget {
  const QuickLogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      onPressed: () => immediateLogout(context),
      child: const Text('Quick Logout'),
    );
  }
}

// Usage: Add this to any screen's body or appBar actions:
// QuickLogoutButton()