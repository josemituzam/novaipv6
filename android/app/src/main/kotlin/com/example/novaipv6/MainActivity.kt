// package com.example.novaipv6

//import io.flutter.embedding.android.FlutterActivity

//class MainActivity : FlutterActivity()

package com.example.novaipv6 // ← Asegúrate de que coincida con tu paquete

import android.net.DnsResolver
import android.os.Build
import android.os.CancellationSignal
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.InetAddress
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "dns_resolver"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "resolveDNS") {
                val domain = call.argument<String>("domain")!!
                val type = call.argument<String>("type")!!
                val dnsServer = call.argument<String>("dnsServer") // opcional (por ahora no lo usaremos directamente)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    resolve(domain, type, result)
                } else {
                    result.error("UNSUPPORTED", "Requires Android 10+", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun resolve(domain: String, type: String, result: MethodChannel.Result) {
        val resolver = DnsResolver.getInstance()
        val signal = CancellationSignal()
        val executor = Executors.newSingleThreadExecutor()

        val recordType = when (type.uppercase()) {
            "A" -> DnsResolver.TYPE_A
            "AAAA" -> DnsResolver.TYPE_AAAA
            else -> {
                result.error("INVALID_TYPE", "Use 'A' or 'AAAA'", null)
                return
            }
        }

        val startTime = System.currentTimeMillis()
        resolver.query(
            null,
            domain,
            recordType,
            DnsResolver.FLAG_NO_CACHE_LOOKUP,
            executor,
            signal,
            object : DnsResolver.Callback<List<InetAddress>> {
                override fun onAnswer(answer: List<InetAddress>, rcode: Int) {
                    val elapsed = System.currentTimeMillis() - startTime
                    val ipList = answer.map { it.hostAddress }
                    result.success(mapOf("ips" to ipList, "latencyMs" to elapsed))
                }

                override fun onError(error: DnsResolver.DnsException) {
                    result.error("DNS_ERROR", error.message, null)
                }
            }
        )
    }
}
