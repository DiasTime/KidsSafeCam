import 'dart:async';

import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [AuthRepository] so the controller can be tested without Firebase.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({this.shouldFail = false});

  final bool shouldFail;
  final _users = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  Stream<AppUser?> authStateChanges() => _users.stream;

  @override
  AppUser? get currentUser => _current;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    if (shouldFail) throw Exception('invalid credentials');
    final user = AppUser(id: 'uid-1', email: email);
    _current = user;
    _users.add(user);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
  }) =>
      signIn(email: email, password: password);

  @override
  Future<void> signOut() async {
    _current = null;
    _users.add(null);
  }
}

ProviderContainer _container(AuthRepository repo) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );
  // Keep the auto-dispose controller alive for the duration of the test.
  container.listen(authControllerProvider, (_, __) {});
  return container;
}

void main() {
  test('signIn success leaves the controller without an error', () async {
    final container = _container(FakeAuthRepository());
    addTearDown(container.dispose);

    final ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'parent@example.com', password: 'secret');

    expect(ok, isTrue);
    expect(container.read(authControllerProvider).hasError, isFalse);
  });

  test('signIn failure surfaces an error state', () async {
    final container = _container(FakeAuthRepository(shouldFail: true));
    addTearDown(container.dispose);

    final ok = await container
        .read(authControllerProvider.notifier)
        .signIn(email: 'parent@example.com', password: 'wrong');

    expect(ok, isFalse);
    expect(container.read(authControllerProvider).hasError, isTrue);
  });

  test('authErrorMessage maps wrong-password to a friendly message', () {
    final message = authErrorMessage(
      FirebaseAuthException(code: 'wrong-password'),
    );
    expect(message, 'Incorrect email or password.');
  });

  test('authErrorMessage falls back for non-auth errors', () {
    expect(authErrorMessage(Exception('boom')),
        'Something went wrong. Please try again.');
  });
}
