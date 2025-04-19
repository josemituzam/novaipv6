import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../services/native_gateway_service.dart';

class LocalDiagnosticScreen extends StatefulWidget {
  const LocalDiagnosticScreen({super.key});

  @override
  State<LocalDiagnosticScreen> createState() => _LocalDiagnosticScreenState();
}

class _LocalDiagnosticScreenState extends State<LocalDiagnosticScreen> {
  String? ipv4Gateway;
  String? ipv6Gateway;
  String ipv4Result = 'Esperando...';
  String ipv6Result = 'Esperando...';

  @override
  void initState() {
    super.initState();
    _loadGateways().then((_) => _runDiagnostics());
  }

  Future<void> _loadGateways() async {
    final info = NetworkInfo();
    final gateway = await info.getWifiGatewayIP();
    final ipv6 = await NativeGatewayService.getIPv6Gateway();

    setState(() {
      ipv4Gateway = gateway;
      ipv6Gateway = ipv6;
    });
  }

  Future<void> _runDiagnostics() async {
    setState(() {
      ipv4Result = 'Procesando...';
      ipv6Result = 'Procesando...';
    });

    int success4 = 0;
    int success6 = 0;
    int totalLatency4 = 0;
    int totalLatency6 = 0;

    try {
      if (ipv4Gateway != null) {
        final pingIPv4 = Ping(ipv4Gateway!, count: 4);
        await for (final event in pingIPv4.stream) {
          if (event.response?.time != null) {
            success4++;
            totalLatency4 += event.response!.time!.inMilliseconds;
          }
        }
      }
    } catch (_) {
      ipv4Result = 'FALLA';
    }

    try {
      if (ipv6Gateway != null) {
        final pingIPv6 = Ping(ipv6Gateway!, count: 4, ipv6: true);
        await for (final event in pingIPv6.stream) {
          if (event.response?.time != null) {
            success6++;
            totalLatency6 += event.response!.time!.inMilliseconds;
          }
        }
      }
    } catch (_) {
      ipv6Result = 'FALLA';
    }

    setState(() {
      ipv4Result = (ipv4Gateway == null)
          ? 'No disponible'
          : (success4 > 0
              ? 'OK (${(totalLatency4 / success4).toStringAsFixed(1)} ms promedio)'
              : 'FALLA');
      ipv6Result = (ipv6Gateway == null)
          ? 'No disponible'
          : (success6 > 0
              ? 'OK (${(totalLatency6 / success6).toStringAsFixed(1)} ms promedio)'
              : 'FALLA');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico Local'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadGateways();
              _runDiagnostics();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ping a Gateway Local', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('IPv4 (${ipv4Gateway ?? 'N/A'}): '),
                const SizedBox(width: 10),
                Text(ipv4Result, style: TextStyle(color: ipv4Result.startsWith('OK') ? Colors.green : Colors.red))
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('IPv6 (${ipv6Gateway ?? 'N/A'}): '),
                const SizedBox(width: 10),
                Text(ipv6Result, style: TextStyle(color: ipv6Result.startsWith('OK') ? Colors.green : Colors.red))
              ],
            ),
          ],
        ),
      ),
      
    );
  }
}
