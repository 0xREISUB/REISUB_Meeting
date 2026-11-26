package xyz.reisub.calls

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Dart's side of calls. Every Flutter engine gets one, the push handler's
 * too, so a push can ring a closed app; the one with the app's screen
 * hears what the user did.
 */
class ReisubCallsPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "reisub_calls")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Calls.onAction = { main.post { channel.invokeMethod("onCallAction", null) } }
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        Calls.onAction = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
        when (call.method) {
            "show" -> {
                IncomingCall.from(args)?.let { Calls.show(context, it) }
                result.success(null)
            }
            "end" -> {
                val id = args["id"] as? String
                if (id != null) {
                    val labels = mutableMapOf<String, String>()
                    for (key in listOf("missed", "missedChannel", "channel")) {
                        (args[key] as? String)?.let { labels[key] = it }
                    }
                    Calls.end(
                        context,
                        id,
                        missed = args["missed"] == true,
                        missedText = args["missedText"] as? String,
                        labels = labels,
                    )
                }
                result.success(null)
            }
            "takePendingAction" -> {
                val action = Calls.pendingAction
                Calls.pendingAction = null
                result.success(action)
            }
            "canUseFullScreen" -> result.success(Calls.canUseFullScreen(context))
            "openFullScreenSettings" -> {
                Calls.openFullScreenSettings(context)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
