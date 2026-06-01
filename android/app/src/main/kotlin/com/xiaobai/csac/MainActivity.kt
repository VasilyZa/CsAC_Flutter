package com.xiaobai.csac

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import java.security.cert.X509Certificate
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManager
import javax.net.ssl.X509TrustManager
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Headers
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import java.io.IOException

class MainActivity : FlutterFragmentActivity() {
    private val httpClient: OkHttpClient by lazy { createUnsafeHttp2Client() }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "csac/android_http")
            .setMethodCallHandler { call, result ->
                if (call.method != "send") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                sendHttp(call.arguments as? Map<*, *>, result)
            }
    }

    private fun sendHttp(args: Map<*, *>?, result: MethodChannel.Result) {
        if (args == null) {
            result.error("bad_args", "Missing request arguments.", null)
            return
        }
        val method = args["method"] as? String ?: "GET"
        val url = args["url"] as? String
        if (url.isNullOrBlank()) {
            result.error("bad_url", "Missing request URL.", null)
            return
        }
        val headers = Headers.Builder()
        (args["headers"] as? Map<*, *>)?.forEach { (key, value) ->
            val name = key?.toString()?.trim().orEmpty()
            val headerValue = value?.toString().orEmpty()
            if (name.isNotEmpty()) {
                headers.set(name, headerValue)
            }
        }
        val bytes = args["body"] as? ByteArray ?: ByteArray(0)
        val contentType = headers["content-type"]?.toMediaTypeOrNull()
        val body = if (method == "GET" || method == "HEAD") {
            null
        } else {
            bytes.toRequestBody(contentType)
        }
        val request = Request.Builder()
            .url(url)
            .headers(headers.build())
            .method(method, body)
            .build()
        httpClient.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                result.error("network_error", e.message, null)
            }

            override fun onResponse(call: Call, response: Response) {
                response.use {
                    val responseHeaders = mutableMapOf<String, String>()
                    for (name in it.headers.names()) {
                        responseHeaders[name.lowercase()] = it.headers.values(name).joinToString(",")
                    }
                    result.success(
                        mapOf(
                            "statusCode" to it.code,
                            "reasonPhrase" to it.message,
                            "headers" to responseHeaders,
                            "body" to (it.body?.bytes() ?: ByteArray(0)),
                            "protocol" to it.protocol.toString(),
                        )
                    )
                }
            }
        })
    }

    private fun createUnsafeHttp2Client(): OkHttpClient {
        val trustManager = object : X509TrustManager {
            override fun checkClientTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
            override fun checkServerTrusted(chain: Array<out X509Certificate>?, authType: String?) {}
            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
        }
        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(null, arrayOf<TrustManager>(trustManager), SecureRandom())
        return OkHttpClient.Builder()
            .sslSocketFactory(sslContext.socketFactory, trustManager)
            .hostnameVerifier { _, _ -> true }
            .protocols(listOf(Protocol.HTTP_2, Protocol.HTTP_1_1))
            .build()
    }
}
