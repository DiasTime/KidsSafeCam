/// ICE server configuration for a WebRTC session, as returned by the
/// `getTurnCredentials` Cloud Function. The `iceServers` list is in the shape
/// `RTCPeerConnection` expects: `{ 'urls': ..., 'username'?, 'credential'? }`.
class IceConfig {
  const IceConfig({required this.iceServers, required this.ttl});

  final List<Map<String, dynamic>> iceServers;

  /// Seconds the TURN credentials remain valid.
  final int ttl;

  Map<String, dynamic> toPeerConnectionConfig() => {'iceServers': iceServers};

  factory IceConfig.fromCallable(Map<String, dynamic> data) {
    final servers = (data['iceServers'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    return IceConfig(
      iceServers: servers,
      ttl: (data['ttl'] as num?)?.toInt() ?? 0,
    );
  }
}
