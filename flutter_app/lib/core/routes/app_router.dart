import 'package:go_router/go_router.dart';

import '../../screens/home/home_screen.dart';
import '../../screens/settings/lg_connection_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/settings/lg',
      builder: (context, state) => const LgConnectionScreen(),
    ),
  ],
);
