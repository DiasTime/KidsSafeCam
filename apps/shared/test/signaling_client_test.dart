import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late SignalingClient client;
  const deviceId = 'device-1';

  setUp(() {
    firestore = FakeFirebaseFirestore();
    client = SignalingClient(firestore: firestore);
  });

  test('newCallId returns a fresh, non-empty id', () {
    final a = client.newCallId(deviceId);
    final b = client.newCallId(deviceId);
    expect(a, isNotEmpty);
    expect(a, isNot(b));
  });

  test('offer round-trips through getOffer and watchOffer', () async {
    final callId = client.newCallId(deviceId);
    final offer = RTCSessionDescription('v=0\r\n...offer', 'offer');

    await client.setOffer(deviceId, callId, offer);

    final read = await client.getOffer(deviceId, callId);
    expect(read, isNotNull);
    expect(read!.sdp, offer.sdp);
    expect(read.type, 'offer');

    final watched = await client.watchOffer(deviceId, callId).first;
    expect(watched!.sdp, offer.sdp);
  });

  test('answer round-trips through watchAnswer', () async {
    final callId = client.newCallId(deviceId);
    final answer = RTCSessionDescription('v=0\r\n...answer', 'answer');

    await client.setAnswer(deviceId, callId, answer);

    final watched = await client.watchAnswer(deviceId, callId).first;
    expect(watched!.sdp, answer.sdp);
    expect(watched.type, 'answer');
  });

  test('caller and callee ICE candidates are exchanged separately', () async {
    final callId = client.newCallId(deviceId);
    final callerCandidate = RTCIceCandidate('candidate:caller', '0', 0);
    final calleeCandidate = RTCIceCandidate('candidate:callee', '1', 1);

    await client.addCallerCandidate(deviceId, callId, callerCandidate);
    await client.addCalleeCandidate(deviceId, callId, calleeCandidate);

    // The callee reads caller candidates; the caller reads callee candidates.
    final fromCaller = await client
        .watchCallerCandidates(deviceId, callId)
        .first;
    final fromCallee = await client
        .watchCalleeCandidates(deviceId, callId)
        .first;

    expect(fromCaller.candidate, 'candidate:caller');
    expect(fromCaller.sdpMLineIndex, 0);
    expect(fromCallee.candidate, 'candidate:callee');
    expect(fromCallee.sdpMLineIndex, 1);
  });

  test('watchIncomingCalls emits only unanswered calls', () async {
    final emitted = <String>[];
    final sub = client.watchIncomingCalls(deviceId).listen(emitted.add);
    await pumpEventQueue();

    // A parent posts an offer with no answer yet → should be surfaced.
    await client.setOffer(
      deviceId,
      'pending-call',
      RTCSessionDescription('sdp', 'offer'),
    );
    await pumpEventQueue();

    // An already-answered call → should be ignored.
    await firestore
        .collection('devices')
        .doc(deviceId)
        .collection('calls')
        .doc('answered-call')
        .set({
          'offer': {'sdp': 'sdp', 'type': 'offer'},
          'answer': {'sdp': 'sdp', 'type': 'answer'},
        });
    await pumpEventQueue();

    expect(emitted, ['pending-call']);
    await sub.cancel();
  });

  test('deleteCall removes the call document and its candidates', () async {
    final callId = client.newCallId(deviceId);
    await client.setOffer(
      deviceId,
      callId,
      RTCSessionDescription('sdp', 'offer'),
    );
    await client.addCallerCandidate(
      deviceId,
      callId,
      RTCIceCandidate('candidate:x', '0', 0),
    );

    await client.deleteCall(deviceId, callId);

    final doc = await firestore
        .collection('devices')
        .doc(deviceId)
        .collection('calls')
        .doc(callId)
        .get();
    expect(doc.exists, isFalse);
  });
}
