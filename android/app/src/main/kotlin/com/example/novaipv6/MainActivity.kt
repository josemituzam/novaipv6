package com.example.novaipv6

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.novaipv6/network"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result ->
            when (call.method) {
                "resolve" -> {
                    val domain = call.argument<String>("domain")
                    val type = call.argument<String>("type")
                    val dnsServer = call.argument<String>("dnsServer")
                    // Aquí deberías incluir la lógica de resolución DNS si ya la usas.
                    result.notImplemented() // Mantener hasta que la lógica esté lista.
                }
                "getIPv6Gateway" -> {
                    val gateway = getIPv6Gateway()
                    result.success(gateway)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getIPv6Gateway(): String? {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        val networks = cm.allNetworks
        for (network in networks) {
            val caps = cm.getNetworkCapabilities(network)
            if (caps != null && caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)) {
                val props: LinkProperties? = cm.getLinkProperties(network)
                props?.routes?.forEach { route ->
                    val gw = route.gateway
                    if (route.hasGateway() && gw != null && gw.hostAddress?.contains(':') == true) {
                        return gw.hostAddress
                    }
                }
            }
        }
        return null
    }
}
