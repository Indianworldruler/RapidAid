import 'package:firebase_database/firebase_database.dart';

import 'models.dart';

class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance =
      FirebaseService._();

  final FirebaseDatabase _database =
      FirebaseDatabase.instance;

  // Saves an emergency contact to Firebase Realtime Database.
  Future<void> saveContact({
    required String userId,
    required EmergencyContact contact,
  }) async {
    final reference = _database.ref(
      'users/$userId/contacts/${contact.id}',
    );

    await reference.set(contact.toMap());
  }

  // Updates an existing emergency contact in Firebase Realtime Database.
  Future<void> updateContact({
    required String userId,
    required EmergencyContact contact,
  }) async {
    final reference = _database.ref(
      'users/$userId/contacts/${contact.id}',
    );

    await reference.update(contact.toMap());
  }

  // Deletes an emergency contact from Firebase Realtime Database.
  Future<void> deleteContact({
    required String userId,
    required String contactId,
  }) async {
    final reference = _database.ref(
      'users/$userId/contacts/$contactId',
    );

    await reference.remove();
  }

  // Retrieves all emergency contacts belonging to the authenticated user.
  Future<List<EmergencyContact>> getContacts({
    required String userId,
  }) async {
    final reference = _database.ref(
      'users/$userId/contacts',
    );

    final snapshot = await reference.get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final data = Map<dynamic, dynamic>.from(
      snapshot.value as Map,
    );

    return data.values.map((value) {
      return EmergencyContact.fromMap(
        Map<String, dynamic>.from(value as Map),
      );
    }).toList();
  }

  // Saves or replaces the user's priority emergency number.
  Future<void> savePriorityNumber({
    required PriorityNumber priorityNumber,
  }) async {
    final reference = _database.ref(
      'users/${priorityNumber.userId}/priority_number',
    );

    await reference.set({
      'userId': priorityNumber.userId,
      'phone': priorityNumber.phone,
    });
  }

  // Retrieves the user's priority emergency number.
  Future<PriorityNumber?> getPriorityNumber({
    required String userId,
  }) async {
    final reference = _database.ref(
      'users/$userId/priority_number',
    );

    final snapshot = await reference.get();

    if (!snapshot.exists || snapshot.value == null) {
      return null;
    }

    final value = snapshot.value;

    if (value is Map) {
      return PriorityNumber.fromMap(
        Map<String, dynamic>.from(value),
      );
    }

    if (value is String) {
      return PriorityNumber(
        userId: userId,
        phone: value,
      );
    }

    return null;
  }

  // Updates the user's existing priority emergency number.
  Future<void> updatePriorityNumber({
    required PriorityNumber priorityNumber,
  }) async {
    final reference = _database.ref(
      'users/${priorityNumber.userId}/priority_number',
    );

    await reference.update({
      'phone': priorityNumber.phone,
    });
  }

  // Deletes the user's priority emergency number.
  Future<void> deletePriorityNumber({
    required String userId,
  }) async {
    final reference = _database.ref(
      'users/$userId/priority_number',
    );

    await reference.remove();
  }

  // Saves an SOS alert with its location and communication results.
  Future<void> saveSOSAlert({
    required SOSAlert alert,
  }) async {
    final reference = _database.ref(
      'users/${alert.userId}/sos_alerts/${alert.id}',
    );

    await reference.set(
      alert.toMap(),
    );
  }

  // Retrieves the authenticated user's SOS history.
  Future<List<SOSAlert>> getSOSHistory({
    required String userId,
  }) async {
    final reference = _database.ref(
      'users/$userId/sos_alerts',
    );

    final snapshot = await reference.get();

    if (!snapshot.exists || snapshot.value == null) {
      return [];
    }

    final data = Map<dynamic, dynamic>.from(
      snapshot.value as Map,
    );

    final alerts = data.values.map((value) {
      return SOSAlert.fromMap(
        Map<String, dynamic>.from(value as Map),
      );
    }).toList();

    alerts.sort(
      (a, b) => b.timestamp.compareTo(
        a.timestamp,
      ),
    );

    return alerts;
  }
}