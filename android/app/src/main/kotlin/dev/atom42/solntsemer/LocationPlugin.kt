package dev.atom42.solntsemer

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class LocationPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var locationManager: LocationManager? = null
    private var eventSink: EventChannel.EventSink? = null
    private var locationListener: LocationListener? = null
    private var isListening = false

    companion object {
        private const val CHANNEL_METHOD = "dev.atom42.solntsemer/location"
        private const val CHANNEL_EVENT = "dev.atom42.solntsemer/location_stream"
        private const val PERMISSION_REQUEST_CODE = 1001
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        locationManager = context?.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_METHOD)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, CHANNEL_EVENT)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopUpdates()
        context = null
        locationManager = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkStatus" -> result.success(checkStatus())
            "requestPermission" -> {
                // На Android 6+ запрос разрешения делается через Activity, не через Plugin.
                // Здесь просто возвращаем текущий статус.
                result.success(checkStatus())
            }
            "getLastKnown" -> {
                val fix = getLastKnown()
                if (fix != null) {
                    result.success(fix)
                } else {
                    result.success(null)
                }
            }
            "startUpdates" -> {
                val intervalMs = call.argument<Int>("intervalMs") ?: 15000
                startUpdates(intervalMs)
                result.success(null)
            }
            "stopUpdates" -> {
                stopUpdates()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun checkStatus(): String {
        val lm = locationManager ?: return "unknown"
        if (!lm.isProviderEnabled(LocationManager.GPS_PROVIDER) &&
            !lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
            return "service_disabled"
        }
        val hasFine = ContextCompat.checkSelfPermission(
            context!!, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ContextCompat.checkSelfPermission(
            context!!, Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return if (hasFine || hasCoarse) "available" else "permission_denied"
    }

    private fun getLastKnown(): Map<String, Any>? {
        val lm = locationManager ?: return null
        if (ActivityCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return null
        }
        val location = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            ?: lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            ?: return null
        return locationToMap(location)
    }

    private fun startUpdates(intervalMs: Int) {
        if (isListening) return
        val lm = locationManager ?: return
        if (ActivityCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ActivityCompat.checkSelfPermission(context!!, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            return
        }
        locationListener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                eventSink?.success(locationToMap(location))
            }
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(provider: String) {}
            override fun onProviderDisabled(provider: String) {}
        }
        try {
            lm.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                intervalMs.toLong(),
                0f,
                locationListener!!,
                Looper.getMainLooper()
            )
            lm.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                intervalMs.toLong(),
                0f,
                locationListener!!,
                Looper.getMainLooper()
            )
            isListening = true
        } catch (e: SecurityException) {
            eventSink?.error("PERMISSION_DENIED", e.message, null)
        }
    }

    private fun stopUpdates() {
        if (!isListening) return
        val lm = locationManager ?: return
        locationListener?.let { lm.removeUpdates(it) }
        locationListener = null
        isListening = false
    }

    private fun locationToMap(location: Location): Map<String, Any> {
        return mapOf(
            "lat" to location.latitude,
            "lon" to location.longitude,
            "accuracy" to location.accuracy.toDouble(),
            "timestampMs" to location.time
        )
    }

    // EventChannel.StreamHandler
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        stopUpdates()
    }
}
