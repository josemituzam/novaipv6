import 'package:flutter/material.dart';
import 'http_test_screen.dart';
import 'dns_test_screen.dart';
import 'ping_test_screen.dart';
import 'traceroute_test_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selecciona una prueba')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => TestScreen()));
            },
            child: const Text('1. Prueba de HTTP IPv4 / IPv6'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DnsTestScreen()));
            },
            child: const Text('2. Prueba de DNS IPv4 / IPv6'),
          ),
          ElevatedButton(
  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PingTestScreen())),
  child: const Text("Test de Ping"),
),
ElevatedButton(
  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TracerouteTestScreen())),
  child: const Text("Test de Traceroute"),
),

        ],
      ),
    );
  }
}