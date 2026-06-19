import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/devices/presentation/pages/home_page.dart';
import '../features/live_view/presentation/pages/live_view_page.dart';

/// Auth-gated router for the Parent app. Redirects unauthenticated users to
/// `/login` and signed-in users away from it; refreshes on auth changes.
final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authRepositoryProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loggingIn = state.matchedLocation == '/login';
      if (!loggedIn) return loggingIn ? null : '/login';
      if (loggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/camera/:deviceId',
        builder: (context, state) =>
            LiveViewPage(deviceId: state.pathParameters['deviceId']!),
      ),
    ],
  );
});
