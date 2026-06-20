import '../../domain/ai_detector.dart';
// Real implementation on mobile/desktop (dart:io / FFI); a no-op stub on web,
// which has no dart:ffi for tflite_flutter.
import 'cry_detector_stub.dart'
    if (dart.library.io) 'cry_detector_io.dart' as impl;

/// Builds the platform's cry detector, or `null` where unsupported (web).
AiDetector? createCryDetector({double threshold = 0.4}) =>
    impl.createCryDetector(threshold: threshold);
