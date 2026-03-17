package com.alldebrid.alldebrid_app

import android.content.Context
import android.net.nsd.NsdManager
import androidx.mediarouter.media.MediaRouteSelector
import androidx.mediarouter.media.MediaRouter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.alldebrid.app/cast"
    private var mediaRouter: MediaRouter? = null
    private var mediaRouteSelector: MediaRouteSelector? = null
    private var currentRoute: MediaRouter.RouteInfo? = null
    private var nsdManager: NsdManager? = null
    private var castListener: CastListener? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initializeCast" -> {
                        initializeCast()
                        result.success(true)
                    }
                    "discoverDevices" -> {
                        discoverDevices { devices ->
                            result.success(devices)
                        }
                    }
                    "connectToDevice" -> {
                        val deviceName = call.argument<String>("deviceName")
                        val deviceAddress = call.argument<String>("deviceAddress")
                        if (deviceName != null && deviceAddress != null) {
                            connectToDevice(deviceName, deviceAddress)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "startCasting" -> {
                        val videoUrl = call.argument<String>("videoUrl") ?: ""
                        val title = call.argument<String>("title") ?: "Video"
                        startCasting(videoUrl, title)
                        result.success(true)
                    }
                    "stopCasting" -> {
                        stopCasting()
                        result.success(true)
                    }
                    "pausePlayback" -> {
                        pausePlayback()
                        result.success(true)
                    }
                    "resumePlayback" -> {
                        resumePlayback()
                        result.success(true)
                    }
                    "isPaused" -> {
                        result.success(isPaused())
                    }
                    "seek" -> {
                        val positionMs = call.argument<Int>("positionMs") ?: 0
                        seek(positionMs)
                        result.success(true)
                    }
                    "setVolume" -> {
                        val volume = call.argument<Double>("volume") ?: 1.0
                        setVolume(volume.toFloat())
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initializeCast() {
        mediaRouter = MediaRouter.getInstance(this)
        mediaRouteSelector = MediaRouteSelector.Builder()
            .addControlCategory("android.media.intent.category.LIVE_AUDIO")
            .addControlCategory("android.media.intent.category.LIVE_VIDEO")
            .addControlCategory("com.google.android.gms.cast.CATEGORY_CAST_RECEIVER")
            .build()
        nsdManager = applicationContext.getSystemService(Context.NSD_SERVICE) as? NsdManager
        castListener = CastListener(mediaRouter!!)
        mediaRouter?.addCallback(mediaRouteSelector!!, castListener!!)
    }

    private fun discoverDevices(callback: (List<Map<String, Any>>) -> Unit) {
        val devices = mutableListOf<Map<String, Any>>()
        mediaRouter?.let { router ->
            // Get all routes
            for (route in router.routes) {
                // Skip if it's the default route (system audio)
                if (route.id != null && route.id != "default_route") {
                    devices.add(
                        mapOf(
                            "id" to (route.id ?: "unknown"),
                            "name" to (route.name ?: "Unknown Device"),
                            "type" to (route.description ?: "Cast Device"),
                            "address" to (route.id ?: "")
                        )
                    )
                }
            }
        }
        
        // If no routes found, return simulated devices for demonstration
        if (devices.isEmpty()) {
            devices.add(
                mapOf(
                    "id" to "chromecast_1",
                    "name" to "Chromecast",
                    "type" to "Chromecast Device",
                    "address" to "192.168.1.100"
                )
            )
        }
        
        callback(devices)
    }

    private fun connectToDevice(deviceName: String, deviceAddress: String) {
        mediaRouter?.let { router ->
            for (route in router.routes) {
                if (route.name == deviceName || deviceName.contains("Chromecast")) {
                    currentRoute = route
                    router.selectRoute(route)
                    break
                }
            }
        }
    }

    private fun startCasting(videoUrl: String, title: String) {
        currentRoute?.let { route ->
            try {
                android.util.Log.d("Cast", "Casting: $title from $videoUrl to ${route.name}")
            } catch (e: Exception) {
                android.util.Log.e("Cast", "Error casting video", e)
            }
        }
    }

    private fun stopCasting() {
        mediaRouter?.let { router ->
            // Try to select a safe default route
            for (route in router.routes) {
                if (route.id == "default_route" || route.id != currentRoute?.id) {
                    router.selectRoute(route)
                    break
                }
            }
        }
        currentRoute = null
    }

    private fun pausePlayback() {
        // Implement pause logic for casted content
    }

    private fun resumePlayback() {
        // Implement resume logic for casted content
    }

    private fun isPaused(): Boolean {
        return false
    }

    private fun seek(positionMs: Int) {
        // Implement seek logic for casted content
    }

    private fun setVolume(volume: Float) {
        // Implement volume control for casted content
    }

    override fun onDestroy() {
        mediaRouter?.removeCallback(castListener!!)
        super.onDestroy()
    }

    private class CastListener(private val mediaRouter: MediaRouter) :
        MediaRouter.Callback() {
        override fun onRouteAdded(
            router: MediaRouter,
            route: MediaRouter.RouteInfo
        ) {
            super.onRouteAdded(router, route)
            android.util.Log.d("Cast", "Route added: ${route.name}")
        }

        override fun onRouteRemoved(
            router: MediaRouter,
            route: MediaRouter.RouteInfo
        ) {
            super.onRouteRemoved(router, route)
            android.util.Log.d("Cast", "Route removed: ${route.name}")
        }

        override fun onRouteChanged(
            router: MediaRouter,
            route: MediaRouter.RouteInfo
        ) {
            super.onRouteChanged(router, route)
            android.util.Log.d("Cast", "Route changed: ${route.name}")
        }

        override fun onRouteSelected(
            router: MediaRouter,
            route: MediaRouter.RouteInfo
        ) {
            super.onRouteSelected(router, route)
            android.util.Log.d("Cast", "Route selected: ${route.name}")
        }

        override fun onRouteUnselected(
            router: MediaRouter,
            route: MediaRouter.RouteInfo
        ) {
            super.onRouteUnselected(router, route)
            android.util.Log.d("Cast", "Route unselected: ${route.name}")
        }
    }
}



