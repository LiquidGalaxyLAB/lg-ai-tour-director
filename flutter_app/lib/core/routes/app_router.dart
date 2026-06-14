import 'package:go_router/go_router.dart';

import '../../screens/active_tour_screen.dart';
import '../../screens/generation_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/library_screen.dart';
import '../../screens/settings/language_screen.dart';
import '../../screens/settings/lg_connection_screen.dart';
import '../../screens/settings/theme_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/generation',
      builder: (context, state) {
        final prompt = state.extra as String? ?? 'A beautiful random tour';
        return GenerationScreen(prompt: prompt);
      },
    ),
    GoRoute(
      path: '/active_tour',
      builder: (context, state) => const ActiveTourScreen(),
    ),
    GoRoute(
      path: '/library',
      builder: (context, state) => const LibraryScreen(),
    ),
    GoRoute(
      path: '/settings/lg',
      builder: (context, state) => const LgConnectionScreen(),
    ),
    GoRoute(
      path: '/settings/language',
      builder: (context, state) => const LanguageScreen(),
    ),
    GoRoute(
      path: '/settings/theme',
      builder: (context, state) => const ThemeScreen(),
    ),
  ],
);
