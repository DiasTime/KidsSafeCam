import '../../../../domain/entities/app_user.dart';

/// Contract for authentication. The domain layer depends on this abstraction,
/// never on Firebase directly — so it can be faked in tests and swapped later.
abstract class AuthRepository {
  /// Emits the current user (or null when signed out) on every auth change.
  Stream<AppUser?> authStateChanges();

  /// The currently signed-in user, read synchronously (null if signed out).
  AppUser? get currentUser;

  /// Sign in with email/password. Throws on failure.
  Future<AppUser> signIn({required String email, required String password});

  /// Create an account with email/password and provision the user profile.
  Future<AppUser> signUp({required String email, required String password});

  /// Sign the current user out.
  Future<void> signOut();
}
