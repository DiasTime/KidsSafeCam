import 'package:equatable/equatable.dart';

/// A short-lived pairing code minted by a camera for a parent to claim.
class PairingCode extends Equatable {
  const PairingCode({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  Duration get timeRemaining => expiresAt.difference(DateTime.now());
  bool get isExpired => timeRemaining.isNegative;

  @override
  List<Object?> get props => [code, expiresAt];
}

/// Contract for the pairing flow, backed by Cloud Functions.
abstract class PairingRepository {
  /// Camera side: mint a code to display to the parent.
  Future<PairingCode> requestCode({String deviceName});

  /// Parent side: claim a code; returns the new device id.
  Future<String> claimCode(String code);
}
