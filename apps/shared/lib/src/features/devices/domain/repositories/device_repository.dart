import '../../../../domain/entities/device.dart';

/// Contract for reading and managing a user's camera devices.
abstract class DeviceRepository {
  /// Streams the devices owned by [ownerId], newest first.
  Stream<List<Device>> watchDevices(String ownerId);

  /// Streams a single device (null if it disappears).
  Stream<Device?> watchDevice(String deviceId);

  /// Rename a device.
  Future<void> rename({required String deviceId, required String name});

  /// Update a device's settings (night mode, AI sensitivity, notifications).
  Future<void> updateSettings({
    required String deviceId,
    required DeviceSettings settings,
  });

  /// Remove a device the user owns.
  Future<void> deleteDevice(String deviceId);
}
