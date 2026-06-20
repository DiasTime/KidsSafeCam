import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../../../ai/presentation/ai_monitor_controller.dart';
import '../../../ai/presentation/ai_preview.dart';
import '../controllers/camera_streaming_controller.dart';

/// Camera home screen: runs on-device AI monitoring (cry / fall / wake) and
/// answers parent calls in the foreground. While idle it shows the monitoring
/// preview; during a call it shows the live capture.
class CameraHomePage extends ConsumerWidget {
  const CameraHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraStreamingControllerProvider);
    final ai = ref.watch(aiMonitorControllerProvider);
    final renderer = ref
        .read(cameraStreamingControllerProvider.notifier)
        .localRenderer;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Baby Monitor — Camera'),
        actions: [
          IconButton(
            tooltip: 'Pair with parent',
            icon: const Icon(Icons.link),
            onPressed: () => context.push('/pair'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: Colors.black,
            child: _buildPreview(state, ai, renderer),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StatusBar(state: state, ai: ai),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(
    CameraStreamingState state,
    AiMonitorState ai,
    RTCVideoRenderer renderer,
  ) {
    if (state.previewReady) {
      return RTCVideoView(
        renderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        mirror: true,
      );
    }
    if (ai.monitoring) {
      return buildAiPreview(ai.previewController);
    }
    return _PreviewPlaceholder(errorMessage: state.errorMessage);
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              errorMessage == null
                  ? Icons.videocam_outlined
                  : Icons.videocam_off,
              size: 72,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? 'Starting camera…',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.state, required this.ai});

  final CameraStreamingState state;
  final AiMonitorState ai;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, String label, Color color}) status;
    if (!state.paired) {
      status = (
        icon: Icons.link_off,
        label: 'Not paired — tap the link icon to pair with a parent.',
        color: Colors.orangeAccent,
      );
    } else if (state.hasViewer) {
      final connected =
          state.callState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      status = connected
          ? (
              icon: Icons.fiber_manual_record,
              label: 'Live — a parent is watching.',
              color: Colors.redAccent,
            )
          : (
              icon: Icons.sync,
              label: 'A parent is connecting…',
              color: Colors.amberAccent,
            );
    } else if (ai.monitoring) {
      status = (
        icon: Icons.shield_outlined,
        label: 'Monitoring — ${_detectorLabel(ai.activeDetectors)}.',
        color: Colors.greenAccent,
      );
    } else {
      status = (
        icon: Icons.check_circle_outline,
        label: 'Ready — waiting for a parent to connect.',
        color: Colors.greenAccent,
      );
    }

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(status.icon, color: status.color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status.label,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _detectorLabel(List<String> detectors) {
    if (detectors.contains('pose') && detectors.contains('cry')) {
      return 'cry, fall & wake detection active';
    }
    if (detectors.contains('cry')) return 'cry detection active';
    if (detectors.contains('pose')) return 'fall & wake detection active';
    return 'AI active';
  }
}
