import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_service.dart';

class LogoutConfirmationDialog extends StatefulWidget {
  final VoidCallback onLoggedOut;

  const LogoutConfirmationDialog({
    super.key,
    required this.onLoggedOut,
  });

  @override
  State<LogoutConfirmationDialog> createState() =>
      _LogoutConfirmationDialogState();
}

class _LogoutConfirmationDialogState
    extends State<LogoutConfirmationDialog> {
  bool _isLoggingOut = false;

  // Signs the user out of Firebase Authentication.
  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await AuthService.instance.signOut();

      if (!mounted) return;

      Navigator.of(context).pop();
      widget.onLoggedOut();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggingOut = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to sign out. Please try again.',
          ),
          backgroundColor: RapidAidColors.error,
        ),
      );
    }
  }

  // Builds the logout confirmation dialog.
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: RapidAidColors.surfaceSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.logout_rounded,
          color: RapidAidColors.primary,
          size: 28,
        ),
      ),
      title: const Text(
        'Sign out?',
        textAlign: TextAlign.center,
      ),
      content: const Text(
        'Are you sure you want to sign out of RapidAid?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: RapidAidColors.textSecondary,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoggingOut
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoggingOut ? null : _logout,
          icon: _isLoggingOut
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.logout_rounded,
                  size: 18,
                ),
          label: Text(
            _isLoggingOut ? 'Signing out...' : 'Sign Out',
          ),
        ),
      ],
    );
  }
}