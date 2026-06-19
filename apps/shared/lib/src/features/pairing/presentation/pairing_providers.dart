import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/functions_pairing_repository.dart';
import '../domain/repositories/pairing_repository.dart';

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => FunctionsPairingRepository(),
);

/// Camera side: requests a fresh pairing code. Invalidate to mint a new one.
final pairingCodeProvider = FutureProvider.autoDispose<PairingCode>(
  (ref) => ref.watch(pairingRepositoryProvider).requestCode(),
);

/// Parent side: claims a code entered by the user.
class ClaimController extends AutoDisposeAsyncNotifier<String?> {
  @override
  FutureOr<String?> build() => null;

  /// Returns true on success (state holds the new deviceId).
  Future<bool> claim(String code) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(pairingRepositoryProvider).claimCode(code),
    );
    return !state.hasError;
  }
}

final claimControllerProvider =
    AutoDisposeAsyncNotifierProvider<ClaimController, String?>(
      ClaimController.new,
    );

/// Friendly message for a pairing failure. The Cloud Functions already return
/// user-facing messages (e.g. "This code has expired."), so we surface those.
String pairingErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.message ?? 'Pairing failed. Please try again.';
  }
  return 'Pairing failed. Please check your connection and try again.';
}
