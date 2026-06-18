import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IceConfig.fromCallable', () {
    test('parses STUN-only response', () {
      final cfg = IceConfig.fromCallable({
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
        'ttl': 43200,
      });
      expect(cfg.iceServers.length, 1);
      expect(cfg.ttl, 43200);
      expect(cfg.toPeerConnectionConfig(), {
        'iceServers': [
          {
            'urls': ['stun:stun.l.google.com:19302'],
          },
        ],
      });
    });

    test('parses TURN credentials', () {
      final cfg = IceConfig.fromCallable({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {
            'urls': ['turn:turn.example.com:3478'],
            'username': '123:alice',
            'credential': 'abc=',
          },
        ],
        'ttl': 3600,
      });
      expect(cfg.iceServers.length, 2);
      expect(cfg.iceServers[1]['username'], '123:alice');
      expect(cfg.iceServers[1]['credential'], 'abc=');
    });

    test('tolerates a missing iceServers field', () {
      final cfg = IceConfig.fromCallable({});
      expect(cfg.iceServers, isEmpty);
      expect(cfg.ttl, 0);
    });
  });
}
