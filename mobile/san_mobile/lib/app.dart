import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'features/shell/app_shell.dart';
import 'features/map/aid_map_page.dart';


final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _GoRouterRefresh(ref),
    redirect: (context, state) {
      final loggedIn = authState.token != null && authState.user != null;

      final loc = state.matchedLocation;
      final goingToLogin = loc == '/login';
      final goingToRegister = loc == '/register';
      final goingToGuestMap = loc == '/map';
      final goingToGuestPps = loc == '/pps-booking';

      // Allow guest map and pps booking without login
      if (!loggedIn && !(goingToLogin || goingToRegister || goingToGuestMap || goingToGuestPps)) {
        return '/login';
      }

      // If logged in and trying to go to login/register, go to app shell
      if (loggedIn && (goingToLogin || goingToRegister)) {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const AidMapPage(isGuest: true),
      ),
      GoRoute(
        path: '/pps-booking',
        builder: (context, state) => const AidMapPage(
          isGuest: true,
          initialGuestTab: 1,
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => AppShell(),
      ),
    ],
  );
});

class _GoRouterRefresh extends ChangeNotifier {
  _GoRouterRefresh(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
