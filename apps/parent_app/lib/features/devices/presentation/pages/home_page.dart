import 'package:flutter/material.dart';

/// Placeholder home (camera list) screen for the Parent app.
///
/// Future steps replace this with: the live device list with online/offline
/// status (Step 3), pairing entry (Step 4), and navigation to the live camera
/// view with audio, push-to-talk, and event history (Steps 6-11).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Cameras')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.crib_outlined, size: 72),
              SizedBox(height: 16),
              Text(
                'No cameras yet',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Pair a camera device to start monitoring.',
                textAlign: TextAlign.center,
              ),
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
