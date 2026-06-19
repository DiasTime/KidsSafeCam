import 'dart:async';

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// State the live-view screen renders for one device's call.
@immutable
class LiveViewState {
  const LiveViewState({
    this.rendererReady = false,
    this.hasRemoteVideo = false,
    this.callState,
    this.errorMessage,
  });

  /// True once the remote renderer is initialized and can be mounted.
  final bool rendererReady;

  /// True once the camera's remote stream has been attached.
  final bool hasRemoteVideo;

  /// Peer-connection state, mapped to a connecting / connected / disconnected
  /// indicator in the UI.
  final RTCPeerConnectionState? callState;

  final String? errorMessage;

  bool get isConnected =>
      callState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  bool get isDisconnected =>
      callState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
      callState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
      callState == RTCPeerConnectionState.RTCPeerConnectionStateClosed;

  LiveViewState copyWith({
    bool? rendererReady,
    bool? hasRemoteVideo,
    RTCPeerConnectionState? callState,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LiveViewState(
      rendererReady: rendererReady ?? this.rendererReady,
      hasRemoteVideo: hasRemoteVideo ?? this.hasRemoteVideo,
      callState: callState ?? this.callState,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// Drives the parent (caller) side of a live view: it creates the call + offer
/// for one device, renders the camera's remote stream, and tears everything
/// down (including the signaling docs) on hang-up or when the screen closes.
class LiveViewController
    extends AutoDisposeFamilyNotifier<LiveViewState, String> {
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  WebRtcSession? _session;
  bool _disposed = false;

  String get _deviceId => arg;

  @override
  LiveViewState build(String deviceId) {
    ref.onDispose(_dispose);
    _start();
    return const LiveViewState();
  }

  Future<void> _start() async {
    try {
      await remoteRenderer.initialize();
      if (_disposed) return;
      state = state.copyWith(rendererReady: true);

      final signaling = ref.read(signalingClientProvider);
      final iceServers = await ref.read(iceServersProvider.future);
      if (_disposed) return;

      final callId = signaling.newCallId(_deviceId);
      final session = ref.read(webRtcSessionFactoryProvider)(
        deviceId: _deviceId,
        callId: callId,
        iceServers: iceServers,
      );
      _session = session;

      session.onRemoteStream = (stream) {
        if (_disposed) return;
        remoteRenderer.srcObject = stream;
        state = state.copyWith(hasRemoteVideo: true);
      };
      session.connectionState.addListener(() {
        if (_disposed) return;
        state = state.copyWith(callState: session.connectionState.value);
      });

      await session.connectAsCaller();
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(errorMessage: 'Could not start live view: $e');
    }
  }

  /// Ends the call: closes the peer connection and removes its signaling docs.
  Future<void> hangUp() => _session?.close(deleteCall: true) ?? Future.value();

  Future<void> _dispose() async {
    _disposed = true;
    // deleteCall cleans up the ephemeral signaling docs when leaving the screen.
    await _session?.close(deleteCall: true);
    _session = null;
    try {
      await remoteRenderer.dispose();
    } catch (_) {}
  }
}

final liveViewControllerProvider = AutoDisposeNotifierProviderFamily<
    LiveViewController, LiveViewState, String>(
  LiveViewController.new,
);
