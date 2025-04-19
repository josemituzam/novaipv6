import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import '../models/test_result.dart';
import '../models/ping_result.dart';
import '../services/test_service.dart';

class TestScreen extends StatefulWidget {
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<Map<String, String>> testUrls = [];
  Map<String, TestResult> results = {};
  bool wakelockEnabled = true;
  String ipInfo = 'Buscando IP pública...';

  @override
void initState() {
  super.initState();
  WakelockPlus.enable();
  _initFlow();
}

Future<void> _initFlow() async {
  await getIpPublic();   // 1. Primero obtiene IPs públicas
  await _loadUrls();     // 2. Luego carga los dominios desde el txt
  await runTests();      // 3. Finalmente corre las pruebas HTTP
}


  Future<void> _loadUrls() async {
    final content = await rootBundle.loadString('assets/http_list.csv');
    final lines = content.split('\n');

    setState(() {
      testUrls = lines
          .where((line) => line.trim().isNotEmpty)
          .map((line) {
            final parts = line.split(',');
            return {
              'name': parts[0],
              'ipv4': parts[1],
              'ipv6': parts[2],
            };
          }).toList();
    });
  }

  Future<void> runTests() async {
    for (var test in testUrls) {
      final name = test['name']!;
      setState(() {
        results[name] = TestResult('Procesando...', 'Procesando...');
      });

      final ipv4 = await checkHttp(test['ipv4']!);
      final ipv6 = await checkHttpIPv6Forced(test['ipv6']!);

      setState(() {
        results[name] = TestResult('${ipv4.result} (${ipv4.ms} ms)', '${ipv6.result} (${ipv6.ms} ms)');
      });

      await Future.delayed(const Duration(milliseconds: 250));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Pruebas completadas'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> getIpPublic() async {
    try {
      final ipv4 = await http.get(Uri.parse('https://ipv4.icanhazip.com'));
      final ipv6 = await http.get(Uri.parse('https://ipv6.icanhazip.com'));
      final ip4 = ipv4.body.trim();
      final ip6 = ipv6.body.trim();
      setState(() {
        ipInfo = 'IPv4 Pública: $ip4\nIPv6 Pública: $ip6';
      });
    } catch (e) {
      String ip4 = 'Desconocida';
String ip6 = 'No disponible';

try {
  final ipv4 = await http.get(Uri.parse('https://ipv4.icanhazip.com'));
  ip4 = ipv4.body.trim();
} catch (_) {}

try {
  final ipv6 = await http.get(Uri.parse('https://ipv6.icanhazip.com'));
  ip6 = ipv6.body.trim();
} catch (_) {}

setState(() {
  ipInfo = 'IPv4 Pública: $ip4\nIPv6 Pública: $ip6';
});
    }
  }

  void toggleWakelock(bool enable) {
    setState(() {
      wakelockEnabled = enable;
      if (enable) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de IPv4 e IPv6'),
        actions: [
          Row(
            children: [
              const Text("Pantalla activa"),
              Switch(
                value: wakelockEnabled,
                onChanged: toggleWakelock,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  runTests();
                  getIpPublic();
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(ipInfo, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            child: testUrls.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 20.0,
                        columns: const [
                          DataColumn(label: Text('Dominio')),
                          DataColumn(label: Text('IPv4')),
                          DataColumn(label: Text('IPv6')),
                        ],
                        rows: testUrls.map((test) {
                          final name = test['name']!;
                          final result = results[name] ?? TestResult('...', '...');
                          return DataRow(cells: [
                            DataCell(SizedBox(width: 160, child: Text(name))),
                            DataCell(SizedBox(width: 140, child: Text(result.ipv4))),
                            DataCell(SizedBox(width: 140, child: Text(result.ipv6))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
