import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/app_user.dart';
import '../data/repositories/firebase_auth_repository.dart';
import '../domain/repositories/auth_repository.dart';

/// The app's [AuthRepository]. Override in tests with a fake.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(),
);

/// Streams the signed-in user (or null). Drives auth-gated routing.
final authStateChangesProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Handles sign-in / sign-up / sign-out and exposes a loading/error state the
/// login UI can react to.
class AuthController extends AutoDisposeAsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signIn({required String email, required String password}) {
    return _run(() => ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password));
  }

  Future<bool> signUp({required String email, required String password}) {
    return _run(() => ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password));
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(action);
    return !state.hasError;
  }
}

final authControllerProvider =
    AutoDisposeAsyncNotifierProvider<AuthController, void>(AuthController.new);

/// Turns a thrown auth error into a human-readable message for the UI.
String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Please choose a stronger password (6+ characters).';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
