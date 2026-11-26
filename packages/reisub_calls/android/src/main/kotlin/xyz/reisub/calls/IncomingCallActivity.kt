package xyz.reisub.calls

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.KeyEvent
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * The call screen, over the lock screen: who calls, Decline and Answer. A
 * volume key silences the ringing.
 */
class IncomingCallActivity : Activity() {
    private var callId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Over the lock screen from Android 8.1; on 8.0 the call shows as
        // its notification there.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        handle(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handle(intent)
    }

    private fun handle(intent: Intent) {
        val id = intent.getStringExtra(Calls.EXTRA_CALL_ID)
        val call = id?.let { Calls.calls[it] }
        if (call == null) {
            finish()
            return
        }
        callId = id
        Calls.screens[id] = { runOnUiThread { finish() } }
        if (intent.action == Calls.ACTION_ANSWER) {
            answer()
            return
        }
        setContentView(layout(call))
    }

    private fun layout(call: IncomingCall): LinearLayout {
        val dp = resources.displayMetrics.density
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setBackgroundColor(Color.rgb(0x11, 0x0f, 0x16))
            setPadding((24 * dp).toInt(), (120 * dp).toInt(), (24 * dp).toInt(), (64 * dp).toInt())
        }
        val avatar = TextView(this).apply {
            text = call.title.trim().take(1).uppercase()
            setTextColor(Color.WHITE)
            textSize = 44f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.rgb(0x8a, 0x5c, 0xff))
            }
        }
        root.addView(avatar, LinearLayout.LayoutParams((112 * dp).toInt(), (112 * dp).toInt()))
        root.addView(
            TextView(this).apply {
                text = call.title
                setTextColor(Color.WHITE)
                textSize = 30f
                typeface = Typeface.DEFAULT_BOLD
                gravity = Gravity.CENTER
                setPadding(0, (24 * dp).toInt(), 0, (8 * dp).toInt())
            },
        )
        root.addView(
            TextView(this).apply {
                text = call.label("incoming")
                setTextColor(Color.argb(0xb3, 0xff, 0xff, 0xff))
                textSize = 18f
                gravity = Gravity.CENTER
            },
        )
        root.addView(LinearLayout(this), LinearLayout.LayoutParams(1, 0, 1f))
        val buttons = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        buttons.addView(roundButton(call.label("decline"), Color.rgb(0xe5, 0x39, 0x35)) { decline() }, buttonParams(dp))
        buttons.addView(roundButton(call.label("answer"), Color.rgb(0x43, 0xa0, 0x47)) { answer() }, buttonParams(dp))
        root.addView(buttons)
        return root
    }

    private fun buttonParams(dp: Float) = LinearLayout.LayoutParams((96 * dp).toInt(), (96 * dp).toInt()).apply {
        setMargins((28 * dp).toInt(), 0, (28 * dp).toInt(), 0)
    }

    private fun roundButton(label: String, color: Int, onTap: () -> Unit) = Button(this).apply {
        text = label
        setTextColor(Color.WHITE)
        isAllCaps = false
        textSize = 15f
        background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
        }
        setOnClickListener { onTap() }
    }

    private fun answer() {
        val id = callId ?: return
        val keyguard = getSystemService(KeyguardManager::class.java)
        if (keyguard.isKeyguardLocked) {
            // The meeting opens once the phone is unlocked.
            keyguard.requestDismissKeyguard(
                this,
                object : KeyguardManager.KeyguardDismissCallback() {
                    override fun onDismissSucceeded() {
                        Calls.answer(applicationContext, id)
                        finish()
                    }
                },
            )
            return
        }
        Calls.answer(applicationContext, id)
        finish()
    }

    private fun decline() {
        callId?.let { Calls.decline(applicationContext, it) }
        finish()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN || keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
            Calls.silence(callId)
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onDestroy() {
        callId?.let { Calls.screens.remove(it) }
        super.onDestroy()
    }
}
