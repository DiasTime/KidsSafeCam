import 'package:flutter/material.dart';

/// Placeholder home screen for the Camera app.
///
/// Future steps replace this with: pairing UI (Step 4), the WebRTC publisher
/// preview + status (Steps 5-8), background-service controls (Step 9), and the
/// on-device AI indicators (Steps 12-13).
class CameraHomePage extends StatelessWidget {
  const CameraHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Baby Monitor — Camera')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_outlined, size: 72),
              SizedBox(height: 16),
              Text(
                'Camera device',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Sign in and pair with a parent device to begin streaming.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
