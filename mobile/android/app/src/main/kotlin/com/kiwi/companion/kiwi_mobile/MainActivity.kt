package com.kiwi.companion.kiwi_mobile

import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.kiwi.companion/wifi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val connectivityManager = getSystemService(android.content.Context.CONNECTIVITY_SERVICE) as android.net.ConnectivityManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getConnectedWifiSsid" -> {
                    try {
                        var ssid: String? = null
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                            for (network in connectivityManager.allNetworks) {
                                val caps = connectivityManager.getNetworkCapabilities(network)
                                if (caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                                    val transportInfo = caps.transportInfo
                                    if (transportInfo is android.net.wifi.WifiInfo) {
                                        val s = transportInfo.ssid
                                        if (s != null && s.isNotEmpty() && s != "<unknown ssid>") {
                                            ssid = s.replace("\"", "").trim()
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        if (ssid == null || ssid.isEmpty() || ssid == "<unknown ssid>") {
                            val wifiManager = applicationContext.getSystemService(android.content.Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                            @Suppress("DEPRECATION")
                            val info = wifiManager?.connectionInfo
                            val s = info?.ssid
                            if (s != null && s.isNotEmpty() && s != "<unknown ssid>") {
                                ssid = s.replace("\"", "").trim()
                            }
                        }
                        result.success(if (ssid != null && ssid.isNotEmpty() && ssid != "<unknown ssid>") ssid else null)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "getConnectedWifiBssid" -> {
                    try {
                        var bssid: String? = null
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                            for (network in connectivityManager.allNetworks) {
                                val caps = connectivityManager.getNetworkCapabilities(network)
                                if (caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                                    val transportInfo = caps.transportInfo
                                    if (transportInfo is android.net.wifi.WifiInfo) {
                                        val b = transportInfo.bssid
                                        if (b != null && b.isNotEmpty() && b != "02:00:00:00:00:00") {
                                            bssid = b
                                            break
                                        }
                                    }
                                }
                            }
                        }
                        if (bssid == null || bssid.isEmpty() || bssid == "02:00:00:00:00:00") {
                            val wifiManager = applicationContext.getSystemService(android.content.Context.WIFI_SERVICE) as? android.net.wifi.WifiManager
                            @Suppress("DEPRECATION")
                            val info = wifiManager?.connectionInfo
                            val b = info?.bssid
                            if (b != null && b.isNotEmpty() && b != "02:00:00:00:00:00") {
                                bssid = b
                            }
                        }
                        result.success(bssid)
                    } catch (e: Exception) {
                        result.success(null)
                    }
                }
                "openWifiSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_WIFI_SETTINGS)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Cannot open Wi-Fi settings: ${e.message}", null)
                    }
                }
                "bindProcessToWifi" -> {
                    try {
                        var bound = false
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            for (network in connectivityManager.allNetworks) {
                                val caps = connectivityManager.getNetworkCapabilities(network)
                                if (caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                                    connectivityManager.bindProcessToNetwork(network)
                                    bound = true
                                    break
                                }
                            }
                        }
                        result.success(bound)
                    } catch (e: Exception) {
                        result.error("BIND_ERROR", e.message, null)
                    }
                }
                "unbindProcess" -> {
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                            connectivityManager.bindProcessToNetwork(null)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UNBIND_ERROR", e.message, null)
                    }
                }
                "wifiHttpRequest" -> {
                    val urlString = call.argument<String>("url") ?: run {
                        result.error("INVALID_ARGS", "URL required", null)
                        return@setMethodCallHandler
                    }
                    val method = call.argument<String>("method") ?: "GET"
                    val body = call.argument<String>("body")
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: 3500

                    kotlin.concurrent.thread {
                        try {
                            var wifiNetwork: android.net.Network? = null
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                                for (net in connectivityManager.allNetworks) {
                                    val caps = connectivityManager.getNetworkCapabilities(net)
                                    if (caps != null && caps.hasTransport(android.net.NetworkCapabilities.TRANSPORT_WIFI)) {
                                        wifiNetwork = net
                                        break
                                    }
                                }
                            }

                            val url = java.net.URL(urlString)
                            val conn = (if (wifiNetwork != null && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                                wifiNetwork.openConnection(url)
                            } else {
                                url.openConnection()
                            }) as java.net.HttpURLConnection

                            conn.requestMethod = method
                            conn.connectTimeout = timeoutMs
                            conn.readTimeout = timeoutMs
                            conn.setRequestProperty("Content-Type", "application/json")
                            conn.setRequestProperty("Accept", "application/json")
                            conn.instanceFollowRedirects = false

                            if (body != null && (method == "POST" || method == "PUT")) {
                                conn.doOutput = true
                                val bytes = body.toByteArray(Charsets.UTF_8)
                                conn.setFixedLengthStreamingMode(bytes.size)
                                conn.outputStream.use { os ->
                                    os.write(bytes)
                                    os.flush()
                                }
                            }

                            val code = conn.responseCode
                            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                            val respBody = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""

                            runOnUiThread {
                                result.success(mapOf(
                                    "statusCode" to code,
                                    "body" to respBody
                                ))
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("HTTP_ERROR", e.javaClass.simpleName + ": " + (e.message ?: "Connection failed"), null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
