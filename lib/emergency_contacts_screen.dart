import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'communication_service.dart';
import 'firebase_service.dart';
import 'logout_screen.dart';
import 'models.dart';
import 'storage_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSOS;

  const EmergencyContactsScreen({
    super.key,
    required this.onOpenSettings,
    required this.onOpenSOS,
  });

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState
    extends State<EmergencyContactsScreen> {
  final FirebaseService _firebaseService =
      FirebaseService.instance;

  final StorageService _storageService =
      StorageService.instance;

  final CommunicationService _communicationService =
      CommunicationService.instance;

  List<EmergencyContact> _contacts = [];
  PriorityNumber? _priorityNumber;

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _usingLocalData = false;
  bool _usingLocalPriority = false;

  // Loads contacts and the priority number from local storage and Firebase.
  Future<void> _loadContacts({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _contacts = [];
        _priorityNumber = null;
        _usingLocalData = false;
        _usingLocalPriority = false;
        _isLoading = false;
      });

      return;
    }

    final localContacts = await _storageService.getContacts(
      userId: user.uid,
    );

    final localPriorityNumber =
        await _storageService.getPriorityNumber(
      userId: user.uid,
    );

    if (mounted) {
      setState(() {
        _contacts = localContacts;
        _priorityNumber = localPriorityNumber;
        _usingLocalData = localContacts.isNotEmpty;
        _usingLocalPriority = localPriorityNumber != null;
        _isLoading = false;
      });
    }

    try {
      final cloudContacts =
          await _firebaseService.getContacts(
        userId: user.uid,
      );

      final cloudPriorityNumber =
          await _firebaseService.getPriorityNumber(
        userId: user.uid,
      );

      final mergedContacts = _mergeContacts(
        localContacts,
        cloudContacts,
      );

      for (final contact in mergedContacts) {
        await _storageService.saveContact(
          userId: user.uid,
          contact: contact,
        );
      }

      PriorityNumber? mergedPriorityNumber =
          cloudPriorityNumber;

      if (localPriorityNumber != null) {
        mergedPriorityNumber = localPriorityNumber;
      }

      if (mergedPriorityNumber != null) {
        await _storageService.savePriorityNumber(
          mergedPriorityNumber,
        );
      }

      if (!mounted) return;

      setState(() {
        _contacts = mergedContacts;
        _priorityNumber = mergedPriorityNumber;

        _usingLocalData =
            localContacts.isNotEmpty &&
            cloudContacts.isEmpty;

        _usingLocalPriority =
            localPriorityNumber != null &&
            cloudPriorityNumber == null;
      });

      final localOnlyContacts = localContacts.where(
        (localContact) {
          return !cloudContacts.any(
            (cloudContact) =>
                cloudContact.id == localContact.id,
          );
        },
      );

      for (final contact in localOnlyContacts) {
        try {
          await _firebaseService.saveContact(
            userId: user.uid,
            contact: contact,
          );
        } catch (_) {}
      }

      if (localPriorityNumber != null &&
          cloudPriorityNumber == null) {
        try {
          await _firebaseService.savePriorityNumber(
            priorityNumber: localPriorityNumber,
          );

          if (!mounted) return;

          setState(() {
            _usingLocalPriority = false;
          });
        } catch (_) {}
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _contacts = localContacts;
        _priorityNumber = localPriorityNumber;
        _usingLocalData = localContacts.isNotEmpty;
        _usingLocalPriority = localPriorityNumber != null;
      });
    }
  }

  // Combines local and cloud contacts without losing locally saved contacts.
  List<EmergencyContact> _mergeContacts(
    List<EmergencyContact> localContacts,
    List<EmergencyContact> cloudContacts,
  ) {
    final contactsById =
        <String, EmergencyContact>{};

    for (final contact in cloudContacts) {
      contactsById[contact.id] = contact;
    }

    for (final contact in localContacts) {
      contactsById[contact.id] = contact;
    }

    final mergedContacts =
        contactsById.values.toList();

    mergedContacts.sort(
      (a, b) => a.name.toLowerCase().compareTo(
        b.name.toLowerCase(),
      ),
    );

    return mergedContacts;
  }

  // Refreshes the contact list and priority number.
  Future<void> _refreshContacts() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    await _loadContacts(showLoader: false);

    if (!mounted) return;

    setState(() {
      _isRefreshing = false;
    });
  }

  // Calls one selected emergency contact directly.
  Future<void> _callContact(
    EmergencyContact contact,
  ) async {
    try {
      final bool success =
          await _communicationService.makePriorityPhoneCall(
        contact.phone,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to call ${contact.name}.',
            ),
            backgroundColor: RapidAidColors.error,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to call ${contact.name}.',
          ),
          backgroundColor: RapidAidColors.error,
        ),
      );
    }
  }

  // Calls the priority emergency number.
  Future<void> _callPriorityNumber() async {
    final priorityNumber = _priorityNumber;

    if (priorityNumber == null ||
        priorityNumber.phone.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No priority number is configured.',
          ),
          backgroundColor: RapidAidColors.error,
        ),
      );

      return;
    }

    try {
      final bool success =
          await _communicationService.makePriorityPhoneCall(
        priorityNumber.phone,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to call the priority number.',
            ),
            backgroundColor: RapidAidColors.error,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to call the priority number.',
          ),
          backgroundColor: RapidAidColors.error,
        ),
      );
    }
  }

  // Opens an SMS composer with a pre-filled message for one emergency contact.
  Future<void> _smsContact(
    EmergencyContact contact,
  ) async {
    const String message =
        'Hello, I have selected you as a trusted emergency contact in RapidAid. '
        'Please contact me if you receive an emergency alert.';

    try {
      await _communicationService.sendSms(
        contact.phone,
        message,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open SMS for ${contact.name}.',
          ),
          backgroundColor: RapidAidColors.error,
        ),
      );
    }
  }

  // Opens an SMS composer with a pre-filled message for the priority number.
  Future<void> _smsPriorityNumber() async {
    final priorityNumber = _priorityNumber;

    if (priorityNumber == null ||
        priorityNumber.phone.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No priority number is configured.',
          ),
          backgroundColor: RapidAidColors.error,
        ),
      );

      return;
    }

    const String message =
        'RAPIDAID EMERGENCY CONTACT\n\n'
        'You are my priority emergency contact in RapidAid. '
        'Please contact me if I need emergency assistance.';

    try {
      await _communicationService.sendSms(
        priorityNumber.phone,
        message,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to open SMS for the priority number.',
          ),
          backgroundColor: RapidAidColors.error,
        ),
      );
    }
  }

  // Opens the logout confirmation dialog.
  Future<void> _showLogoutDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return LogoutConfirmationDialog(
          onLoggedOut: () {
            if (!mounted) return;

            Navigator.of(context).pushNamedAndRemoveUntil(
              '/login',
              (route) => false,
            );
          },
        );
      },
    );
  }

  // Initializes the emergency contacts screen.
  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // Builds the emergency contacts screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidAidColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: RapidAidColors.primary,
          onRefresh: _refreshContacts,
          child: CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              SliverToBoxAdapter(
                child: _buildEmergencyBanner(),
              ),
              if (!_isLoading &&
                  _priorityNumber != null)
                SliverToBoxAdapter(
                  child: _buildPriorityNumberCard(),
                ),
              SliverToBoxAdapter(
                child: _buildSectionHeader(),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_contacts.isEmpty)
                SliverToBoxAdapter(
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    20,
                  ),
                  sliver: SliverList.builder(
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      return _buildContactCard(
                        _contacts[index],
                        index,
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: _buildBottomActionArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the RapidAid header with the splash-screen logo.
  Widget _buildHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Row(
        children: [
          _buildAppLogo(),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'RapidAid',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: RapidAidColors.primary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Emergency Contacts',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color:
                        RapidAidColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed:
                    widget.onOpenSettings,
                tooltip: 'Settings',
                style: IconButton.styleFrom(
                  backgroundColor:
                      RapidAidColors.surface,
                  foregroundColor:
                      RapidAidColors.textPrimary,
                ),
                icon: const Icon(
                  Icons.settings_outlined,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _showLogoutDialog,
                tooltip: 'Sign out',
                style: IconButton.styleFrom(
                  backgroundColor:
                      RapidAidColors.surface,
                  foregroundColor:
                      RapidAidColors.primary,
                ),
                icon: const Icon(
                  Icons.logout_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Builds the RapidAid logo used on the splash screen.
  Widget _buildAppLogo() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: RapidAidColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          CustomPaint(
            size: const Size(31, 31),
            painter: _RapidAidLogoPainter(),
          ),
        ],
      ),
    );
  }

  // Builds the emergency information banner.
  Widget _buildEmergencyBanner() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 0, 20, 22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              RapidAidColors.primary,
              RapidAidColors.primaryDark,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius:
              BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color:
                  RapidAidColors.primary.withValues(
                alpha: 0.20,
              ),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: 0.16,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emergency_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stay ready for emergencies',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Your trusted contacts are ready to receive help requests when you need them.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the priority emergency number card.
  Widget _buildPriorityNumberCard() {
    final priorityNumber = _priorityNumber;

    if (priorityNumber == null ||
        priorityNumber.phone.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Card(
        margin: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: RapidAidColors.primary
                  .withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: RapidAidColors.primary
                          .withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_in_talk_rounded,
                      color:
                          RapidAidColors.primary,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Priority Emergency Number',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight:
                                FontWeight.w800,
                            color: RapidAidColors
                                .textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This number is called first when you send an SOS.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: RapidAidColors
                                .textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_usingLocalPriority)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: RapidAidColors
                            .warning
                            .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 13,
                            color:
                                RapidAidColors.warning,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Offline',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight:
                                  FontWeight.w700,
                              color: RapidAidColors
                                  .warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      RapidAidColors.surfaceSoft,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 20,
                      color:
                          RapidAidColors.success,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        priorityNumber.phone,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.w800,
                          color: RapidAidColors
                              .textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _callPriorityNumber,
                      icon: const Icon(
                        Icons.call_rounded,
                        size: 18,
                      ),
                      label:
                          const Text('Call'),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            RapidAidColors
                                .success,
                        side:
                            const BorderSide(
                          color:
                              RapidAidColors
                                  .success,
                        ),
                        minimumSize:
                            const Size(0, 46),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          _smsPriorityNumber,
                      icon: const Icon(
                        Icons.sms_rounded,
                        size: 18,
                      ),
                      label:
                          const Text('SMS'),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            RapidAidColors
                                .primary,
                        foregroundColor:
                            Colors.white,
                        minimumSize:
                            const Size(0, 46),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the trusted contacts section heading.
  Widget _buildSectionHeader() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Trusted contacts',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: RapidAidColors.textPrimary,
              ),
            ),
          ),
          if (_usingLocalData)
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: RapidAidColors.warning
                    .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 14,
                    color: RapidAidColors.warning,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Offline',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color:
                          RapidAidColors.warning,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Builds an individual emergency contact card with Call and SMS actions.
  Widget _buildContactCard(
    EmergencyContact contact,
    int index,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor:
                      RapidAidColors.surfaceSoft,
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name[0]
                            .toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color:
                          RapidAidColors.primary,
                      fontWeight:
                          FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight:
                              FontWeight.w800,
                          color: RapidAidColors
                              .textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.relationship,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: RapidAidColors
                              .textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        contact.phone,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: RapidAidColors
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: RapidAidColors.success
                        .withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color:
                        RapidAidColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _callContact(contact),
                    icon: const Icon(
                      Icons.call_rounded,
                      size: 18,
                    ),
                    label: const Text('Call'),
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          RapidAidColors.success,
                      side: const BorderSide(
                        color:
                            RapidAidColors.success,
                      ),
                      minimumSize:
                          const Size(0, 46),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        _smsContact(contact),
                    icon: const Icon(
                      Icons.sms_rounded,
                      size: 18,
                    ),
                    label: const Text('SMS'),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          RapidAidColors.primary,
                      foregroundColor:
                          Colors.white,
                      minimumSize:
                          const Size(0, 46),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Builds the empty contact state.
  Widget _buildEmptyState() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 30, 20, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: RapidAidColors.surface,
          borderRadius:
              BorderRadius.circular(24),
          border: Border.all(
            color: RapidAidColors.border,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color:
                    RapidAidColors.surfaceSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 34,
                color: RapidAidColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No emergency contacts yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color:
                    RapidAidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add trusted people so they can be included in your SOS alerts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color:
                    RapidAidColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Builds the SOS and contact management actions.
  Widget _buildBottomActionArea() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _contacts.isEmpty
                  ? null
                  : widget.onOpenSOS,
              icon: const Icon(
                Icons.sos_rounded,
              ),
              label: const Text(
                'Send Emergency SOS',
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: widget.onOpenSettings,
            icon: const Icon(
              Icons.person_add_alt_1_rounded,
            ),
            label: const Text(
              'Manage emergency contacts',
            ),
          ),
        ],
      ),
    );
  }
}

class _RapidAidLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = math.min(
      size.width,
      size.height,
    ) /
        2;

    final path = Path();

    path.moveTo(
      center.dx - radius * 0.18,
      center.dy - radius * 0.88,
    );

    path.lineTo(
      center.dx + radius * 0.14,
      center.dy - radius * 0.88,
    );

    path.lineTo(
      center.dx + radius * 0.05,
      center.dy - radius * 0.22,
    );

    path.lineTo(
      center.dx + radius * 0.48,
      center.dy - radius * 0.22,
    );

    path.lineTo(
      center.dx - radius * 0.16,
      center.dy + radius * 0.88,
    );

    path.lineTo(
      center.dx - radius * 0.04,
      center.dy + radius * 0.20,
    );

    path.lineTo(
      center.dx - radius * 0.48,
      center.dy + radius * 0.20,
    );

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {
    return false;
  }
}