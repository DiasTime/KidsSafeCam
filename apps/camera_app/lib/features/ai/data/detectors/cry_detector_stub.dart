import '../../domain/ai_detector.dart';

/// Web fallback — on-device TFLite cry detection isn't available without
/// `dart:ffi`, so there's no detector to run.
AiDetector? createCryDetector({double threshold = 0.4}) => null;
