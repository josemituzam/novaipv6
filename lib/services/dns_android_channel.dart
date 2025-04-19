import 'package:flutter/services.dart';

class DnsAndroidChannel {
  static const MethodChannel _channel = MethodChannel('dns_resolver');

  static Future<Map<String, dynamic>> resolve({
    required String domain,
    required String type, // 'A' o 'AAAA'
    String? dnsServer,
  }) async {
    final result = await _channel.invokeMethod('resolveDNS', {
      'domain': domain,
      'type': type,
      'dnsServer': dnsServer,
    });
    return Map<String, dynamic>.from(result);
  }
}
