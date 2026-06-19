import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/constants.dart';
import '../../../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Firebase-backed [AuthRepository]. Maps [User] to our domain [AppUser] and
/// provisions a `users/{uid}` profile document on sign-up.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AppUser? _toUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
    );
  }

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_toUser);

  @override
  AppUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return _toUser(cred.user)!;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = _toUser(cred.user)!;
    // Provision the profile document (rules require email to be a string and
    // the doc id to equal the uid).
    await _firestore.collection(FirestoreCollections.users).doc(user.id).set({
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return user;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
