/// Cross-app constants. Firestore collection names are centralized so the apps and
/// backend never drift apart.
class FirestoreCollections {
  FirestoreCollections._();

  static const users = 'users';
  static const devices = 'devices';
  static const events = 'events';
  static const notifications = 'notifications';

  /// Ephemeral signaling subcollection under a device document.
  static const calls = 'calls';
}

/// ICE servers for WebRTC. The STUN server is public; TURN credentials are fetched
/// ephemerally from the `getTurnCredentials` Cloud Function at call setup time
/// (no static TURN secret ships in the app — see docs/SECURITY.md).
class WebRtcConfig {
  WebRtcConfig._();

  static const List<Map<String, dynamic>> defaultStunServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];
}

/// How often the camera device updates its `lastSeenAt` heartbeat, and how long the
/// backend waits before declaring it offline (`connection_lost`).
class Heartbeat {
  Heartbeat._();

  static const Duration interval = Duration(seconds: 15);
  static const Duration offlineThreshold = Duration(seconds: 45);
}
