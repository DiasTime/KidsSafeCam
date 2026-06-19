import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../signaling/data/signaling_client.dart';

/// Manages one WebRTC peer connection for a single call, layered on top of the
/// Firestore-based [SignalingClient] and an ICE-server list.
///
/// Roles (docs/ARCHITECTURE.md §4.2):
///  - **Parent = caller** ([connectAsCaller]). In Step 6 the parent only
///    *receives*, so it offers two `recvonly` transceivers and renders the
///    camera's tracks via [onRemoteStream].
///  - **Camera = callee** ([answerAsCallee]). It captures video + audio with
///    `getUserMedia`, publishes the tracks, and answers the parent's offer.
///
/// ICE candidates that arrive before the remote description is applied are
/// buffered and flushed once it is set.
class WebRtcSession {
  WebRtcSession({
    required SignalingClient signaling,
    required this.deviceId,
    required this.callId,
    required List<Map<String, dynamic>> iceServers,
  })  : _signaling = signaling,
        _iceServers = iceServers;

  final SignalingClient _signaling;
  final List<Map<String, dynamic>> _iceServers;

  final String deviceId;
  final String callId;

  RTCPeerConnection? _pc;

  MediaStream? _localStream;
  MediaStream? get localStream => _localStream;

  MediaStream? _remoteStream;
  MediaStream? get remoteStream => _remoteStream;

  /// Latest peer-connection state — drives a connecting / connected /
  /// disconnected indicator in the UI.
  final ValueNotifier<RTCPeerConnectionState> connectionState =
      ValueNotifier(RTCPeerConnectionState.RTCPeerConnectionStateNew);

  /// Whether the remote (camera) audio is currently muted on this side
  /// (Step 7). Muting just disables the received audio tracks locally, so
  /// playback stops instantly without renegotiating the call.
  final ValueNotifier<bool> remoteAudioMuted = ValueNotifier(false);

  /// Fired when the remote stream arrives (parent renders this).
  void Function(MediaStream stream)? onRemoteStream;

  /// Fired when local capture starts (camera shows this as a preview).
  void Function(MediaStream stream)? onLocalStream;

  final List<RTCIceCandidate> _pendingRemoteCandidates = [];
  bool _remoteDescriptionSet = false;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _disposed = false;

  /// Whether this session captured [_localStream] itself (and so must dispose
  /// it). False when the caller passes in a shared preview stream it still owns.
  bool _ownsLocalStream = true;

  Map<String, dynamic> get _config => {
        'iceServers': _iceServers,
        'sdpSemantics': 'unified-plan',
      };

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(_config);
    pc.onConnectionState = (state) {
      if (!_disposed) connectionState.value = state;
    };
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams.first;
        // Respect a mute toggled before the stream arrived.
        _applyRemoteAudioMuted();
        onRemoteStream?.call(_remoteStream!);
      }
    };
    _pc = pc;
    return pc;
  }

  // ── Parent (caller) ────────────────────────────────────────────────
  /// Creates the call doc + offer and waits for the camera's answer.
  Future<void> connectAsCaller() async {
    final pc = await _createPeerConnection();
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _signaling.addCallerCandidate(deviceId, callId, candidate);
      }
    };

    // Step 6: the parent receives only, so request two recvonly media lines.
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    await pc.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeAudio,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );

    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    await _signaling.setOffer(deviceId, callId, offer);

    _subs.add(_signaling.watchAnswer(deviceId, callId).listen((answer) async {
      if (answer == null || _remoteDescriptionSet || _disposed) return;
      await pc.setRemoteDescription(answer);
      _remoteDescriptionSet = true;
      await _flushPendingCandidates();
    }));

    _subs.add(_signaling
        .watchCalleeCandidates(deviceId, callId)
        .listen(_addRemoteCandidate));
  }

  // ── Camera (callee) ────────────────────────────────────────────────
  /// Publishes local media and answers the parent's offer. Pass [localStream]
  /// to reuse an already-running capture (e.g. the on-screen preview); when
  /// omitted the session captures its own video + audio.
  Future<void> answerAsCallee({MediaStream? localStream}) async {
    final pc = await _createPeerConnection();
    pc.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _signaling.addCalleeCandidate(deviceId, callId, candidate);
      }
    };

    _ownsLocalStream = localStream == null;
    _localStream = localStream ??
        await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
        });
    onLocalStream?.call(_localStream!);
    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    final offer = await _signaling.getOffer(deviceId, callId);
    if (offer == null) {
      throw StateError('Cannot answer call $callId: no offer present.');
    }
    await pc.setRemoteDescription(offer);
    _remoteDescriptionSet = true;
    await _flushPendingCandidates();

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    await _signaling.setAnswer(deviceId, callId, answer);

    _subs.add(_signaling
        .watchCallerCandidates(deviceId, callId)
        .listen(_addRemoteCandidate));
  }

  Future<void> _addRemoteCandidate(RTCIceCandidate candidate) async {
    if (_disposed) return;
    if (!_remoteDescriptionSet) {
      _pendingRemoteCandidates.add(candidate);
      return;
    }
    await _pc?.addCandidate(candidate);
  }

  Future<void> _flushPendingCandidates() async {
    for (final candidate in _pendingRemoteCandidates) {
      await _pc?.addCandidate(candidate);
    }
    _pendingRemoteCandidates.clear();
  }

  // ── Audio mute (parent side, Step 7) ───────────────────────────────
  /// Mutes or unmutes the camera's audio by toggling the `enabled` flag on the
  /// received audio tracks. Returns the resulting muted state. Safe to call
  /// before the remote stream arrives — the choice is applied on arrival.
  bool setRemoteAudioMuted(bool muted) {
    remoteAudioMuted.value = muted;
    _applyRemoteAudioMuted();
    return muted;
  }

  /// Flips the current mute state; returns the new value.
  bool toggleRemoteAudioMuted() =>
      setRemoteAudioMuted(!remoteAudioMuted.value);

  void _applyRemoteAudioMuted() {
    final stream = _remoteStream;
    if (stream == null) return;
    final enabled = !remoteAudioMuted.value;
    for (final track in stream.getAudioTracks()) {
      track.enabled = enabled;
    }
  }

  /// Tears down the peer connection and local media. When [deleteCall] is true
  /// the call's signaling docs are removed too (the caller does this on hang-up).
  /// Safe to call more than once.
  Future<void> close({bool deleteCall = false}) async {
    if (_disposed) return;
    _disposed = true;

    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    if (_ownsLocalStream) {
      try {
        await _localStream?.dispose();
      } catch (_) {}
    }
    _localStream = null;
    _remoteStream = null;

    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;

    if (deleteCall) {
      try {
        await _signaling.deleteCall(deviceId, callId);
      } catch (_) {}
    }
  }
}
