import 'dart:io';

import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:send_message/send_message.dart' as sms;
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';

class CommunicationService {
  CommunicationService._();

  static final CommunicationService instance =
      CommunicationService._();

  // Cleans and formats a phone number for phone and SMS actions.
  String formatPhoneNumber(String phoneNumber) {
    String number = phoneNumber.trim();

    number = number.replaceAll(
      RegExp(r'[\s\-\(\)\.]'),
      '',
    );

    if (number.startsWith('00')) {
      number = '+${number.substring(2)}';
    }

    if (number.startsWith('+')) {
      return number;
    }

    if (number.length == 10) {
      return '+91$number';
    }

    return '+$number';
  }

  // Creates the emergency message with the current location link.
  String buildSOSMessage(
    SOSAlert alert, {
    String? locationLink,
  }) {
    final String formattedTime =
        _formatDateTime(alert.timestamp);

    final String locationSection =
        locationLink == null ||
                locationLink.isEmpty
            ? ''
            : '''

Current location:
$locationLink''';

    return '''RAPIDAID EMERGENCY ALERT

I need emergency assistance.

Situation:
${alert.situation}

Time:
$formattedTime$locationSection

Please contact me as soon as possible.''';
  }

  // Formats the SOS timestamp for the emergency message.
  String _formatDateTime(DateTime dateTime) {
    final String day =
        dateTime.day.toString().padLeft(2, '0');

    final String month =
        dateTime.month.toString().padLeft(2, '0');

    final String year =
        dateTime.year.toString();

    final int hour =
        dateTime.hour % 12 == 0
            ? 12
            : dateTime.hour % 12;

    final String minute =
        dateTime.minute.toString().padLeft(2, '0');

    final String period =
        dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$day/$month/$year '
        '$hour:$minute $period';
  }

  // Attempts to make a direct phone call and falls back to the dialler.
  Future<bool> makeDirectPhoneCall(
    String phoneNumber,
  ) async {
    final String formattedNumber =
        formatPhoneNumber(phoneNumber);

    if (Platform.isAndroid) {
      try {
        final bool? directCallResult =
            await FlutterPhoneDirectCaller.callNumber(
          formattedNumber,
        );

        if (directCallResult == true) {
          return true;
        }
      } catch (_) {}
    }

    try {
      await makePhoneCall(formattedNumber);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Keeps compatibility with existing SOS and priority-number code.
  Future<bool> makePriorityPhoneCall(
    String phoneNumber,
  ) async {
    return makeDirectPhoneCall(phoneNumber);
  }

  // Opens the phone dialler with the selected phone number.
  Future<void> makePhoneCall(
    String phoneNumber,
  ) async {
    final String formattedNumber =
        formatPhoneNumber(phoneNumber);

    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: formattedNumber,
    );

    if (!await canLaunchUrl(phoneUri)) {
      throw Exception(
        'Unable to open the phone dialler.',
      );
    }

    await launchUrl(
      phoneUri,
      mode: LaunchMode.externalApplication,
    );
  }

  // Opens the SMS composer with a pre-filled emergency message.
  Future<void> sendSms(
    String phoneNumber,
    String message,
  ) async {
    final String formattedNumber =
        formatPhoneNumber(phoneNumber);

    final Uri smsUri = Uri(
      scheme: 'sms',
      path: formattedNumber,
      queryParameters: {
        'body': message,
      },
    );

    if (!await canLaunchUrl(smsUri)) {
      throw Exception(
        'Unable to open the SMS application.',
      );
    }

    await launchUrl(
      smsUri,
      mode: LaunchMode.externalApplication,
    );
  }

  // Gets the current device location and creates a Google Maps link.
  Future<String> getCurrentLocationLink() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled.',
      );
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
        LocationPermission.denied) {
      throw Exception(
        'Location permission was denied.',
      );
    }

    if (permission ==
        LocationPermission.deniedForever) {
      throw Exception(
        'Location permission was permanently denied.',
      );
    }

    final Position position =
        await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    return 'https://www.google.com/maps?q='
        '${position.latitude},'
        '${position.longitude}';
  }

  // Requests the Android permission required for direct SMS sending.
  Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    final PermissionStatus status =
        await Permission.sms.status;

    if (status.isGranted) {
      return true;
    }

    final PermissionStatus requested =
        await Permission.sms.request();

    return requested.isGranted;
  }

  // Checks whether the Android device can send SMS messages.
  Future<bool> canSendSMS() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final bool permissionGranted =
          await requestSmsPermission();

      if (!permissionGranted) {
        return false;
      }

      return await sms.canSendSMS();
    } catch (_) {
      return false;
    }
  }

  // Sends the same emergency SMS to every supplied phone number.
  Future<Map<String, bool>>
      sendEmergencySmsToNumbers({
    required SOSAlert alert,
    required List<String> phoneNumbers,
    String? locationLink,
  }) async {
    final Map<String, bool> results =
        <String, bool>{};

    if (phoneNumbers.isEmpty) {
      return results;
    }

    final String currentLocation =
        locationLink ??
        await getCurrentLocationLink();

    final String message =
        buildSOSMessage(
      alert,
      locationLink: currentLocation,
    );

    if (Platform.isAndroid) {
      final bool permissionGranted =
          await requestSmsPermission();

      if (!permissionGranted) {
        for (final String phoneNumber
            in phoneNumbers) {
          results[phoneNumber] = false;
        }

        return results;
      }

      final bool smsAvailable =
          await sms.canSendSMS();

      if (!smsAvailable) {
        for (final String phoneNumber
            in phoneNumbers) {
          results[phoneNumber] = false;
        }

        return results;
      }
    }

    for (final String originalNumber
        in phoneNumbers) {
      final String phoneNumber =
          formatPhoneNumber(originalNumber);

      if (phoneNumber.isEmpty) {
        results[originalNumber] = false;
        continue;
      }

      try {
        final String result =
            await sms.sendSMS(
          message: message,
          recipients: <String>[
            phoneNumber,
          ],
          sendDirect: Platform.isAndroid,
        );

        results[originalNumber] =
            result.isNotEmpty;
      } catch (_) {
        results[originalNumber] = false;
      }
    }

    return results;
  }

  // Automatically sends the same emergency SMS to every saved contact.
  Future<Map<String, bool>>
      sendEmergencySmsToContacts({
    required SOSAlert alert,
    required List<EmergencyContact> contacts,
    String? locationLink,
  }) async {
    final Map<String, bool> results =
        <String, bool>{};

    if (contacts.isEmpty) {
      return results;
    }

    final List<String> phoneNumbers =
        <String>[];

    for (final EmergencyContact contact
        in contacts) {
      final String phoneNumber =
          formatPhoneNumber(contact.phone);

      if (phoneNumber.isNotEmpty &&
          !phoneNumbers.contains(phoneNumber)) {
        phoneNumbers.add(phoneNumber);
      }
    }

    final Map<String, bool> numberResults =
        await sendEmergencySmsToNumbers(
      alert: alert,
      phoneNumbers: phoneNumbers,
      locationLink: locationLink,
    );

    for (final EmergencyContact contact
        in contacts) {
      final String phoneNumber =
          formatPhoneNumber(contact.phone);

      results[contact.id] =
          numberResults[phoneNumber] ?? false;
    }

    return results;
  }
}