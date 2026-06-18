import 'package:go_router/go_router.dart';

import '../features/streaming/presentation/pages/camera_home_page.dart';

/// App routes for the Camera app. Auth-gated redirects are added in Step 2.
final cameraRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const CameraHomePage(),
    ),
  ],
);
