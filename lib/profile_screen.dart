import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'models.dart';
import 'storage_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _firebaseService =
      FirebaseService.instance;

  final StorageService _storageService =
      StorageService.instance;

  List<SOSAlert> _alerts = [];
  User? _user;

  bool _isLoading = true;
  bool _usingLocalHistory = false;
  bool _cloudSyncFailed = false;

  // Loads and merges SOS history from local storage and Firebase.
  Future<void> _loadHistory({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final user = AuthService.instance.currentUser;

    if (mounted) {
      setState(() {
        _user = user;
      });
    }

    if (user == null) {
      if (mounted) {
        setState(() {
          _alerts = [];
          _isLoading = false;
          _usingLocalHistory = false;
          _cloudSyncFailed = false;
        });
      }

      return;
    }

    List<SOSAlert> localAlerts = [];

    try {
      localAlerts = await _storageService.getSOSAlerts(
        userId: user.uid,
      );
    } catch (_) {
      localAlerts = [];
    }

    if (mounted) {
      setState(() {
        _alerts = _sortAlerts(localAlerts);
        _usingLocalHistory = localAlerts.isNotEmpty;
        _cloudSyncFailed = false;
        _isLoading = false;
      });
    }

    try {
      final cloudAlerts =
          await _firebaseService.getSOSHistory(
        userId: user.uid,
      );

      final mergedAlerts = _mergeAlerts(
        localAlerts,
        cloudAlerts,
      );

      for (final alert in mergedAlerts) {
        await _storageService.saveSOSAlert(alert);
      }

      if (!mounted) return;

      setState(() {
        _alerts = mergedAlerts;
        _usingLocalHistory = false;
        _cloudSyncFailed = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _alerts = _sortAlerts(localAlerts);
        _usingLocalHistory = localAlerts.isNotEmpty;
        _cloudSyncFailed = true;
      });
    }
  }

  // Merges local and cloud SOS alerts without creating duplicates.
  List<SOSAlert> _mergeAlerts(
    List<SOSAlert> localAlerts,
    List<SOSAlert> cloudAlerts,
  ) {
    final Map<String, SOSAlert> alertMap =
        <String, SOSAlert>{};

    for (final alert in localAlerts) {
      alertMap[alert.id] = alert;
    }

    for (final alert in cloudAlerts) {
      final existing = alertMap[alert.id];

      if (existing == null) {
        alertMap[alert.id] = alert;
        continue;
      }

      if (_statusPriority(alert.status) >=
          _statusPriority(existing.status)) {
        alertMap[alert.id] = alert;
      }
    }

    return _sortAlerts(alertMap.values.toList());
  }

  // Gives cloud and completed states priority over local temporary states.
  int _statusPriority(String status) {
    switch (status) {
      case 'sent':
        return 3;
      case 'failed':
        return 2;
      case 'pending':
        return 1;
      default:
        return 0;
    }
  }

  // Sorts SOS alerts from newest to oldest.
  List<SOSAlert> _sortAlerts(List<SOSAlert> alerts) {
    final sorted = List<SOSAlert>.from(alerts);

    sorted.sort(
      (a, b) => b.timestamp.compareTo(a.timestamp),
    );

    return sorted;
  }

  // Signs the authenticated user out of Firebase.
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You will need to sign in again to access your RapidAid account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(
                context,
                false,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                true,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await AuthService.instance.signOut();

    if (!mounted) return;

    widget.onLogout();
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Builds the profile screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidAidColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _logout,
            tooltip: 'Sign out',
            icon: const Icon(
              Icons.logout_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: RapidAidColors.primary,
          onRefresh: () => _loadHistory(
            showLoader: false,
          ),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              30,
            ),
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 20),
              _buildHistoryHeader(),
              const SizedBox(height: 12),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_alerts.isEmpty)
                _buildEmptyHistory()
              else
                ..._alerts.map(_buildAlertCard),
              if (_usingLocalHistory ||
                  _cloudSyncFailed) ...[
                const SizedBox(height: 14),
                _buildOfflineNotice(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Builds the authenticated user profile header.
  Widget _buildProfileHeader() {
    final email = _user?.email ?? 'Unknown user';

    final initial = email.isNotEmpty
        ? email.substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            RapidAidColors.primary,
            RapidAidColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: RapidAidColors.primary.withValues(
              alpha: 0.20,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.16,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.30,
                ),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'RapidAid account',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.white70,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Authenticated account',
                      style: TextStyle(
                        color: Colors.white.withValues(
                          alpha: 0.78,
                        ),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the SOS history heading.
  Widget _buildHistoryHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                'SOS History',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: RapidAidColors.textPrimary,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Your previous emergency alerts',
                style: TextStyle(
                  fontSize: 12.5,
                  color: RapidAidColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: RapidAidColors.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: RapidAidColors.border,
            ),
          ),
          child: Text(
            '${_alerts.length} alert${_alerts.length == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: RapidAidColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // Builds one SOS history card.
  Widget _buildAlertCard(SOSAlert alert) {
    final isSent = alert.status == 'sent';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RapidAidColors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: RapidAidColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.025,
            ),
            blurRadius: 9,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSent
                      ? RapidAidColors.success
                          .withValues(alpha: 0.10)
                      : RapidAidColors.error
                          .withValues(alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Icon(
                  isSent
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                  color: isSent
                      ? RapidAidColors.success
                      : RapidAidColors.error,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSent
                          ? 'SOS Sent'
                          : 'SOS ${_statusLabel(alert.status)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color:
                            RapidAidColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDateTime(alert.timestamp),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color:
                            RapidAidColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusChip(alert.status),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: RapidAidColors.background,
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Text(
              alert.situation,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: RapidAidColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 16,
                color: RapidAidColors.textLight,
              ),
              const SizedBox(width: 5),
              Text(
                '${alert.contacts.length} recipient${alert.contacts.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color:
                      RapidAidColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builds the SOS status chip.
  Widget _buildStatusChip(String status) {
    final isSent = status == 'sent';

    final backgroundColor = isSent
        ? RapidAidColors.success.withValues(
            alpha: 0.10,
          )
        : RapidAidColors.error.withValues(
            alpha: 0.10,
          );

    final foregroundColor = isSent
        ? RapidAidColors.success
        : RapidAidColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: foregroundColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // Builds the empty SOS history state.
  Widget _buildEmptyHistory() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 36,
      ),
      decoration: BoxDecoration(
        color: RapidAidColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: RapidAidColors.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: RapidAidColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              color: RapidAidColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'No SOS alerts yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: RapidAidColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your completed SOS alerts will appear here '
            'with their time, status and recipients.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: RapidAidColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Builds the offline/cloud sync notice.
  Widget _buildOfflineNotice() {
    final String message = _cloudSyncFailed
        ? 'Cloud history could not be loaded. '
            'Showing all SOS history currently saved on this device.'
        : 'Showing SOS history saved on this device. '
            'Cloud history is synchronised when available.';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5E6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: RapidAidColors.warning.withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: RapidAidColors.warning,
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11.8,
                height: 1.4,
                color: RapidAidColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Converts an SOS status into a readable label.
  String _statusLabel(String status) {
    switch (status) {
      case 'failed':
        return 'Failed';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  // Formats an SOS timestamp for display.
  String _formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month =
        local.month.toString().padLeft(2, '0');
    final year = local.year.toString();

    final hour = local.hour == 0
        ? 12
        : local.hour > 12
            ? local.hour - 12
            : local.hour;

    final minute =
        local.minute.toString().padLeft(2, '0');

    final period = local.hour >= 12
        ? 'PM'
        : 'AM';

    return '$day/$month/$year, $hour:$minute $period';
  }
}