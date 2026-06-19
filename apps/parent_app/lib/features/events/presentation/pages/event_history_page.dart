import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Event-history screen (route `/events`) for the Parent app. Lists the
/// detected events (cry, fall, motion, …) the backend recorded for the
/// signed-in user, newest first.
class EventHistoryPage extends ConsumerWidget {
  const EventHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Empty(
          icon: Icons.error_outline,
          title: 'Could not load activity',
          subtitle: '$e',
        ),
        data: (list) {
          if (list.isEmpty) {
            return const _Empty(
              icon: Icons.history,
              title: 'No activity yet',
              subtitle: 'Cry, fall and motion events will appear here.',
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _EventTile(event: list[i]),
          );
        },
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final BabyEvent event;

  @override
  Widget build(BuildContext context) {
    final display = _displayFor(event.type);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: display.color.withValues(alpha: 0.15),
        child: Icon(display.icon, color: display.color),
      ),
      title: Text(display.label),
      subtitle: Text(_formatTime(event.timestamp)),
    );
  }
}

({IconData icon, String label, Color color}) _displayFor(BabyEventType type) {
  switch (type) {
    case BabyEventType.babyCry:
      return (icon: Icons.volume_up, label: 'Baby crying', color: Colors.orange);
    case BabyEventType.fallDetected:
      return (
        icon: Icons.warning_amber_rounded,
        label: 'Possible fall',
        color: Colors.red
      );
    case BabyEventType.motionDetected:
      return (
        icon: Icons.directions_run,
        label: 'Motion detected',
        color: Colors.blue
      );
    case BabyEventType.soundDetected:
      return (
        icon: Icons.hearing,
        label: 'Loud sound',
        color: Colors.purple
      );
    case BabyEventType.connectionLost:
      return (
        icon: Icons.wifi_off,
        label: 'Camera offline',
        color: Colors.grey
      );
  }
}

String _formatTime(DateTime t) {
  final local = t.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year && local.month == now.month && local.day == now.day;
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (sameDay) return 'Today $hh:$mm';
  final dd = local.day.toString().padLeft(2, '0');
  final mon = local.month.toString().padLeft(2, '0');
  return '$dd/$mon $hh:$mm';
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.subtitle});

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
