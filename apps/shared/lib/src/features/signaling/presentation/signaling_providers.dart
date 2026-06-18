import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
