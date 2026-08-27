import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RKTokens>(
      valueListenable: themeNotifier,
      builder: (context, tokens, _) {
        return MaterialApp.router(
          title: 'HW_WIDGETS',
          routerConfig: router,
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: tokens.surface,
            appBarTheme: AppBarTheme(
              backgroundColor: tokens.base300,
              elevation: 0,
            ),
          ),
          builder: (context, child) => AppTheme(child: child!),
        );
      },
    );
  }
}
