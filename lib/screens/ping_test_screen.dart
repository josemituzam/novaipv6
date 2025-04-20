import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:dart_ping/dart_ping.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

class PingTestScreen extends StatefulWidget {
  const PingTestScreen({super.key});

  @override
  State<PingTestScreen> createState() => _PingTestScreenState();
}

class _PingTestScreenState extends State<PingTestScreen> {
  List<Map<String, String>> testIps = [];
  Map<String, String> results = {};
  bool wakelockEnabled = true;
  String ipInfo = 'Buscando IP pública...';
  String? selectedIp;
  TextEditingController customIpController = TextEditingController();
  bool isCustomSelected = false;
  int pingCount = 4;
  CancellationToken? _token;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    customIpController.addListener(() => setState(() {}));
    _initFlow();
  }

  Future<void> _initFlow() async {
    await getIpPublic();
    await _loadIps();
  }

  Future<void> getIpPublic() async {
    String ip4 = 'Desconocida';
    String ip6 = 'No disponible';

    try {
      final res4 = await http.get(Uri.parse('https://ipv4.icanhazip.com'));
      ip4 = res4.body.trim();
    } catch (_) {}

    try {
      final res6 = await http.get(Uri.parse('https://ipv6.icanhazip.com'));
      ip6 = res6.body.trim();
    } catch (_) {}

    setState(() {
      ipInfo = 'IPv4 Pública: $ip4\nIPv6 Pública: $ip6';
    });
  }

  Future<void> _loadIps() async {
    final content = await rootBundle.loadString('assets/ping_list.txt');
    final lines = content.split('\n');

    setState(() {
      testIps = lines
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.split(',');
            return {
              'name': parts[0],
              'ip': parts[1],
            };
          }).toList();

      selectedIp = testIps.isNotEmpty ? testIps.first['ip'] : null;
    });
  }

  Future<void> runTests() async {
    _token?.cancel();
    final token = CancellationToken();
    _token = token;

    final ipToTest = isCustomSelected
        ? customIpController.text.trim()
        : selectedIp;

    if (ipToTest == null || ipToTest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Debes seleccionar o ingresar una IP.")),
      );
      return;
    }

    setState(() {
      results.clear();
    });

    await getIpPublic();

    for (var entry in testIps) {
      if (token.isCancelled) break;

      final ip = entry['ip']!;
      results[ip] = 'Procesando...';
      setState(() {});

      try {
        final ping = Ping(ip, count: pingCount, timeout: 2);
        int success = 0;
        int totalTime = 0;

        await for (final response in ping.stream) {
          if (token.isCancelled) break;
          if (response.response != null) {
            success++;
            totalTime += response.response!.time!.inMilliseconds;
          }
        }

        if (token.isCancelled) break;

        if (success > 0) {
          final avg = (totalTime / success).round();
          results[ip] = 'OK ($avg ms)';
        } else {
          results[ip] = 'FALLA';
        }
      } catch (e) {
        results[ip] = 'FALLA';
      }

      setState(() {});
    }

    if (!token.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Pruebas de Ping completadas'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void toggleWakelock(bool enable) {
    setState(() {
      wakelockEnabled = enable;
      enable ? WakelockPlus.enable() : WakelockPlus.disable();
    });
  }

  Color _getColorFromText(String value) {
    if (value.contains('OK')) return Colors.green;
    if (value.contains('FALLA')) return Colors.red;
    if (value.contains('Procesando')) return Colors.orange;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Ping'),
        actions: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Pantalla activa"),
              ),
              Switch(value: wakelockEnabled, onChanged: toggleWakelock),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: runTests,
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(ipInfo, style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              value: isCustomSelected ? 'personalizado' : selectedIp,
              items: [
                ...testIps.map((entry) => DropdownMenuItem(
                      value: entry['ip'],
                      child: Text(entry['name'] ?? entry['ip'] ?? 'Desconocido'),
                    )),
                const DropdownMenuItem(
                  value: 'personalizado',
                  child: Text('IP personalizada'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  if (value == 'personalizado') {
                    isCustomSelected = true;
                  } else {
                    isCustomSelected = false;
                    selectedIp = value;
                    customIpController.clear();
                  }
                });
              },
              isExpanded: true,
              hint: const Text("Selecciona una IP"),
            ),
            const SizedBox(height: 8),
            if (isCustomSelected)
              TextField(
                controller: customIpController,
                decoration: const InputDecoration(
                  labelText: "Escribe una IP personalizada",
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text("Cantidad de pings: "),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: pingCount,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        pingCount = value;
                      });
                    }
                  },
                  items: [1, 3, 4, 5, 10].map((val) {
                    return DropdownMenuItem<int>(
                      value: val,
                      child: Text('$val'),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.network_ping),
              label: const Text("Iniciar pruebas"),
              onPressed: runTests,
            ),
            const Divider(),
            Expanded(
              child: testIps.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: testIps.length,
                      itemBuilder: (context, index) {
                        final ip = testIps[index]['ip']!;
                        final name = testIps[index]['name']!;
                        final result = results[ip] ?? '...';
                        return ListTile(
                          title: Text(name),
                          subtitle: Text(ip),
                          trailing: Text(
                            result,
                            style: TextStyle(
                              color: _getColorFromText(result),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
