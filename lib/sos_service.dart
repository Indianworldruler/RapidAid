import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'communication_service.dart';
import 'firebase_service.dart';
import 'location_service.dart';
import 'models.dart';
import 'storage_service.dart';

class SOSService {
  SOSService._();

  static final SOSService instance = SOSService._();

  final FirebaseService _firebaseService =
      FirebaseService.instance;

  final StorageService _storageService =
      StorageService.instance;

  final CommunicationService _communicationService =
      CommunicationService.instance;

  final LocationService _locationService =
      LocationService.instance;

  // Sends the SOS by starting the priority call and SMS process together.
  Future<SOSAlert> sendSOS({
    required String situation,
    required List<EmergencyContact> contacts,
    String? priorityNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError(
        'You must be logged in to send an SOS alert.',
      );
    }

    final DateTime now = DateTime.now();

    SOSAlert alert = SOSAlert(
      id: now.microsecondsSinceEpoch.toString(),
      userId: user.uid,
      situation: situation.trim().isEmpty
          ? 'Emergency assistance requested'
          : situation.trim(),
      timestamp: now,
      contacts: List<EmergencyContact>.from(contacts),
      status: 'pending',
      callStatus: 'pending',
      smsStatus: const {},
    );

    await _storageService.saveSOSAlert(alert);

    try {
      String callStatus = 'not_attempted';

      Future<bool>? callFuture;

      if (priorityNumber != null &&
          priorityNumber.trim().isNotEmpty) {
        callFuture =
            _communicationService.makePriorityPhoneCall(
          priorityNumber,
        );
      }

      String? locationLink;

      try {
        locationLink =
            await _locationService.getCurrentLocationLink();
      } catch (_) {
        locationLink = null;
      }

      alert = alert.copyWith(
        locationLink: locationLink,
      );

      final List<String> smsNumbers =
          <String>[];

      if (priorityNumber != null &&
          priorityNumber.trim().isNotEmpty) {
        smsNumbers.add(
          _communicationService
              .formatPhoneNumber(priorityNumber),
        );
      }

      for (final EmergencyContact contact
          in contacts) {
        final String number =
            _communicationService
                .formatPhoneNumber(contact.phone);

        if (number.isNotEmpty &&
            !smsNumbers.contains(number)) {
          smsNumbers.add(number);
        }
      }

      Map<String, bool> smsStatus =
          <String, bool>{};

      if (smsNumbers.isNotEmpty) {
        try {
          smsStatus =
              await _communicationService
                  .sendEmergencySmsToNumbers(
            alert: alert,
            phoneNumbers: smsNumbers,
            locationLink: locationLink,
          );
        } catch (_) {
          for (final String number in smsNumbers) {
            smsStatus[number] = false;
          }
        }
      }

      if (callFuture != null) {
        try {
          final bool callSuccessful =
              await callFuture;

          callStatus =
              callSuccessful ? 'sent' : 'failed';
        } catch (_) {
          callStatus = 'failed';
        }
      }

      alert = alert.copyWith(
        callStatus: callStatus,
      );

      final bool allSmsSent =
          smsNumbers.isNotEmpty &&
              smsStatus.length ==
                  smsNumbers.length &&
              smsStatus.values.every(
                (sent) => sent,
              );

      final bool anySmsSent =
          smsStatus.values.any(
        (sent) => sent,
      );

      String finalStatus;

      if (smsNumbers.isEmpty) {
        finalStatus =
            callStatus == 'sent'
                ? 'sent'
                : callStatus == 'failed'
                    ? 'partial'
                    : 'failed';
      } else if (allSmsSent &&
          (callStatus == 'sent' ||
              callStatus == 'not_attempted')) {
        finalStatus = 'sent';
      } else if (anySmsSent ||
          callStatus == 'sent') {
        finalStatus = 'partial';
      } else {
        finalStatus = 'failed';
      }

      final SOSAlert completedAlert =
          alert.copyWith(
        status: finalStatus,
        locationLink: locationLink,
        callStatus: callStatus,
        smsStatus: smsStatus,
      );

      await _storageService.saveSOSAlert(
        completedAlert,
      );

      try {
        await _firebaseService.saveSOSAlert(
          alert: completedAlert,
        );
      } catch (_) {
        await _storageService.updateSOSStatus(
          alertId: completedAlert.id,
          status: 'failed',
        );

        rethrow;
      }

      return completedAlert;
    } catch (error) {
      await _storageService.updateSOSStatus(
        alertId: alert.id,
        status: 'failed',
      );

      rethrow;
    }
  }

