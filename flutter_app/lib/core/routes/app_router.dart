import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/saved_tour.dart';
import '../../models/tour_flow.dart';
import '../../screens/dev/theme_preview_screen.dart';
import '../../screens/generation_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/profile/about_screen.dart';
import '../../screens/profile/help_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/saved/saved_detail_screen.dart';
import '../../screens/saved/saved_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/settings/advanced_lg_controls_screen.dart';
import '../../screens/settings/language_screen.dart';
import '../../screens/settings/lg_connection_screen.dart';
import '../../screens/settings/theme_screen.dart';
import '../../screens/settings/tour_preferences_screen.dart';
import '../../screens/tour/active_tour_screen.dart';
import '../../screens/tour/inspection_screen.dart';
import '../../screens/tour/post_tour_screen.dart';
import '../../screens/tour/preview_screen.dart';
import '../../screens/tours/tours_screen.dart';
import 'scaffold_with_nav.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// App navigation: a 4-tab bottom-nav shell (Home · Saved · Tours · Profile).
/// The tour flow nests under Home, saved-detail under Saved, and help/about
/// under Profile so the bottom nav stays visible (as in the mockups). Settings
/// screens push full-screen over the shell.
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Splash — shown first (full-screen, no bottom nav), then routes to /home.
    GoRoute(
      path: '/',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          ScaffoldWithNav(navigationShell: navigationShell),
      branches: [
        // Home + tour flow
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'generation',
                  builder: (context, state) => GenerationScreen(
                    prompt: state.extra as String? ?? 'A beautiful random tour',
                  ),
                ),
                GoRoute(
                  path: 'preview',
                  builder: (context, state) =>
                      PreviewScreen(args: state.extra as TourFlowArgs),
                ),
                GoRoute(
                  path: 'active',
                  builder: (context, state) =>
                      ActiveTourScreen(args: state.extra as TourFlowArgs),
                ),
                GoRoute(
                  path: 'inspection',
                  builder: (context, state) =>
                      InspectionScreen(args: state.extra as TourFlowArgs),
                ),
                GoRoute(
                  path: 'post-tour',
                  builder: (context, state) =>
                      PostTourScreen(args: state.extra as TourFlowArgs),
                ),
              ],
            ),
          ],
        ),
        // Saved + detail
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/saved',
              builder: (context, state) => const SavedScreen(),
              routes: [
                GoRoute(
                  path: 'detail',
                  builder: (context, state) =>
                      SavedDetailScreen(tour: state.extra as SavedTour),
                ),
              ],
            ),
          ],
        ),
        // Tours
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tours',
              builder: (context, state) => const ToursScreen(),
            ),
          ],
        ),
        // Profile + help/about
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'help',
                  builder: (context, state) => const HelpScreen(),
                ),
                GoRoute(
                  path: 'about',
                  builder: (context, state) => const AboutScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    // Settings — pushed full-screen over the shell (own back button).
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
