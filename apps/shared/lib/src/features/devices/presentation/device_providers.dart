import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/device.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/repositories/firestore_device_repository.dart';
import '../domain/repositories/device_repository.dart';

/// The app's [DeviceRepository]. Override in tests with a fake.
final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => FirestoreDeviceRepository(),
);

/// Streams the signed-in user's devices. Emits an empty list when signed out.
final devicesProvider = StreamProvider<List<Device>>((ref) {
  final user = ref.watch(authStateChangesProvider).valueOrNull;
  if (user == null) return Stream.value(const <Device>[]);
  return ref.watch(deviceRepositoryProvider).watchDevices(user.id);
});

/// Streams a single device by id (e.g. for the live-view / settings screens).
final deviceProvider = StreamProvider.family<Device?, String>((ref, deviceId) {
  return ref.watch(deviceRepositoryProvider).watchDevice(deviceId);
});
