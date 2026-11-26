package xyz.reisub.calls

import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccountHandle

/**
 * The system's call service asks here for the calls this app rings
 * ("self-managed"): it then keeps ringing to the phone's rules, and a
 * volume key silences it (onSilence).
 */
class CallConnectionService : ConnectionService() {
    override fun onCreateIncomingConnection(
        account: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ): Connection {
        val id = request?.extras?.getString(Calls.EXTRA_CALL_ID) ?: ""
        val call = Calls.calls[id]
        val connection = CallConnection(applicationContext, id)
        connection.connectionProperties = Connection.PROPERTY_SELF_MANAGED
        connection.audioModeIsVoip = true
        if (call != null) {
            connection.setCallerDisplayName(call.title, android.telecom.TelecomManager.PRESENTATION_ALLOWED)
        }
        connection.setRinging()
        Calls.attach(id, connection)
        return connection
    }

    override fun onCreateIncomingConnectionFailed(
        account: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ) {
        // Telecom would not take it (a call on the phone, say): show it
        // without ringing over it.
        val id = request?.extras?.getString(Calls.EXTRA_CALL_ID) ?: return
        Calls.ring(applicationContext, id, quiet = true)
    }
}

class CallConnection(
    private val context: android.content.Context,
    private val id: String,
) : Connection() {
    override fun onShowIncomingCallUi() = Calls.ring(context, id)

    override fun onSilence() = Calls.silence(id)

    override fun onAnswer() = Calls.answer(context, id)

    override fun onAnswer(videoState: Int) = Calls.answer(context, id)

    override fun onReject() = Calls.decline(context, id)

    override fun onDisconnect() {
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
    }

    override fun onAbort() {
        setDisconnected(DisconnectCause(DisconnectCause.CANCELED))
        destroy()
    }
}
