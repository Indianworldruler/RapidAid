class EmergencyContact {
  final String id;
  final String name;
  final String relationship;
  final String phone;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'relationship': relationship,
      'phone': phone,
    };
  }

  factory EmergencyContact.fromMap(Map<String, dynamic> map) {
    return EmergencyContact(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      relationship: map['relationship']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? relationship,
    String? phone,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      relationship: relationship ?? this.relationship,
      phone: phone ?? this.phone,
    );
  }
}

class PriorityNumber {
  final String userId;
  final String phone;

  const PriorityNumber({
    required this.userId,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'phone': phone,
    };
  }

  factory PriorityNumber.fromMap(Map<String, dynamic> map) {
    return PriorityNumber(
      userId: map['userId']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }

  PriorityNumber copyWith({
    String? userId,
    String? phone,
  }) {
    return PriorityNumber(
      userId: userId ?? this.userId,
      phone: phone ?? this.phone,
    );
  }
}

class SOSAlert {
  final String id;
  final String userId;
  final String situation;
  final DateTime timestamp;
  final List<EmergencyContact> contacts;
  final String status;
  final String? locationLink;
  final double? latitude;
  final double? longitude;
  final String callStatus;
  final Map<String, bool> smsStatus;

  const SOSAlert({
    required this.id,
    required this.userId,
    required this.situation,
    required this.timestamp,
    required this.contacts,
    required this.status,
    this.locationLink,
    this.latitude,
    this.longitude,
    this.callStatus = 'pending',
    this.smsStatus = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'situation': situation,
      'timestamp': timestamp.toIso8601String(),
      'contacts': contacts
          .map((contact) => contact.toMap())
          .toList(),
      'status': status,
      'locationLink': locationLink,
      'latitude': latitude,
      'longitude': longitude,
      'callStatus': callStatus,
      'smsStatus': smsStatus,
    };
  }

  factory SOSAlert.fromMap(Map<String, dynamic> map) {
    final rawContacts = map['contacts'];
    final contacts = <EmergencyContact>[];

    if (rawContacts is List) {
      for (final contact in rawContacts) {
        if (contact is Map) {
          contacts.add(
            EmergencyContact.fromMap(
              Map<String, dynamic>.from(contact),
            ),
          );
        }
      }
    } else if (rawContacts is Map) {
      for (final contact in rawContacts.values) {
        if (contact is Map) {
          contacts.add(
            EmergencyContact.fromMap(
              Map<String, dynamic>.from(contact),
            ),
          );
        }
      }
    }

    final rawSmsStatus = map['smsStatus'];
    final smsStatus = <String, bool>{};

    if (rawSmsStatus is Map) {
      rawSmsStatus.forEach((key, value) {
        if (value is bool) {
          smsStatus[key.toString()] = value;
        } else {
          smsStatus[key.toString()] =
              value.toString().toLowerCase() == 'true';
        }
      });
    }

    return SOSAlert(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? '',
      situation: map['situation']?.toString() ?? '',
      timestamp: DateTime.tryParse(
            map['timestamp']?.toString() ?? '',
          ) ??
          DateTime.now(),
      contacts: contacts,
      status: map['status']?.toString() ?? 'pending',
      locationLink: map['locationLink']?.toString(),
      latitude: _toDouble(map['latitude']),
      longitude: _toDouble(map['longitude']),
      callStatus: map['callStatus']?.toString() ?? 'pending',
      smsStatus: smsStatus,
    );
  }

  SOSAlert copyWith({
    String? id,
    String? userId,
    String? situation,
    DateTime? timestamp,
    List<EmergencyContact>? contacts,
    String? status,
    String? locationLink,
    double? latitude,
    double? longitude,
    String? callStatus,
    Map<String, bool>? smsStatus,
  }) {
    return SOSAlert(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      situation: situation ?? this.situation,
      timestamp: timestamp ?? this.timestamp,
      contacts: contacts ?? this.contacts,
      status: status ?? this.status,
      locationLink: locationLink ?? this.locationLink,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      callStatus: callStatus ?? this.callStatus,
      smsStatus: smsStatus ?? this.smsStatus,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString() ?? '',
    );
  }
}