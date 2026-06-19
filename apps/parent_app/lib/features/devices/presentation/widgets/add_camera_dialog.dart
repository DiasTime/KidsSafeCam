import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dialog where the parent enters the code shown on the camera to pair it.
/// On success the device appears in the list via the realtime `devicesProvider`.
class AddCameraDialog extends ConsumerStatefulWidget {
  const AddCameraDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AddCameraDialog(),
    );
  }

  @override
  ConsumerState<AddCameraDialog> createState() => _AddCameraDialogState();
}

class _AddCameraDialogState extends ConsumerState<AddCameraDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    final ok = await ref.read(claimControllerProvider.notifier).claim(code);
    if (ok && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Camera paired')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(claimControllerProvider);
    final isLoading = state.isLoading;

    ref.listen<AsyncValue<String?>>(claimControllerProvider, (_, next) {
      if (next.hasError && !next.isLoading) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(content: Text(pairingErrorMessage(next.error!))),
          );
      }
    });

    return AlertDialog(
      title: const Text('Add camera'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Open the camera app, tap "Pair with parent", and enter the code shown.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !isLoading,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Pairing code',
              hintText: 'e.g. AB7K2M9P',
            ),
            onSubmitted: (_) => isLoading ? null : _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Pair'),
        ),
      ],
    );
  }
}
