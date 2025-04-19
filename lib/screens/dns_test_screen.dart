// Archivo actualizado dns_test_screen.dart con mejoras aplicadas
// Versión con resumen de resultados y colores por estado

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import '../services/dns_android_channel.dart';

class DnsTestScreen extends StatefulWidget {
  const DnsTestScreen({super.key});

  @override
  State<DnsTestScreen> createState() => _DnsTestScreenState();
}

class _DnsTestScreenState extends State<DnsTestScreen> {
  List<Map<String, String>> testDomains = [];
  List<Map<String, String?>> dnsServers = [];
  Map<String, Map<String, String>> results = {};
  bool wakelockEnabled = true;
  String ipInfo = 'Buscando IP pública...';
  String? myIPv4;
  String? myIPv6;
  String? selectedDomain;
  TextEditingController customDomainController = TextEditingController();
  bool isCustomSelected = false;
  int okIPv4 = 0;
  int okIPv6 = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    customDomainController.addListener(() => setState(() {}));
    _initFlow();
  }

  void toggleWakelock(bool enable) {
    setState(() {
      wakelockEnabled = enable;
      enable ? WakelockPlus.enable() : WakelockPlus.disable();
    });
  }

  Future<void> _initFlow() async {
    await getIpPublic();
    await _loadLists();
  }

  Future<void> _loadLists() async {
    final dnsList = await rootBundle.loadString('assets/dns_list.txt');
    final domainCsv = await rootBundle.loadString('assets/domains.csv');

    dnsServers = dnsList
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) {
          final parts = line.split(',');
          return {
            'name': parts[0],
            'ipv4': parts[1],
            'ipv6': parts.length > 2 ? parts[2].trim() : null,
          };
        })
        .toList();

    testDomains = domainCsv
        .split('\n')
        .skip(1)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) {
          final parts = line.split(',');
          return {
            'name': parts[0],
            'domain': parts[1],
            'region': parts.length > 2 ? parts[2] : '',
          };
        })
        .toList();

    selectedDomain = testDomains.isNotEmpty ? testDomains.first['domain'] : null;
    setState(() {});
  }

  Future<void> getIpPublic() async {
    String ip4 = 'Desconocida';
    String ip6 = 'No disponible';
    myIPv4 = null;
    myIPv6 = null;

    try {
      final res4 = await http.get(Uri.parse('https://ipv4.icanhazip.com')).timeout(const Duration(seconds: 3));
      ip4 = res4.body.trim();
      myIPv4 = ip4;
    } catch (_) {}

    try {
      final res6 = await http.get(Uri.parse('https://ipv6.icanhazip.com')).timeout(const Duration(seconds: 3));
      ip6 = res6.body.trim();
      myIPv6 = ip6;
    } catch (_) {}

    setState(() {
      ipInfo = 'IPv4 Pública: $ip4\nIPv6 Pública: $ip6';
    });
  }

  Future<void> runTests() async {
    final domainToTest = isCustomSelected ? customDomainController.text.trim() : selectedDomain;

    if (domainToTest == null || domainToTest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Debes seleccionar o ingresar un dominio.")),
      );
      return;
    }

    setState(() {
      results.clear();
      okIPv4 = 0;
      okIPv6 = 0;
    });

    await getIpPublic();

    if (dnsServers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ No hay servidores DNS disponibles.")),
      );
      return;
    }

    for (var server in dnsServers) {
      await _testServer(server, domainToTest);
    }

    final allEmpty = results.values.every((r) => r['ipv4'] == 'FALLA' && r['ipv6'] == 'FALLA');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(allEmpty ? '❌ Ninguna respuesta DNS válida' : '✅ Pruebas DNS completadas'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _testServer(Map<String, String?> server, String domain) async {
    final name = server['name']!;
    results[name] = {'ipv4': 'Procesando...', 'ipv6': 'Procesando...'};
    setState(() {});

    String ipv4Result = 'FALLA';
    String ipv6Result = 'FALLA';

    if (myIPv4 != null && server['ipv4'] != null && server['ipv4']!.isNotEmpty) {
      try {
        final res = await DnsAndroidChannel.resolve(
          domain: domain,
          type: 'A',
          dnsServer: server['ipv4'],
        );
        if ((res['ips'] as List).isNotEmpty) {
          final ip = (res['ips'] as List).first;
          final latency = res['latencyMs'];
          ipv4Result = 'OK (${latency} ms)\n$ip';
          okIPv4++;
        }
      } catch (_) {}
    }

    if (myIPv6 != null && server['ipv6'] != null && server['ipv6']!.isNotEmpty) {
      try {
        final res = await DnsAndroidChannel.resolve(
          domain: domain,
          type: 'AAAA',
          dnsServer: server['ipv6'],
        );
        if ((res['ips'] as List).isNotEmpty) {
          final ip = (res['ips'] as List).first;
          final latency = res['latencyMs'];
          ipv6Result = 'OK (${latency} ms)\n$ip';
          okIPv6++;
        }
      } catch (_) {}
    }

    results[name] = {
      'ipv4': ipv4Result,
      'ipv6': ipv6Result,
    };
    setState(() {});
  }

  Color _getColor(String value) {
    if (value.startsWith('OK')) return Colors.green;
    if (value.startsWith('Procesando')) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final total = dnsServers.length;
    final failIPv4 = total - okIPv4;
    final failIPv6 = total - okIPv6;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test DNS IPv4 e IPv6'),
        actions: [
          Row(
            children: [
              const Text("Pantalla activa"),
              Switch(value: wakelockEnabled, onChanged: toggleWakelock),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: runTests,
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ipInfo, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 10),
                DropdownButton<String>(
                  value: isCustomSelected ? 'personalizado' : selectedDomain,
                  items: [
                    ...testDomains.map((entry) => DropdownMenuItem(
                          value: entry['domain'],
                          child: Text(entry['name'] ?? entry['domain'] ?? 'Desconocido'),
                        )),
                    const DropdownMenuItem(
                      value: 'personalizado',
                      child: Text('Dominio personalizado'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      if (value == 'personalizado') {
                        isCustomSelected = true;
                      } else {
                        isCustomSelected = false;
                        selectedDomain = value;
                        customDomainController.clear();
                      }
                    });
                  },
                  isExpanded: true,
                  hint: const Text("Selecciona un dominio"),
                ),
                const SizedBox(height: 8),
                if (isCustomSelected)
                  TextField(
                    controller: customDomainController,
                    decoration: const InputDecoration(
                      labelText: "Escribe un dominio personalizado",
                      border: OutlineInputBorder(),
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text("Iniciar pruebas"),
                  onPressed: runTests,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: dnsServers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20.0,
                        columns: const [
                          DataColumn(label: Text('Servidor DNS')),
                          DataColumn(label: Text('IPv4')),
                          DataColumn(label: Text('IPv6')),
                        ],
                        rows: dnsServers.map((server) {
                          final name = server['name']!;
                          final res = results[name] ?? {'ipv4': '...', 'ipv6': '...'};
                          return DataRow(cells: [
                            DataCell(SizedBox(width: 160, child: Text(name))),
                            DataCell(SizedBox(
                              width: 140,
                              child: Text(res['ipv4']!, style: TextStyle(color: _getColor(res['ipv4']!))),
                            )),
                            DataCell(SizedBox(
                              width: 140,
                              child: Text(res['ipv6']!, style: TextStyle(color: _getColor(res['ipv6']!))),
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Resultados: IPv4 - OK: $okIPv4 / $total, FALLA: $failIPv4 | IPv6 - OK: $okIPv6 / $total, FALLA: $failIPv6',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
