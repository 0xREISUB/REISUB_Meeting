import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

web.WakeLockSentinel? _sentinel;
bool _wanted = false;
JSFunction? _onVisibilityChange;

/// Keeps a phone's screen from timing out while a meeting is open. Mobile
/// browsers suspend a page, and its call, once the screen turns off.
///
/// The browser drops the lock whenever the tab is hidden, so it is taken again
/// each time the page becomes visible.
Future<void> setWebWakeLock(bool enabled) async {
  _wanted = enabled;
  if (enabled) {
    if (_onVisibilityChange == null) {
      final listener = ((web.Event _) {
        if (web.document.visibilityState == 'visible') unawaited(_acquire());
      }).toJS;
      _onVisibilityChange = listener;
      web.document.addEventListener('visibilitychange', listener);
    }
    await _acquire();
    return;
  }
  final listener = _onVisibilityChange;
  _onVisibilityChange = null;
  if (listener != null) {
    web.document.removeEventListener('visibilitychange', listener);
  }
  final sentinel = _sentinel;
  _sentinel = null;
  if (sentinel != null && !sentinel.released) {
    try {
      await sentinel.release().toDart;
    } catch (_) {}
  }
}

Future<void> _acquire() async {
  if (!_wanted || !(_sentinel?.released ?? true)) return;
  // Firefox before 126 and older Safari have no Screen Wake Lock API.
  if (!web.window.navigator.has('wakeLock')) return;
  try {
    final sentinel = await web.window.navigator.wakeLock
        .request('screen')
        .toDart;
    if (_wanted) {
      _sentinel = sentinel;
    } else {
      await sentinel.release().toDart;
    }
  } catch (_) {
    // Refused, e.g. battery saver or the page is hidden; retried on the next
    // visibility change.
  }
}
