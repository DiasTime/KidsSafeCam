import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BabyEventType', () {
    test('maps to and from wire names', () {
      expect(BabyEventType.babyCry.wireName, 'baby_cry');
      expect(
        BabyEventType.fromWire('fall_detected'),
        BabyEventType.fallDetected,
      );
    });

    test('unknown wire value falls back to soundDetected', () {
      expect(BabyEventType.fromWire('???'), BabyEventType.soundDetected);
    });
  });

  group('Device', () {
    test('isOnline reflects status', () {
      final device = Device(
        id: 'd1',
        ownerId: 'u1',
        name: 'Nursery',
        status: DeviceStatus.online,
        createdAt: DateTime(2026, 1, 1),
      );
      expect(device.isOnline, isTrue);
    });
  });
}
