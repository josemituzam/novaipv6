import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import '../models/test_result.dart';
import '../models/ping_result.dart';
import '../services/test_service.dart';

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

class TestScreen extends StatefulWidget {
  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<Map<String, String>> testUrls = [];
  Map<String, TestResult> results = {};
  bool wakelockEnabled = true;
  String ipInfo = 'Buscando IP pública...';
  bool _isRunningTests = false;
  int _currentRunId = 0;
  CancellationToken? _token;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initFlow();
  }

  Future<void> _initFlow() async {
    await getIpPublic();
    await _loadUrls();
    await runTests();
  }

  Future<void> _loadUrls() async {
    final content = await rootBundle.loadString('assets/http_list.txt');
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
    final int runId = ++_currentRunId;
    _token = CancellationToken();

    setState(() {
      _isRunningTests = true;
      results.clear();
    });

    for (var test in testUrls) {
      if (!_isRunningTests || runId != _currentRunId || _token!.isCancelled) break;
      final name = test['name']!;
      setState(() {
        results[name] = TestResult('Procesando...', 'Procesando...');
      });

      final ipv4 = await checkHttp(test['ipv4']!);
      if (_token!.isCancelled) break;

      final ipv6 = await checkHttpIPv6Forced(test['ipv6']!);
      if (_token!.isCancelled) break;

      setState(() {
        results[name] = TestResult('${ipv4.result} (${ipv4.ms} ms)', '${ipv6.result} (${ipv6.ms} ms)');
      });

      await Future.delayed(const Duration(milliseconds: 250));
      if (_token!.isCancelled) break;
    }

    if (_isRunningTests && runId == _currentRunId && !_token!.isCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pruebas completadas'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    setState(() {
      _isRunningTests = false;
    });
  }

  Future<void> getIpPublic() async {
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

  Widget _styledResultText(String value) {
    Color color = Colors.grey;
    if (value.contains('OK')) color = Colors.green;
    if (value.contains('FALLA')) color = Colors.red;
    if (value.contains('Procesando')) color = Colors.orange;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Text(
        value,
        key: ValueKey(value),
        style: TextStyle(color: color),
      ),
    );
  }

  void _restartTests() async {
    _token?.cancel();
    setState(() {
      _isRunningTests = false;
      results.clear();
    });
    await Future.delayed(const Duration(milliseconds: 100));
    await _initFlow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de IPv4 e IPv6'),
        actions: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Text("Pantalla activa"),
              ),
              Switch(
                value: wakelockEnabled,
                onChanged: toggleWakelock,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Reiniciar pruebas',
                onPressed: _restartTests,
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
                      child: Text(
                        ipInfo,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: testUrls.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                          columns: const [
                            DataColumn(label: Text('🌐 Dominio', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('📡 IPv4', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('🛰️ IPv6', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: testUrls.map((test) {
                            final name = test['name']!;
                            final result = results[name] ?? TestResult('...', '...');
                            return DataRow(
                              cells: [
                                DataCell(SizedBox(width: 160, child: Text(name))),
                                DataCell(SizedBox(width: 140, child: _styledResultText(result.ipv4))),
                                DataCell(SizedBox(width: 140, child: _styledResultText(result.ipv6))),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}