import 'package:material_ui/material_ui.dart';

/// The app's navigator and messenger, for what happens outside any one
/// screen: an answered call opening its meeting, say.
final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
