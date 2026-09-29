import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'alert_result_screen.dart';
import 'emergency_contacts_screen.dart';
import 'models.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'sos_alert_screen.dart';
import 'storage_service.dart';

class AppNavigation extends StatefulWidget {
  const AppNavigation({super.key});

  @override
  State<AppNavigation> createState() =>
      _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation> {
  final StorageService _storageService =
      StorageService.instance;

  // SOS is the first section shown after login or signup.
  int _currentIndex = 1;

  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // Loads the latest locally available emergency contacts.
  Future<void> _loadContacts() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _contacts = [];
      });

      return;
    }

    final contacts = await _storageService.getContacts(
      userId: user.uid,
    );

    if (!mounted) return;

    setState(() {
      _contacts = contacts;
    });
  }

  // Changes the currently selected navigation page.
  void _changePage(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 1) {
      _loadContacts();
    }
  }

  // Opens the emergency contacts page.
  void _openContacts() {
    setState(() {
      _currentIndex = 0;
    });
  }

  // Opens the SOS page and refreshes the local contacts first.
  Future<void> _openSOS() async {
    await _loadContacts();

    if (!mounted) return;

    setState(() {
      _currentIndex = 1;
    });
  }

  // Opens the settings page.
  void _openSettings() {
    setState(() {
      _currentIndex = 2;
    });
  }

  // Handles a successful SOS alert.
  void _handleSOSSuccess(SOSAlert alert) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertResultScreen(
          alert: alert,
          isFailure: false,
          onDone: () {
            Navigator.of(context).pop();
          },
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // Handles a failed SOS alert.
  void _handleSOSFailure(
    SOSAlert alert,
    Object error,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertResultScreen(
          alert: alert,
          isFailure: true,
          onDone: () {
            Navigator.of(context).pop();
          },
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // Builds the currently selected application page.
  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return EmergencyContactsScreen(
          onOpenSettings: _openSettings,
          onOpenSOS: _openSOS,
        );

      case 1:
        return SOSAlertScreen(
          contacts: _contacts,
          onSuccess: _handleSOSSuccess,
          onFailure: _handleSOSFailure,
          onBack: _openContacts,
        );

      case 2:
        return SettingsScreen(
          onBack: _openContacts,
        );

      case 3:
        return ProfileScreen(
          onLogout: () {
            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        );

      default:
        return SOSAlertScreen(
          contacts: _contacts,
          onSuccess: _handleSOSSuccess,
          onFailure: _handleSOSFailure,
          onBack: _openContacts,
        );
    }
  }

  // Builds the main application navigation.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _buildCurrentPage(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _changePage,
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.contacts_outlined,
            ),
            selectedIcon: Icon(
              Icons.contacts,
            ),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.sos_outlined,
            ),
            selectedIcon: Icon(
              Icons.sos,
            ),
            label: 'SOS',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
            ),
            selectedIcon: Icon(
              Icons.settings,
            ),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon: Icon(
              Icons.person,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}