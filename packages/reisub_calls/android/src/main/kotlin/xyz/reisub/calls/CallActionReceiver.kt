package xyz.reisub.calls

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Decline from the notification, without opening anything. */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getStringExtra(Calls.EXTRA_CALL_ID) ?: return
        if (intent.action == Calls.ACTION_DECLINE) Calls.decline(context, id)
    }
}
