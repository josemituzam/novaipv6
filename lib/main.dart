import 'package:flutter/material.dart';
import 'screens/menu_screen.dart'; // ← Asegúrate que este es el menú correcto

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NovaIPv6',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MenuScreen(), // ← CAMBIA AQUÍ si usabas MenuScreen
    );
  }
}
