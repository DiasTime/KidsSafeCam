import 'package:ai_baby_monitor_shared/ai_baby_monitor_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/pairing/presentation/pages/pairing_page.dart';
import '../features/streaming/presentation/pages/camera_home_page.dart';

/// Auth-gated router for the Camera app. Redirects unauthenticated users to
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
        builder: (context, state) =>
            const LoginPage(title: 'Baby Monitor — Camera'),
      ),
      GoRoute(path: '/', builder: (context, state) => const CameraHomePage()),
      GoRoute(path: '/pair', builder: (context, state) => const PairingPage()),
    ],
  );
});
