import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract class FeatureModule {
  String get id;
  String get title;
  IconData get icon;
  String get routePath;
  bool get isShellBranch => true;
  bool get requiresConnection => false;

  Widget buildScreen(BuildContext context, GoRouterState state);
}
