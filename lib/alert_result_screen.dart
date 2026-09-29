import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'communication_service.dart';
import 'models.dart';
import 'sos_service.dart';

class AlertResultScreen extends StatefulWidget {
  final SOSAlert alert;
  final bool isFailure;
  final VoidCallback onDone;
  final VoidCallback onBack;

  const AlertResultScreen({
    super.key,
    required this.alert,
    required this.isFailure,
    required this.onDone,
    required this.onBack,
  });

  @override
  State<AlertResultScreen> createState() => _AlertResultScreenState();
}

class _AlertResultScreenState extends State<AlertResultScreen> {
  final CommunicationService _communicationService =
      CommunicationService.instance;

  late SOSAlert _alert;
  late bool _isFailure;

  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();

    _alert = widget.alert;
    _isFailure = widget.isFailure;
  }

  // Retries a failed SOS alert.
  Future<void> _retrySOS() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    try {
      final updatedAlert =
          await SOSService.instance.retrySOS(_alert);

      if (!mounted) return;

      setState(() {
        _alert = updatedAlert;
        _isFailure = false;
        _isRetrying = false;
      });

      _showMessage(
        'SOS alert sent successfully.',
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isRetrying = false;
        _isFailure = true;
      });

      _showMessage(
        'SOS could not be sent. Please try again.',
        isError: true,
      );
    }
  }

  // Opens the phone dialler for one emergency contact.
  Future<void> _callContact(
    EmergencyContact contact,
  ) async {
    if (_isRetrying) return;

    try {
      await _communicationService.makePhoneCall(
        contact.phone,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to open the phone dialler.',
        isError: true,
      );
    }
  }

  // Opens the SMS composer for one emergency contact.
  Future<void> _smsContact(
    EmergencyContact contact,
  ) async {
    if (_isRetrying) return;

    try {
      final message =
          _communicationService.buildSOSMessage(_alert);

      await _communicationService.sendSms(
        contact.phone,
        message,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to open the SMS application.',
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

  // Builds the status header.
  Widget _buildStatusHeader() {
    final bool success = !_isFailure;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: success
            ? RapidAidColors.success.withValues(alpha: 0.10)
            : RapidAidColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: success
              ? RapidAidColors.success.withValues(alpha: 0.25)
              : RapidAidColors.error.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: success
                  ? RapidAidColors.success
                  : RapidAidColors.error,
              shape: BoxShape.circle,
            ),
            child: Icon(
              success
                  ? Icons.check_rounded
                  : Icons.priority_high_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            success
                ? 'SOS Alert Recorded'
                : 'SOS Alert Failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: success
                  ? RapidAidColors.success
                  : RapidAidColors.error,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            success
                ? 'Your emergency alert has been saved successfully.'
                : 'The alert could not reach the cloud. '
                    'You can retry it.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: RapidAidColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Builds the SOS details card.
  Widget _buildAlertDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alert details',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: RapidAidColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _buildDetailRow(
              Icons.warning_amber_rounded,
              'Situation',
              _alert.situation,
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.access_time_rounded,
              'Time',
              _formatDateTime(_alert.timestamp),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.cloud_done_rounded,
              'Status',
              _alert.status.toUpperCase(),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Icons.people_alt_outlined,
              'Contacts',
              '${_alert.contacts.length}',
            ),
          ],
        ),
      ),
    );
  }

  // Builds one alert detail row.
  Widget _buildDetailRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 21,
          color: RapidAidColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: RapidAidColors.textLight,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: RapidAidColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Builds the emergency contact communication section.
  Widget _buildContactsSection() {
    if (_alert.contacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency contacts',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: RapidAidColors.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Contact an individual person when needed.',
          style: TextStyle(
            fontSize: 12.5,
            color: RapidAidColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        ..._alert.contacts.map(_buildContactCard),
      ],
    );
  }

  // Builds one emergency contact with individual call and SMS actions.
  Widget _buildContactCard(EmergencyContact contact) {
    final bool disabled = _isRetrying;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: RapidAidColors.surfaceSoft,
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: RapidAidColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: RapidAidColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        contact.relationship,
                        style: const TextStyle(
                          fontSize: 12,
                          color: RapidAidColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        contact.phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: RapidAidColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: disabled
                        ? null
                        : () => _callContact(contact),
                    icon: const Icon(
                      Icons.phone_rounded,
                      size: 19,
                    ),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: disabled
                        ? null
                        : () => _smsContact(contact),
                    icon: const Icon(
                      Icons.sms_rounded,
                      size: 19,
                    ),
                    label: const Text('SMS'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Formats the alert timestamp.
  String _formatDateTime(DateTime dateTime) {
    final String day =
        dateTime.day.toString().padLeft(2, '0');

    final String month =
        dateTime.month.toString().padLeft(2, '0');

    final String year =
        dateTime.year.toString();

    final int hour = dateTime.hour % 12 == 0
        ? 12
        : dateTime.hour % 12;

    final String minute =
        dateTime.minute.toString().padLeft(2, '0');

    final String period =
        dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year $hour:$minute $period';
  }

  // Builds the alert result screen.
  @override
  Widget build(BuildContext context) {
    final bool actionsDisabled = _isRetrying;

    return Scaffold(
      backgroundColor: RapidAidColors.background,
      appBar: AppBar(
        leading: IconButton(
          onPressed:
              actionsDisabled ? null : widget.onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'SOS Result',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildStatusHeader(),
              const SizedBox(height: 18),
              _buildAlertDetails(),
              const SizedBox(height: 22),
              _buildContactsSection(),
              const SizedBox(height: 20),
              if (_isFailure)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isRetrying ? null : _retrySOS,
                    icon: _isRetrying
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.refresh_rounded,
                          ),
                    label: Text(
                      _isRetrying
                          ? 'Retrying...'
                          : 'Retry SOS',
                    ),
                  ),
                ),
              if (_isFailure)
                const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed:
                      actionsDisabled ? null : widget.onDone,
                  child: const Text(
                    'Done',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}