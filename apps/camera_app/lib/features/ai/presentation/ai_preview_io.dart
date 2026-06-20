import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

Widget buildAiPreview(Object? controller) {
  if (controller is CameraController && controller.value.isInitialized) {
    return CameraPreview(controller);
  }
  return const SizedBox.shrink();
}
