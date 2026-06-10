import 'package:flutter/material.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HW_WIDGETS',
      routerConfig: router,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111111),
          elevation: 0,
        ),
      ),
       builder: (context, child) => AppTheme(child: child!),
    );
  }
}
