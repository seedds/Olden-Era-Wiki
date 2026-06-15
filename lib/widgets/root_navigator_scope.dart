import 'package:flutter/cupertino.dart';

/// Exposes the app's root [Navigator] to widgets that are rendered in the
/// persistent shell (above the [Navigator]) but logically belong to a screen.
///
/// The persistent nav bar renders each screen's trailing buttons (e.g. the
/// faction filter) in [PersistentNavBar], which lives in the CupertinoApp
/// builder subtree — an *ancestor* of the app's Navigator/Overlay. Such
/// displaced widgets therefore can't reach a Navigator via their own context.
/// They resolve it through [RootNavigatorScope.of] instead, presenting modal
/// popups and routes against the real app Navigator.
class RootNavigatorScope extends InheritedWidget {
  const RootNavigatorScope({
    super.key,
    required this.navigatorKey,
    required super.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  /// The app's root [NavigatorState], or null if it isn't mounted yet (e.g.
  /// during the first frame) or there is no scope ancestor (e.g. isolated
  /// tests). Callers should fall back to their own context when null.
  static NavigatorState? of(BuildContext context) => context
      .getInheritedWidgetOfExactType<RootNavigatorScope>()
      ?.navigatorKey
      .currentState;

  /// The full-screen root [OverlayState] (the one provided by [WidgetsApp],
  /// which is an ancestor of the persistent shell — so entries inserted here
  /// cover the entire screen, including the persistent nav bar). Returns null
  /// when unavailable (first frame / isolated tests).
  static OverlayState? rootOverlayOf(BuildContext context) {
    final navContext = of(context)?.context;
    if (navContext == null) return null;
    return Navigator.of(navContext, rootNavigator: true).overlay;
  }

  @override
  bool updateShouldNotify(RootNavigatorScope oldWidget) =>
      navigatorKey != oldWidget.navigatorKey;
}
