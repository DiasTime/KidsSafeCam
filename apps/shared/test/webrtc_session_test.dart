import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 7 — parent-side audio mute. These tests cover the mute *state machine*
/// (no native peer connection is created): toggling before any remote stream
/// arrives must still track the desired state so it can be applied on arrival.
void main() {
  WebRtcSession buildSession() => WebRtcSession(
        signaling: SignalingClient(firestore: FakeFirebaseFirestore()),
        deviceId: 'device-1',
        callId: 'call-1',
        iceServers: const [],
      );

  test('remote audio starts unmuted', () {
    final session = buildSession();
    expect(session.remoteAudioMuted.value, isFalse);
  });

  test('setRemoteAudioMuted updates the notifier and returns the new state', () {
    final session = buildSession();

    expect(session.setRemoteAudioMuted(true), isTrue);
    expect(session.remoteAudioMuted.value, isTrue);

    expect(session.setRemoteAudioMuted(false), isFalse);
    expect(session.remoteAudioMuted.value, isFalse);
  });

  test('toggleRemoteAudioMuted flips the state each call', () {
    final session = buildSession();

    expect(session.toggleRemoteAudioMuted(), isTrue);
    expect(session.remoteAudioMuted.value, isTrue);

    expect(session.toggleRemoteAudioMuted(), isFalse);
    expect(session.remoteAudioMuted.value, isFalse);
  });

  test('muting before a remote stream arrives is a safe no-op', () {
    final session = buildSession();
    // No stream attached yet; this must not throw and must retain the choice.
    expect(() => session.setRemoteAudioMuted(true), returnsNormally);
    expect(session.remoteAudioMuted.value, isTrue);
  });

  // ── Step 8 — push-to-talk state machine ────────────────────────────
  test('push-to-talk starts released and unavailable before a mic is added', () {
    final session = buildSession();
    expect(session.talking.value, isFalse);
    expect(session.talkAvailable.value, isFalse);
  });

  test('setTalking updates the talking notifier and returns the new state', () {
    final session = buildSession();

    expect(session.setTalking(true), isTrue);
    expect(session.talking.value, isTrue);

    expect(session.setTalking(false), isFalse);
    expect(session.talking.value, isFalse);
  });

  test('toggleTalking flips the state each call', () {
    final session = buildSession();

    expect(session.toggleTalking(), isTrue);
    expect(session.talking.value, isTrue);

    expect(session.toggleTalking(), isFalse);
    expect(session.talking.value, isFalse);
  });

  test('setTalking before a local stream exists is a safe no-op', () {
    final session = buildSession();
    expect(() => session.setTalking(true), returnsNormally);
    expect(session.talking.value, isTrue);
  });
}
