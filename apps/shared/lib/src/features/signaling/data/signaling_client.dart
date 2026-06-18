import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/constants.dart';

/// Firestore-based WebRTC signaling. SDP and ICE candidates are exchanged under
/// `devices/{deviceId}/calls/{callId}` (see docs/ARCHITECTURE.md §4.2):
///
///   call doc:  { offer: {sdp,type}, answer: {sdp,type} }
///   callerCandidates/*  /  calleeCandidates/*
///
/// Convention: the **parent** is the caller (writes the offer + callerCandidates,
/// reads the answer + calleeCandidates); the **camera** is the callee.
class SignalingClient {
  SignalingClient({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _call(String deviceId, String callId) =>
      _db
          .collection(FirestoreCollections.devices)
          .doc(deviceId)
          .collection(FirestoreCollections.calls)
          .doc(callId);

  CollectionReference<Map<String, dynamic>> _callerCandidates(
          String deviceId, String callId) =>
      _call(deviceId, callId).collection('callerCandidates');

  CollectionReference<Map<String, dynamic>> _calleeCandidates(
          String deviceId, String callId) =>
      _call(deviceId, callId).collection('calleeCandidates');

  // ── SDP ──────────────────────────────────────────────────
  Future<void> setOffer(
          String deviceId, String callId, RTCSessionDescription offer) =>
      _call(deviceId, callId).set(
        {'offer': {'sdp': offer.sdp, 'type': offer.type}},
        SetOptions(merge: true),
      );

  Future<void> setAnswer(
          String deviceId, String callId, RTCSessionDescription answer) =>
      _call(deviceId, callId).set(
        {'answer': {'sdp': answer.sdp, 'type': answer.type}},
        SetOptions(merge: true),
      );

  Stream<RTCSessionDescription?> watchOffer(String deviceId, String callId) =>
      _call(deviceId, callId)
          .snapshots()
          .map((doc) => _toDescription(doc.data()?['offer']));

  Stream<RTCSessionDescription?> watchAnswer(String deviceId, String callId) =>
      _call(deviceId, callId)
          .snapshots()
          .map((doc) => _toDescription(doc.data()?['answer']));

  // ── ICE candidates ───────────────────────────────────────
  Future<void> addCallerCandidate(
          String deviceId, String callId, RTCIceCandidate c) =>
      _callerCandidates(deviceId, callId).add(c.toMap());

  Future<void> addCalleeCandidate(
          String deviceId, String callId, RTCIceCandidate c) =>
      _calleeCandidates(deviceId, callId).add(c.toMap());

  /// Caller listens for the callee's candidates, and vice versa.
  Stream<RTCIceCandidate> watchCalleeCandidates(
          String deviceId, String callId) =>
      _newCandidates(_calleeCandidates(deviceId, callId));

  Stream<RTCIceCandidate> watchCallerCandidates(
          String deviceId, String callId) =>
      _newCandidates(_callerCandidates(deviceId, callId));

  /// Best-effort cleanup of an ended call's signaling data.
  Future<void> deleteCall(String deviceId, String callId) async {
    for (final col in [
      _callerCandidates(deviceId, callId),
      _calleeCandidates(deviceId, callId),
    ]) {
      final docs = await col.get();
      for (final d in docs.docs) {
        await d.reference.delete();
      }
    }
    await _call(deviceId, callId).delete();
  }

  Stream<RTCIceCandidate> _newCandidates(
      CollectionReference<Map<String, dynamic>> col) {
    return col.snapshots().expand((snap) => snap.docChanges
        .where((c) => c.type == DocumentChangeType.added)
        .map((c) {
      final d = c.doc.data()!;
      return RTCIceCandidate(
        d['candidate'] as String?,
        d['sdpMid'] as String?,
        (d['sdpMLineIndex'] as num?)?.toInt(),
      );
    }));
  }

  RTCSessionDescription? _toDescription(dynamic value) {
    if (value is! Map) return null;
    return RTCSessionDescription(value['sdp'] as String?, value['type'] as String?);
  }
}
