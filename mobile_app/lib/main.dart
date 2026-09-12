import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KiwiApp());
}

class KiwiApp extends StatelessWidget {
  const KiwiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KIWI Trust Anchor',
      debugShowCheckedModeBanner: false,
      theme: KiwiTheme.themeData,
      home: const DashboardScreen(),
    );
  }
}
