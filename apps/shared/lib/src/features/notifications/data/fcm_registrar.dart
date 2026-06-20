import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants.dart';

/// Registers this device's FCM token under the signed-in user's
/// `users/{uid}.fcmTokens` array, so the backend fan-out
/// (`fanOutEventNotification`) can push event notifications to it. This is the
/// client half of Step 10 — the parent app calls it once a user is signed in.
///
/// The token is stored with `arrayUnion` (so multiple devices coexist) and kept
/// fresh on rotation; sign-out removes it again. Web needs a VAPID key
/// (Firebase Console → Cloud Messaging → Web Push certificates), passed in by
/// the app; native platforms ignore it.
class FcmRegistrar {
  FcmRegistrar({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    String? vapidKey,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _vapidKey = vapidKey;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final String? _vapidKey;

  String? _uid;
  String? _currentToken;
  StreamSubscription<String>? _refreshSub;

  /// Requests notification permission, resolves the FCM token, stores it under
  /// [uid], and keeps it fresh on rotation. Safe to call repeatedly (e.g. on
  /// every auth change). A denied permission or null token is a no-op.
  Future<void> registerForUser(String uid) async {
    _uid = uid;
    await _messaging.requestPermission();

    String? token;
    try {
      token = await _messaging.getToken(
        vapidKey: kIsWeb ? _vapidKey : null,
      );
    } catch (_) {
      // No token (e.g. web without a VAPID key, or permission denied).
      return;
    }
    if (token != null) {
      _currentToken = token;
      await _storeToken(uid, token);
    }

    _refreshSub ??= _messaging.onTokenRefresh.listen((t) {
      _currentToken = t;
      final u = _uid;
      if (u != null) _storeToken(u, t);
    });
  }

  /// Removes this device's token on sign-out so a logged-out device stops
  /// receiving the previous user's pushes.
  Future<void> unregister() async {
    final uid = _uid;
    final token = _currentToken;
    if (uid != null && token != null) {
      try {
        await _userDoc(uid).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
      } catch (_) {
        // Best-effort; ignore if the doc is already gone.
      }
    }
    await _refreshSub?.cancel();
    _refreshSub = null;
    _uid = null;
    _currentToken = null;
  }

  Future<void> _storeToken(String uid, String token) async {
    try {
      await _userDoc(uid).update({
        'fcmTokens': FieldValue.arrayUnion([token]),
      });
    } catch (_) {
      // The users doc is created at sign-up; ignore transient write races.
    }
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection(FirestoreCollections.users).doc(uid);
}
