import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/add_camera_dialog.dart';
import '../widgets/activity_button.dart';

/// Home (camera list) screen for the Parent app. Shows the signed-in user's
/// devices with live online/offline status from Firestore.
///
/// Pairing (the "Add camera" action) is wired in Step 4; tapping a device opens
/// the live view in Step 6.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cameras'),
        actions: [
          const ActivityButton(),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.error_outline,
          title: 'Could not load cameras',
          subtitle: '$e',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _Message(
              icon: Icons.crib_outlined,
              title: 'No cameras yet',
              subtitle: 'Pair a camera device to start monitoring.',
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) => _DeviceTile(device: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddCameraDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add camera'),
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final online = device.isOnline;
    return ListTile(
      leading: const Icon(Icons.videocam_outlined),
      title: Text(device.name),
      subtitle: Text(online ? 'Online' : 'Offline'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 12,
            color: online ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right),
        ],
      ),
      // Tapping opens the live view; the camera answers if it's online.
      onTap: () => context.push('/camera/${device.id}'),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
