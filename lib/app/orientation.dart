import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tells [PortraitOnPhone] when other screens cover or uncover its own.
final appRouteObserver = RouteObserver<ModalRoute<void>>();

/// Whether this is a phone running the app natively, where screens may be
/// locked to an orientation.
bool isNativePhone(BuildContext context) =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) &&
    MediaQuery.sizeOf(context).shortestSide < 600;

/// The orientations allowed outside a fullscreen meeting. A screen that
/// needs one sets it; a meeting returns to it when it ends, so a screen
/// shown underneath keeps its orientation.
abstract final class AppOrientation {
  static List<DeviceOrientation> _base = const [];

  static List<DeviceOrientation> get base => _base;

  static set base(List<DeviceOrientation> value) {
    _base = value;
    restore();
  }

  /// Applies [base] again, e.g. after a meeting forced landscape.
  static void restore() =>
      unawaited(SystemChrome.setPreferredOrientations(_base));
}

/// Keeps a phone upright while [child]'s screen is the one in front. Other
/// screens opened on top of it may rotate again.
class PortraitOnPhone extends StatefulWidget {
  const PortraitOnPhone({super.key, required this.child});

  final Widget child;

  @override
  State<PortraitOnPhone> createState() => _PortraitOnPhoneState();
}

class _PortraitOnPhoneState extends State<PortraitOnPhone> with RouteAware {
  ModalRoute<void>? _route;

  static const _portrait = [DeviceOrientation.portraitUp];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _route)) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    appRouteObserver.subscribe(this, route);
    // Already pushed when this subscribes, so didPush won't come.
    if (route.isCurrent) _lock();
  }

  void _lock() {
    if (isNativePhone(context)) AppOrientation.base = _portrait;
  }

  void _unlock() {
    if (identical(AppOrientation.base, _portrait)) AppOrientation.base = [];
  }

  @override
  void didPush() => _lock();

  @override
  void didPopNext() => _lock();

  @override
  void didPushNext() => _unlock();

  @override
  void dispose() {
    // Not unlocked here: when a meeting ends, the new home screen locks
    // before the meeting's screen goes away.
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
