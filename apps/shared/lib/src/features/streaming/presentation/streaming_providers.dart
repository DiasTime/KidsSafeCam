import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../signaling/presentation/signaling_providers.dart';
import '../data/webrtc_session.dart';

/// Builds a [WebRtcSession] for one call. Injected so app controllers can
/// create sessions without reaching for singletons, and tests can override it.
typedef WebRtcSessionFactory = WebRtcSession Function({
  required String deviceId,
  required String callId,
  required List<Map<String, dynamic>> iceServers,
});

final webRtcSessionFactoryProvider = Provider<WebRtcSessionFactory>((ref) {
  final signaling = ref.watch(signalingClientProvider);
  return ({
    required String deviceId,
    required String callId,
    required List<Map<String, dynamic>> iceServers,
  }) =>
      WebRtcSession(
        signaling: signaling,
        deviceId: deviceId,
        callId: callId,
        iceServers: iceServers,
      );
});
