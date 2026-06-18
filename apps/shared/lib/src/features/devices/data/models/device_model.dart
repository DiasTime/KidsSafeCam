import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../domain/entities/device.dart';

/// Maps between Firestore documents and the [Device] domain entity.
class DeviceModel {
  DeviceModel._();

  static Device fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    final settings = (data['settings'] as Map<String, dynamic>?) ?? const {};
    return Device(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      name: data['name'] as String? ?? 'Camera',
      status: DeviceStatus.fromWire(data['status'] as String?),
      createdAt: _toDate(data['createdAt']) ?? DateTime.now(),
      lastSeenAt: _toDate(data['lastSeenAt']),
      settings: DeviceSettings(
        nightMode: settings['nightMode'] as bool? ?? false,
        aiSensitivity: (settings['aiSensitivity'] as num?)?.toDouble() ?? 0.5,
        notificationsEnabled: settings['notificationsEnabled'] as bool? ?? true,
      ),
    );
  }

  static Map<String, dynamic> settingsToMap(DeviceSettings s) => {
        'nightMode': s.nightMode,
        'aiSensitivity': s.aiSensitivity,
        'notificationsEnabled': s.notificationsEnabled,
      };

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
