import 'package:go_router/go_router.dart';

import 'screens/demo_screen.dart';

final GoRouter router = GoRouter(
  initialLocation: '/buttons',
  routes: [
    GoRoute(
      path: '/buttons',
      builder: (context, state) => const DemoScreen(selectedIndex: 0),
    ),
    GoRoute(
      path: '/multiple',
      builder: (context, state) => const DemoScreen(selectedIndex: 1),
    ),
    GoRoute(
      path: '/switches',
      builder: (context, state) => const DemoScreen(selectedIndex: 2),
    ),
    GoRoute(
      path: '/sliders',
      builder: (context, state) => const DemoScreen(selectedIndex: 3),
    ),
    GoRoute(
      path: '/knobs',
      builder: (context, state) => const DemoScreen(selectedIndex: 4),
    ),
    GoRoute(
      path: '/joysticks',
      builder: (context, state) => const DemoScreen(selectedIndex: 5),
    ),
    GoRoute(
      path: '/display',
      builder: (context, state) => const DemoScreen(selectedIndex: 6),
    ),
    GoRoute(
      path: '/leds',
      builder: (context, state) => const DemoScreen(selectedIndex: 7),
    ),
  ],
);
