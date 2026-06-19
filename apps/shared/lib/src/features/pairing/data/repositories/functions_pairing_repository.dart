import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/repositories/pairing_repository.dart';

/// [PairingRepository] backed by the `requestPairingCode` / `claimPairingCode`
/// callable Cloud Functions.
class FunctionsPairingRepository implements PairingRepository {
  FunctionsPairingRepository({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<PairingCode> requestCode({String deviceName = 'Camera'}) async {
    final result = await _functions
        .httpsCallable('requestPairingCode')
        .call<Map<String, dynamic>>({'deviceName': deviceName});
    final data = result.data;
    return PairingCode(
      code: data['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch(
        (data['expiresAt'] as num).toInt(),
      ),
    );
  }

  @override
  Future<String> claimCode(String code) async {
    final result = await _functions
        .httpsCallable('claimPairingCode')
        .call<Map<String, dynamic>>({'code': code.trim()});
    return result.data['deviceId'] as String;
  }
}
