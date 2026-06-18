import 'package:go_router/go_router.dart';

import '../features/devices/presentation/pages/home_page.dart';

/// App routes for the Parent app. Auth-gated redirects and the camera/live-view
/// route are added in Steps 2 and 6.
final parentRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
