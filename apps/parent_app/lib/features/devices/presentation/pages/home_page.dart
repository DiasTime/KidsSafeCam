import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder home (camera list) screen for the Parent app.
///
/// Future steps replace this with: the live device list with online/offline
/// status (Step 3), pairing entry (Step 4), and navigation to the live camera
/// view with audio, push-to-talk, and event history (Steps 6-11).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authStateChangesProvider).valueOrNull?.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cameras'),
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
              const Icon(Icons.crib_outlined, size: 72),
              const SizedBox(height: 16),
              const Text(
                'No cameras yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pair a camera device to start monitoring.',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: null, // wired to the pairing flow in Step 4
        icon: const Icon(Icons.add),
        label: const Text('Add camera'),
      ),
    );
  }
}
