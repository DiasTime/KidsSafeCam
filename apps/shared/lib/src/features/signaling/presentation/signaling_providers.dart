import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../data/signaling_client.dart';
import '../domain/ice_config.dart';

final signalingClientProvider = Provider<SignalingClient>(
  (ref) => SignalingClient(),
);

/// Fetches ICE servers (STUN + ephemeral TURN) from the `getTurnCredentials`
/// Cloud Function. Re-fetch (invalidate) before the TTL expires for long sessions.
final iceConfigProvider = FutureProvider<IceConfig>((ref) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('getTurnCredentials')
      .call<Map<String, dynamic>>();
  return IceConfig.fromCallable(result.data);
});

/// The ICE-server list to hand to a peer connection: ephemeral STUN + TURN from
/// [iceConfigProvider], falling back to public STUN if the Cloud Function is
/// unavailable (e.g. not yet deployed, or offline on a LAN). This is what the
/// streaming controllers consume.
final iceServersProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  try {
    final config = await ref.watch(iceConfigProvider.future);
    if (config.iceServers.isNotEmpty) return config.iceServers;
  } catch (_) {
    // fall through to STUN-only
  }
  return WebRtcConfig.defaultStunServers;
});
