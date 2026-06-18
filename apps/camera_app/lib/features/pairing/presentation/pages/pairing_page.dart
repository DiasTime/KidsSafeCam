import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Camera-side pairing screen: requests a code and shows it for the parent to
/// enter in their app. The code is short-lived; "New code" mints another.
class PairingPage extends ConsumerWidget {
  const PairingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeAsync = ref.watch(pairingCodeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pair with parent')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: codeAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56),
                const SizedBox(height: 12),
                Text(pairingErrorMessage(e), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(pairingCodeProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
            data: (pairing) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter this code in the parent app:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SelectableText(
                  pairing.code,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: pairing.code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied')),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy'),
                ),
                const SizedBox(height: 8),
                Text(
                  'This code expires in about 5 minutes.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => ref.invalidate(pairingCodeProvider),
                  child: const Text('New code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
