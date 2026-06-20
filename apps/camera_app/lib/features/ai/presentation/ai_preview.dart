import 'package:flutter/widgets.dart';

// The camera plugin is mobile-only; the web build uses an empty placeholder.
import 'ai_preview_stub.dart'
    if (dart.library.io) 'ai_preview_io.dart' as impl;

/// Builds the live monitoring preview from the pose detector's camera
/// controller (passed as `Object?` so the web build doesn't import `camera`).
Widget buildAiPreview(Object? controller) => impl.buildAiPreview(controller);
