import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../controllers/live_view_controller.dart';

/// Parent live-view screen (route `/camera/:deviceId`): renders the camera's
/// remote video, shows a connection-status indicator, and hangs up — tearing
/// down the peer connection and the call's signaling docs — on exit.
class LiveViewPage extends ConsumerWidget {
  const LiveViewPage({super.key, required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveViewControllerProvider(deviceId));
    final controller = ref.read(liveViewControllerProvider(deviceId).notifier);
    final device = ref.watch(deviceProvider(deviceId)).valueOrNull;

    Future<void> hangUp() async {
      await controller.hangUp();
      if (context.mounted) context.pop();
    }

    return PopScope(
      // Ensure teardown also runs when leaving via the system back gesture.
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(device?.name ?? 'Live view'),
          actions: [_StatusChip(state: state)],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (state.hasRemoteVideo)
              RTCVideoView(
                controller.remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              )
            else
              _ConnectingView(state: state),
            if (state.hasRemoteVideo && !state.isConnected)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.redAccent,
          onPressed: hangUp,
          icon: const Icon(Icons.call_end),
          label: const Text('Hang up'),
        ),
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  const _ConnectingView({required this.state});

  final LiveViewState state;

  @override
  Widget build(BuildContext context) {
    final String message;
    final bool showSpinner;
    if (state.errorMessage != null) {
      message = state.errorMessage!;
      showSpinner = false;
    } else if (state.isDisconnected) {
      message = 'Disconnected. The camera may be offline.';
      showSpinner = false;
    } else {
      message = 'Connecting to the camera…';
      showSpinner = true;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              const CircularProgressIndicator()
            else
              const Icon(Icons.videocam_off, size: 72, color: Colors.white70),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state});

  final LiveViewState state;

  @override
  Widget build(BuildContext context) {
    final ({Color color, String label}) status;
    if (state.isConnected) {
      status = (color: Colors.greenAccent, label: 'Connected');
    } else if (state.isDisconnected) {
      status = (color: Colors.redAccent, label: 'Disconnected');
    } else {
      status = (color: Colors.amberAccent, label: 'Connecting');
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 12, color: status.color),
            const SizedBox(width: 6),
            Text(status.label),
          ],
        ),
      ),
    );
  }
}
