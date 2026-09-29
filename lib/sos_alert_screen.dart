import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'firebase_service.dart';
import 'models.dart';
import 'sos_service.dart';
import 'storage_service.dart';

class SOSAlertScreen extends StatefulWidget {
  final List<EmergencyContact> contacts;
  final Function(SOSAlert alert) onSuccess;
  final Function(SOSAlert alert, Object error) onFailure;
  final VoidCallback onBack;

  const SOSAlertScreen({
    super.key,
    required this.contacts,
    required this.onSuccess,
    required this.onFailure,
    required this.onBack,
  });

  @override
  State<SOSAlertScreen> createState() =>
      _SOSAlertScreenState();
}

class _SOSAlertScreenState extends State<SOSAlertScreen> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _situationController =
      TextEditingController();

  final StorageService _storageService =
      StorageService.instance;

  final FirebaseService _firebaseService =
      FirebaseService.instance;

  PriorityNumber? _priorityNumber;

  bool _isLoadingPriorityNumber = true;
  bool _usingLocalPriority = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadPriorityNumber();
  }

  @override
  void dispose() {
    _situationController.dispose();
    super.dispose();
  }

  // Loads the user's priority number from local storage and Firebase.
  Future<void> _loadPriorityNumber() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _priorityNumber = null;
        _usingLocalPriority = false;
        _isLoadingPriorityNumber = false;
      });

      return;
    }

    try {
      final localPriorityNumber =
          await _storageService.getPriorityNumber(
        userId: user.uid,
      );

      if (mounted) {
        setState(() {
          _priorityNumber = localPriorityNumber;
          _usingLocalPriority =
              localPriorityNumber != null;
          _isLoadingPriorityNumber = false;
        });
      }

      try {
        final cloudPriorityNumber =
            await _firebaseService.getPriorityNumber(
          userId: user.uid,
        );

        if (cloudPriorityNumber != null) {
          await _storageService.savePriorityNumber(
            cloudPriorityNumber,
          );
        }

        if (!mounted) return;

        setState(() {
          _priorityNumber =
              cloudPriorityNumber ?? localPriorityNumber;

          _usingLocalPriority =
              cloudPriorityNumber == null &&
              localPriorityNumber != null;
        });
      } catch (_) {
        if (!mounted) return;

        setState(() {
          _priorityNumber = localPriorityNumber;
          _usingLocalPriority =
              localPriorityNumber != null;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _priorityNumber = null;
        _usingLocalPriority = false;
        _isLoadingPriorityNumber = false;
      });
    }
  }

  // Returns the entered situation or the default emergency message.
  String _getSituationText() {
    final String text =
        _situationController.text.trim();

    if (text.isEmpty) {
      return 'Emergency assistance requested';
    }

    return text;
  }

  // Starts the complete emergency response through the SOS service.
  Future<void> _sendSOS() async {
    if (_isSending) return;

    final PriorityNumber? priorityNumber =
        _priorityNumber;

    if (priorityNumber == null ||
        priorityNumber.phone.trim().isEmpty) {
      _showMessage(
        'Priority emergency number is not configured.',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSending = true;
    });

    try {
      final String situation =
          _getSituationText();

      final SOSAlert alert =
          await SOSService.instance.sendSOS(
        situation: situation,
        contacts: widget.contacts,
        priorityNumber: priorityNumber.phone,
      );

      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      widget.onSuccess(alert);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
      });

      try {
        final history =
            await SOSService.instance.getLocalHistory();

        SOSAlert? failedAlert;

        for (final historyAlert in history) {
          if (historyAlert.status == 'failed' ||
              historyAlert.status == 'partial') {
            failedAlert = historyAlert;
            break;
          }
        }

        if (failedAlert != null) {
          widget.onFailure(
            failedAlert,
            error,
          );
          return;
        }
      } catch (_) {}

      _showMessage(
        'SOS could not be completed. Please try again.',
        isError: true,
      );
    }
  }

  // Shows a short status message.
  void _showMessage(
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? RapidAidColors.error
            : RapidAidColors.success,
      ),
    );
  }

  // Builds the priority number information card.
  Widget _buildPriorityNumberInfo() {
    if (_isLoadingPriorityNumber) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: RapidAidColors.surface,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: RapidAidColors.border,
          ),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading priority number...',
                style: TextStyle(
                  fontSize: 12.5,
                  color:
                      RapidAidColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool hasNumber =
        _priorityNumber != null &&
        _priorityNumber!.phone.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: hasNumber
            ? RapidAidColors.success.withValues(
                alpha: 0.08,
              )
            : RapidAidColors.error.withValues(
                alpha: 0.08,
              ),
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: hasNumber
              ? RapidAidColors.success.withValues(
                  alpha: 0.25,
                )
              : RapidAidColors.error.withValues(
                  alpha: 0.25,
                ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: hasNumber
                  ? RapidAidColors.success
                  : RapidAidColors.error,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasNumber
                  ? Icons.phone_in_talk_rounded
                  : Icons.phone_disabled_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  hasNumber
                      ? 'Priority call number'
                      : 'Priority number required',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        RapidAidColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasNumber
                      ? _priorityNumber!.phone
                      : 'Add a number in Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: hasNumber
                        ? RapidAidColors.textPrimary
                        : RapidAidColors.error,
                  ),
                ),
                if (_usingLocalPriority &&
                    hasNumber) ...[
                  const SizedBox(height: 3),
                  const Text(
                    'Available offline',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          RapidAidColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Builds the optional situation input field.
  Widget _buildSituationField() {
    return TextFormField(
      controller: _situationController,
      maxLines: 4,
      maxLength: 500,
      textInputAction:
          TextInputAction.newline,
      enabled: !_isSending,
      decoration: const InputDecoration(
        labelText: 'What is happening? (Optional)',
        hintText:
            'Briefly describe your emergency if you want to...',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding:
              EdgeInsets.only(bottom: 58),
          child: Icon(
            Icons.warning_amber_rounded,
          ),
        ),
      ),
      validator: (value) {
        return null;
      },
    );
  }

  // Builds the large emergency SOS button.
  Widget _buildSOSButton() {
    final bool hasPriorityNumber =
        _priorityNumber != null &&
        _priorityNumber!.phone.trim().isNotEmpty;

    final bool disabled =
        _isSending ||
        _isLoadingPriorityNumber ||
        !hasPriorityNumber;

    return Column(
      children: [
        Text(
          _isSending
              ? 'Starting your emergency response...'
              : hasPriorityNumber
                  ? 'Tap SOS only when you need emergency assistance'
                  : 'Add a priority number before using SOS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: _isSending
                ? RapidAidColors.primary
                : hasPriorityNumber
                    ? RapidAidColors.textSecondary
                    : RapidAidColors.error,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: disabled ? null : _sendSOS,
          child: AnimatedScale(
            scale: _isSending ? 0.96 : 1.0,
            duration:
                const Duration(milliseconds: 180),
            child: AnimatedContainer(
              duration:
                  const Duration(milliseconds: 200),
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: disabled && !_isSending
                    ? RapidAidColors.textLight
                    : _isSending
                        ? RapidAidColors.primaryDark
                        : RapidAidColors.primary,
                boxShadow: [
                  if (!disabled)
                    BoxShadow(
                      color: RapidAidColors.primary
                          .withValues(
                        alpha: _isSending
                            ? 0.18
                            : 0.28,
                      ),
                      blurRadius:
                          _isSending ? 18 : 26,
                      spreadRadius:
                          _isSending ? 3 : 6,
                    ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 174,
                  height: 174,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white
                          .withValues(alpha: 0.35),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: _isSending
                        ? const Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              SizedBox(
                                width: 38,
                                height: 38,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color:
                                      Colors.white,
                                ),
                              ),
                              SizedBox(height: 13),
                              Text(
                                'SENDING...',
                                style: TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w900,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,
                            children: [
                              const Icon(
                                Icons.sos_rounded,
                                color: Colors.white,
                                size: 55,
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'SOS',
                                style: TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 29,
                                  fontWeight:
                                      FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              if (hasPriorityNumber) ...[
                                const SizedBox(height: 7),
                                Text(
                                  _priorityNumber!
                                      .phone,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors.white70,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              _isSending
                  ? Icons.sync_rounded
                  : Icons.phone_in_talk_rounded,
              size: 17,
              color: _isSending
                  ? RapidAidColors.primary
                  : RapidAidColors.success,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _isSending
                    ? 'Calling, getting your location and sending emergency messages'
                    : hasPriorityNumber
                        ? 'Priority call first • ${widget.contacts.length} contact${widget.contacts.length == 1 ? '' : 's'} will receive your SOS'
                        : 'Priority call number not configured',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: hasPriorityNumber
                      ? RapidAidColors.textSecondary
                      : RapidAidColors.error,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Builds the emergency contact information.
  Widget _buildContactInfo() {
    final bool hasContacts =
        widget.contacts.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: RapidAidColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasContacts
                ? Icons.people_alt_outlined
                : Icons.info_outline_rounded,
            color: hasContacts
                ? RapidAidColors.primary
                : RapidAidColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasContacts
                  ? '${widget.contacts.length} emergency '
                      '${widget.contacts.length == 1 ? 'contact' : 'contacts'} '
                      'will receive the same automatic SMS with your current location.'
                  : 'No additional emergency contacts are configured. '
                      'Your priority number will still be called and the SOS will be recorded.',
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color:
                    RapidAidColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds the SOS emergency screen.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RapidAidColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed:
              _isSending ? null : widget.onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'Emergency SOS',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              30,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildPriorityNumberInfo(),
                const SizedBox(height: 18),
                _buildSituationField(),
                const SizedBox(height: 28),
                _buildSOSButton(),
                const SizedBox(height: 28),
                _buildContactInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}