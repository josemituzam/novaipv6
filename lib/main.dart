import 'package:flutter/material.dart';
import 'screens/menu_screen.dart';

void main() {
  runApp(const NovaIPv6App());
}

class NovaIPv6App extends StatelessWidget {
  const NovaIPv6App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPv6 Network Test',
      home: const MenuScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}