  // Retries a previously failed or pending SOS alert.
  Future<SOSAlert> retrySOS(
    SOSAlert alert, {
    String? priorityNumber,
  }) async {
    final SOSAlert retryingAlert =
        alert.copyWith(
      status: 'pending',
    );

    await _storageService.updateSOSStatus(
      alertId: alert.id,
      status: 'pending',
    );

    try {
      String callStatus =
          retryingAlert.callStatus;

      Future<bool>? callFuture;

      if (priorityNumber != null &&
          priorityNumber.trim().isNotEmpty &&
          callStatus != 'sent') {
        callFuture =
            _communicationService.makePriorityPhoneCall(
          priorityNumber,
        );
      }

      String? locationLink =
          retryingAlert.locationLink;

      if (locationLink == null ||
          locationLink.isEmpty) {
        try {
          locationLink =
              await _locationService
                  .getCurrentLocationLink();
        } catch (_) {}
      }

      final List<String> smsNumbers =
          <String>[];

      if (priorityNumber != null &&
          priorityNumber.trim().isNotEmpty) {
        smsNumbers.add(
          _communicationService
              .formatPhoneNumber(priorityNumber),
        );
      }

      for (final EmergencyContact contact
          in retryingAlert.contacts) {
        final String number =
            _communicationService
                .formatPhoneNumber(contact.phone);

        if (number.isNotEmpty &&
            !smsNumbers.contains(number)) {
          smsNumbers.add(number);
        }
      }

      Map<String, bool> smsStatus =
          <String, bool>{};

      if (smsNumbers.isNotEmpty) {
        try {
          smsStatus =
              await _communicationService
                  .sendEmergencySmsToNumbers(
            alert: retryingAlert,
            phoneNumbers: smsNumbers,
            locationLink: locationLink,
          );
        } catch (_) {
          for (final String number in smsNumbers) {
            smsStatus[number] = false;
          }
        }
      }

      if (callFuture != null) {
        try {
          final bool callSuccessful =
              await callFuture;

          callStatus =
              callSuccessful ? 'sent' : 'failed';
        } catch (_) {
          callStatus = 'failed';
        }
      }

      final bool allSmsSent =
          smsNumbers.isNotEmpty &&
              smsStatus.length ==
                  smsNumbers.length &&
              smsStatus.values.every(
                (sent) => sent,
              );

      final bool anySmsSent =
          smsStatus.values.any(
        (sent) => sent,
      );

      String finalStatus;

      if (smsNumbers.isEmpty) {
        finalStatus =
            callStatus == 'sent'
                ? 'sent'
                : callStatus == 'failed'
                    ? 'partial'
                    : 'failed';
      } else if (allSmsSent &&
          (callStatus == 'sent' ||
              callStatus == 'not_attempted')) {
        finalStatus = 'sent';
      } else if (anySmsSent ||
          callStatus == 'sent') {
        finalStatus = 'partial';
      } else {
        finalStatus = 'failed';
      }

      final SOSAlert sentAlert =
          retryingAlert.copyWith(
        status: finalStatus,
        locationLink: locationLink,
        callStatus: callStatus,
        smsStatus: smsStatus,
      );

      await _storageService.saveSOSAlert(
        sentAlert,
      );

      await _firebaseService.saveSOSAlert(
        alert: sentAlert,
      );

      await _storageService.updateSOSStatus(
        alertId: alert.id,
        status: finalStatus,
      );

      return sentAlert;
    } catch (error) {
      await _storageService.updateSOSStatus(
        alertId: alert.id,
        status: 'failed',
      );

      rethrow;
    }
  }

  // Attempts to send all locally pending or failed SOS alerts.
  Future<List<SOSAlert>> retryPendingAlerts({
    String? userId,
    String? priorityNumber,
  }) async {
    final List<SOSAlert> pendingAlerts =
        await _storageService.getPendingSOSAlerts(
      userId: userId,
    );

    final List<SOSAlert> sentAlerts =
        <SOSAlert>[];

    for (final SOSAlert alert in pendingAlerts) {
      try {
        final SOSAlert sentAlert =
            await retrySOS(
          alert,
          priorityNumber: priorityNumber,
        );

        sentAlerts.add(sentAlert);
      } catch (_) {
        continue;
      }
    }

    return sentAlerts;
  }

  // Retrieves locally stored SOS history for offline access.
  Future<List<SOSAlert>> getLocalHistory({
    String? userId,
  }) async {
    return _storageService.getSOSAlerts(
      userId: userId,
    );
  }
}