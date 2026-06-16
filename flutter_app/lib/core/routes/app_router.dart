import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/dev/theme_preview_screen.dart';
import '../../screens/generation_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/saved/saved_screen.dart';
import '../../screens/settings/advanced_lg_controls_screen.dart';
import '../../screens/settings/language_screen.dart';
import '../../screens/settings/lg_connection_screen.dart';
import '../../screens/settings/theme_screen.dart';
import '../../screens/settings/tour_preferences_screen.dart';
import '../../screens/tours/tours_screen.dart';
import 'scaffold_with_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App navigation: a 4-tab bottom-nav shell (Home · Saved · Tours · Profile)
/// with generation / settings / dev routes pushed on top of it.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              builder: (context, state) => const SavedScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tours',
              builder: (context, state) => const ToursScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),

    // Pushed over the shell (full-screen, no bottom nav).
    GoRoute(
      path: '/generation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final prompt = state.extra as String? ?? 'A beautiful random tour';
        return GenerationScreen(prompt: prompt);
      },
    ),
    GoRoute(
      path: '/settings/lg',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LgConnectionScreen(),
    ),
    GoRoute(
      path: '/settings/advanced',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AdvancedLgControlsScreen(),
    ),
    GoRoute(
      path: '/settings/preferences',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TourPreferencesScreen(),
    ),
    GoRoute(
      path: '/settings/language',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/settings/theme',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ThemeScreen(),
    ),
    GoRoute(
      path: '/theme-preview',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ThemePreviewScreen(),
    ),
  ],
);
