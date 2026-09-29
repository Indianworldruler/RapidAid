import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  static const String _databaseName = 'rapidaid.db';
  static const int _databaseVersion = 4;

  Database? _database;

  // Opens the local RapidAid database and creates or upgrades its tables.
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE emergency_contacts (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            name TEXT NOT NULL,
            relationship TEXT NOT NULL,
            phone TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE sos_alerts (
            id TEXT PRIMARY KEY,
            user_id TEXT NOT NULL,
            situation TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            contacts TEXT NOT NULL,
            status TEXT NOT NULL,
            location_link TEXT,
            latitude REAL,
            longitude REAL,
            call_status TEXT NOT NULL DEFAULT 'pending',
            sms_status TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE priority_numbers (
            user_id TEXT PRIMARY KEY,
            phone TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE emergency_contacts
            ADD COLUMN user_id TEXT NOT NULL DEFAULT ''
          ''');
        }

        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE priority_numbers (
              user_id TEXT PRIMARY KEY,
              phone TEXT NOT NULL
            )
          ''');
        }

        if (oldVersion < 4) {
          await db.execute('''
            ALTER TABLE sos_alerts
            ADD COLUMN location_link TEXT
          ''');

          await db.execute('''
            ALTER TABLE sos_alerts
            ADD COLUMN latitude REAL
          ''');

          await db.execute('''
            ALTER TABLE sos_alerts
            ADD COLUMN longitude REAL
          ''');

          await db.execute('''
            ALTER TABLE sos_alerts
            ADD COLUMN call_status TEXT NOT NULL DEFAULT 'pending'
          ''');

          await db.execute('''
            ALTER TABLE sos_alerts
            ADD COLUMN sms_status TEXT
          ''');
        }
      },
    );

    return _database!;
  }

  // Saves or replaces an emergency contact for the specified user.
  Future<void> saveContact({
    required String userId,
    required EmergencyContact contact,
  }) async {
    final db = await database;

    await db.insert(
      'emergency_contacts',
      {
        'id': contact.id,
        'user_id': userId,
        'name': contact.name,
        'relationship': contact.relationship,
        'phone': contact.phone,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Updates an existing emergency contact for the specified user.
  Future<void> updateContact({
    required String userId,
    required EmergencyContact contact,
  }) async {
    final db = await database;

    await db.update(
      'emergency_contacts',
      {
        'name': contact.name,
        'relationship': contact.relationship,
        'phone': contact.phone,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        contact.id,
        userId,
      ],
    );
  }

  // Deletes an emergency contact only from the specified user's local storage.
  Future<void> deleteContact({
    required String userId,
    required String contactId,
  }) async {
    final db = await database;

    await db.delete(
      'emergency_contacts',
      where: 'id = ? AND user_id = ?',
      whereArgs: [
        contactId,
        userId,
      ],
    );
  }

  // Retrieves only the locally saved contacts belonging to the specified user.
  Future<List<EmergencyContact>> getContacts({
    required String userId,
  }) async {
    final db = await database;

    final rows = await db.query(
      'emergency_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows.map(EmergencyContact.fromMap).toList();
  }

  // Removes all locally stored contacts belonging to the specified user.
  Future<void> clearContacts({
    required String userId,
  }) async {
    final db = await database;

    await db.delete(
      'emergency_contacts',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // Saves or replaces the priority emergency number for a user.
  Future<void> savePriorityNumber(
    PriorityNumber priorityNumber,
  ) async {
    final db = await database;

    await db.insert(
      'priority_numbers',
      {
        'user_id': priorityNumber.userId,
        'phone': priorityNumber.phone,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieves the locally stored priority number for a user.
  Future<PriorityNumber?> getPriorityNumber({
    required String userId,
  }) async {
    final db = await database;

    final rows = await db.query(
      'priority_numbers',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return PriorityNumber.fromMap(rows.first);
  }

  // Updates the priority emergency number for a user.
  Future<void> updatePriorityNumber(
    PriorityNumber priorityNumber,
  ) async {
    final db = await database;

    await db.update(
      'priority_numbers',
      {
        'phone': priorityNumber.phone,
      },
      where: 'user_id = ?',
      whereArgs: [priorityNumber.userId],
    );
  }

  // Deletes the priority emergency number for a user.
  Future<void> deletePriorityNumber({
    required String userId,
  }) async {
    final db = await database;

    await db.delete(
      'priority_numbers',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // Saves an SOS alert locally for history or later retry.
  Future<void> saveSOSAlert(SOSAlert alert) async {
    final db = await database;

    await db.insert(
      'sos_alerts',
      {
        'id': alert.id,
        'user_id': alert.userId,
        'situation': alert.situation,
        'timestamp': alert.timestamp.toIso8601String(),
        'contacts': jsonEncode(
          alert.contacts
              .map((contact) => contact.toMap())
              .toList(),
        ),
        'status': alert.status,
        'location_link': alert.locationLink,
        'latitude': alert.latitude,
        'longitude': alert.longitude,
        'call_status': alert.callStatus,
        'sms_status': jsonEncode(alert.smsStatus),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Retrieves locally stored SOS alerts for offline history and retry handling.
  Future<List<SOSAlert>> getSOSAlerts({
    String? userId,
  }) async {
    final db = await database;

    final rows = await db.query(
      'sos_alerts',
      where: userId == null ? null : 'user_id = ?',
      whereArgs: userId == null ? null : [userId],
      orderBy: 'timestamp DESC',
    );

    return rows.map(_alertFromDatabaseRow).toList();
  }

  // Retrieves only SOS alerts that still need to be sent to Firebase.
  Future<List<SOSAlert>> getPendingSOSAlerts({
    String? userId,
  }) async {
    final db = await database;

    final conditions = <String>[
      'status IN (?, ?)',
    ];

    final arguments = <Object>[
      'pending',
      'failed',
    ];

    if (userId != null) {
      conditions.add('user_id = ?');
      arguments.add(userId);
    }

    final rows = await db.query(
      'sos_alerts',
      where: conditions.join(' AND '),
      whereArgs: arguments,
      orderBy: 'timestamp ASC',
    );

    return rows.map(_alertFromDatabaseRow).toList();
  }

  // Updates the local status of an SOS alert after a send attempt.
  Future<void> updateSOSStatus({
    required String alertId,
    required String status,
  }) async {
    final db = await database;

    await db.update(
      'sos_alerts',
      {
        'status': status,
      },
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  // Deletes a locally stored SOS alert after it is no longer needed.
  Future<void> deleteSOSAlert(String alertId) async {
    final db = await database;

    await db.delete(
      'sos_alerts',
      where: 'id = ?',
      whereArgs: [alertId],
    );
  }

  // Converts a SQLite SOS record back into the application model.
  SOSAlert _alertFromDatabaseRow(
    Map<String, dynamic> row,
  ) {
    final decodedContacts = jsonDecode(
      row['contacts']?.toString() ?? '[]',
    );

    final contacts = <EmergencyContact>[];

    if (decodedContacts is List) {
      for (final contact in decodedContacts) {
        if (contact is Map) {
          contacts.add(
            EmergencyContact.fromMap(
              Map<String, dynamic>.from(contact),
            ),
          );
        }
      }
    }

    final decodedSmsStatus = jsonDecode(
      row['sms_status']?.toString() ?? '{}',
    );

    final smsStatus = <String, bool>{};

    if (decodedSmsStatus is Map) {
      decodedSmsStatus.forEach((key, value) {
        if (value is bool) {
          smsStatus[key.toString()] = value;
        } else {
          smsStatus[key.toString()] =
              value.toString().toLowerCase() == 'true';
        }
      });
    }

    return SOSAlert(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      situation: row['situation']?.toString() ?? '',
      timestamp: DateTime.tryParse(
            row['timestamp']?.toString() ?? '',
          ) ??
          DateTime.now(),
      contacts: contacts,
      status: row['status']?.toString() ?? 'pending',
      locationLink: row['location_link']?.toString(),
      latitude: _toDouble(row['latitude']),
      longitude: _toDouble(row['longitude']),
      callStatus:
          row['call_status']?.toString() ?? 'pending',
      smsStatus: smsStatus,
    );
  }

  // Converts a database value into a nullable double.
  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }

  // Closes the local database when it is no longer needed.
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}