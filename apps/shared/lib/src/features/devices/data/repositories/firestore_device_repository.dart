import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants.dart';
import '../../../../domain/entities/device.dart';
import '../../domain/repositories/device_repository.dart';
import '../models/device_model.dart';

/// Firestore-backed [DeviceRepository]. Queries are scoped by `ownerId`, which
/// the security rules also enforce.
class FirestoreDeviceRepository implements DeviceRepository {
  FirestoreDeviceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _devices =>
      _firestore.collection(FirestoreCollections.devices);

  @override
  Stream<List<Device>> watchDevices(String ownerId) {
    return _devices
        .where('ownerId', isEqualTo: ownerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DeviceModel.fromDoc).toList());
  }

  @override
  Stream<Device?> watchDevice(String deviceId) {
    return _devices
        .doc(deviceId)
        .snapshots()
        .map((doc) => doc.exists ? DeviceModel.fromDoc(doc) : null);
  }

  @override
  Stream<Device?> watchDeviceForCamera(String cameraUid) {
    // The security rules admit the camera identity to read a device matching
    // its own cameraUid, so this query is allowed (no orderBy → no extra index).
    return _devices
        .where('cameraUid', isEqualTo: cameraUid)
        .limit(1)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.isEmpty ? null : DeviceModel.fromDoc(snap.docs.first),
        );
  }

  @override
  Future<void> rename({required String deviceId, required String name}) {
    return _devices.doc(deviceId).update({'name': name});
  }

  @override
  Future<void> updateSettings({
    required String deviceId,
    required DeviceSettings settings,
  }) {
    return _devices.doc(deviceId).update({
      'settings': DeviceModel.settingsToMap(settings),
    });
  }

  @override
  Future<void> deleteDevice(String deviceId) {
    return _devices.doc(deviceId).delete();
  }
}
