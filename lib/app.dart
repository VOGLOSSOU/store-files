import 'package:flutter/material.dart';
import 'features/home/screens/home_screen.dart';
import 'shared/theme/app_theme.dart';

class DocManagerApp extends StatelessWidget {
  const DocManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Classeur',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
