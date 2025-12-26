import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/group_details_screen.dart';
import '../../features/dashboard/presentation/screens/join_group_screen.dart';
import '../../features/dashboard/domain/entities/group.dart';

/// Router configuration with authentication
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      // 1. If loading, go to Splash
      if (authState.isLoading || authState.hasError) {
        return '/splash';
      }

      // Handle custom scheme deep links like contri://join/xyz
      final uri = state.uri;
      if (uri.scheme == 'contri' && uri.host == 'join') {
        final segments = uri.pathSegments;
        final groupId = segments.isNotEmpty ? segments.first : '';
        if (groupId.isNotEmpty) {
          return '/join/$groupId';
        }
      }

      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      // 2. If Auth Loaded:
      if (!isLoggedIn) {
        // Redirect unauthenticated users to login (MVP: we do not preserve the deep link)
        return isLoggingIn ? null : '/login';
      }

      if (isLoggedIn && (isLoggingIn || isSplash)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/group-details',
        name: 'groupDetails',
        builder: (context, state) {
          // Pass the Group object via 'extra'
          final group = state.extra as Group;
          return GroupDetailsScreen(group: group);
        },
      ),
      GoRoute(
        path: '/join/:groupId',
        name: 'join_group',
        builder: (context, state) => JoinGroupScreen(
          groupId: state.pathParameters['groupId']!,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Error: ${state.error}'),
      ),
    ),
  );
});
