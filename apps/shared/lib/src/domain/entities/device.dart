import 'package:equatable/equatable.dart';

enum DeviceStatus {
  online('online'),
  offline('offline');

  const DeviceStatus(this.wireName);
  final String wireName;

  static DeviceStatus fromWire(String? value) =>
      value == 'online' ? DeviceStatus.online : DeviceStatus.offline;
}

/// Per-device configuration controlled by the owner.
class DeviceSettings extends Equatable {
  const DeviceSettings({
    this.nightMode = false,
    this.aiSensitivity = 0.5,
    this.notificationsEnabled = true,
  });

  final bool nightMode;
  final double aiSensitivity; // 0.0 - 1.0
  final bool notificationsEnabled;

  @override
  List<Object?> get props => [nightMode, aiSensitivity, notificationsEnabled];
}

/// A paired camera device owned by a user.
class Device extends Equatable {
  const Device({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.lastSeenAt,
    this.settings = const DeviceSettings(),
  });

  final String id;
  final String ownerId;
  final String name;
  final DeviceStatus status;
  final DateTime createdAt;
  final DateTime? lastSeenAt;
  final DeviceSettings settings;

  bool get isOnline => status == DeviceStatus.online;

  @override
  List<Object?> get props => [id, ownerId, name, status, createdAt, lastSeenAt];
}
