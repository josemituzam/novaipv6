import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ping_result.dart';

Future<PingResult> checkHttp(String url) async {
  try {
    final stopwatch = Stopwatch()..start();
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
    stopwatch.stop();
    return PingResult(
      result: response.statusCode == 200 ? 'OK' : 'FAIL',
      ms: stopwatch.elapsedMilliseconds,
    );
  } catch (e) {
    return PingResult(result: 'ERROR', ms: 0);
  }
}

Future<PingResult> checkHttpIPv6Forced(String url) async {
  try {
    final uri = Uri.parse(url);
    final host = uri.host;
    final path = uri.path.isEmpty ? '/' : uri.path;

    final addresses = await InternetAddress.lookup(host, type: InternetAddressType.IPv6);
    if (addresses.isEmpty) {
      return PingResult(result: 'SIN IPV6', ms: 0);
    }

    final ipv6 = addresses.first;

    final socket = await SecureSocket.connect(
      ipv6,
      443,
      timeout: const Duration(seconds: 6),
      onBadCertificate: (_) => true,
      supportedProtocols: ['http/1.1'],
    );

    final request = 'GET $path HTTP/1.1\r\n'
        'Host: $host\r\n'
        'Connection: close\r\n\r\n';

    socket.write(request);
    await socket.flush();

    final stopwatch = Stopwatch()..start();
    final completer = Completer<void>();
    socket.listen((_) {
      if (!completer.isCompleted) {
        stopwatch.stop();
        completer.complete();
      }
    }, onDone: () {
      if (!completer.isCompleted) completer.complete();
    });

    await completer.future;
    socket.destroy();

    return PingResult(result: 'OK', ms: stopwatch.elapsedMilliseconds);
  } catch (e) {
    return PingResult(result: 'SIN IPV6', ms: 0);
  }
}
