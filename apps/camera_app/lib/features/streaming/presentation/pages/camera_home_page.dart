import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder home screen for the Camera app.
///
/// Future steps replace this with: pairing UI (Step 4), the WebRTC publisher
/// preview + status (Steps 5-8), background-service controls (Step 9), and the
/// on-device AI indicators (Steps 12-13).
class CameraHomePage extends ConsumerWidget {
  const CameraHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateChangesProvider).valueOrNull?.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baby Monitor — Camera'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined, size: 72),
              const SizedBox(height: 16),
              const Text(
                'Camera device',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pair with a parent device to begin streaming.',
                textAlign: TextAlign.center,
              ),
              if (email != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Signed in as $email',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
