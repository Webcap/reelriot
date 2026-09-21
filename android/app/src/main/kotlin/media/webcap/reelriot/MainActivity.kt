package media.webcap.reelriot

import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "media.webcap.reelriot/cast_wake")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        CastProxyService.start(this)
                        result.success(true)
                    }
                    "release" -> {
                        CastProxyService.stop(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "media.webcap.reelriot/screen_wake")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        runOnUiThread {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            window.decorView.keepScreenOn = true
                        }
                        result.success(true)
                    }
                    "disable" -> {
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                            window.decorView.keepScreenOn = false
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
