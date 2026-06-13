import 'package:flutter/material.dart';
import 'package:stadium/src/screens/main_navigation_page.dart';
import 'package:stadium/src/theme/app_theme.dart';

class StadiumBookingApp extends StatelessWidget {
  const StadiumBookingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Stadium Booking',
      theme: AppTheme.dark(),
      home: const MainNavigationPage(),
    );
  }
}
