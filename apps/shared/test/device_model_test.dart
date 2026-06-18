import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeviceStatus', () {
    test('maps wire values, defaulting unknown to offline', () {
      expect(DeviceStatus.fromWire('online'), DeviceStatus.online);
      expect(DeviceStatus.fromWire('offline'), DeviceStatus.offline);
      expect(DeviceStatus.fromWire(null), DeviceStatus.offline);
      expect(DeviceStatus.fromWire('???'), DeviceStatus.offline);
    });
  });

  group('DeviceModel.settingsToMap', () {
    test('serializes settings to the Firestore shape', () {
      const settings = DeviceSettings(
        nightMode: true,
        aiSensitivity: 0.8,
        notificationsEnabled: false,
      );
      expect(DeviceModel.settingsToMap(settings), {
        'nightMode': true,
        'aiSensitivity': 0.8,
        'notificationsEnabled': false,
      });
    });
  });
}
