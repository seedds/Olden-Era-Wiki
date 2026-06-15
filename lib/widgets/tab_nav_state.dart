import 'package:flutter/cupertino.dart';

import '../search/search_state.dart';

/// The two persistent tabs of the app shell. Each owns an independent
/// [Navigator] stack so a tab's deep navigation state is preserved when the
/// user switches away and back (port of the bottom-bar tabs in the redesign).
enum AppTab { home, settings }

/// Holds the active tab plus, for each tab, a [GlobalKey] for its [Navigator]
/// and its own observer instances. A [NavigatorObserver] can only be attached
/// to one [Navigator] at a time, so each tab navigator gets its own
/// [SearchNavigatorObserver] and [RouteObserver]. Routing helpers (routes.dart),
/// the persistent nav bar (back button / canPop), and search (result pushes +
/// depth) target the currently visible tab's navigator regardless of where
/// they are called from.
class TabNavState extends ChangeNotifier {
  TabNavState(SearchState search)
      : _tabs = {
          for (final tab in AppTab.values)
            tab: _TabEntry(
              key: GlobalKey<NavigatorState>(),
              searchObserver: SearchNavigatorObserver(search, tab),
              routeObserver: RouteObserver<ModalRoute<void>>(),
            ),
        };

  final Map<AppTab, _TabEntry> _tabs;

  AppTab _active = AppTab.home;
  AppTab get active => _active;

  GlobalKey<NavigatorState> keyFor(AppTab tab) => _tabs[tab]!.key;

  List<NavigatorObserver> observersFor(AppTab tab) =>
      [_tabs[tab]!.searchObserver, _tabs[tab]!.routeObserver];

  /// The navigator key of the currently visible tab.
  GlobalKey<NavigatorState> get activeKey => keyFor(_active);

  /// The currently visible tab's [NavigatorState] (null before first mount).
  NavigatorState? get activeNavigator => activeKey.currentState;

  /// The [RouteObserver] attached to the navigator that owns [navigator],
  /// so a screen can subscribe to the correct per-tab observer.
  RouteObserver<ModalRoute<void>>? routeObserverForNavigator(
      NavigatorState navigator) {
    for (final entry in _tabs.entries) {
      if (entry.value.key.currentState == navigator) {
        return entry.value.routeObserver;
      }
    }
    return null;
  }

  /// Which [AppTab] owns [navigator], or null if it isn't a tab navigator.
  AppTab? tabForNavigator(NavigatorState navigator) {
    for (final entry in _tabs.entries) {
      if (entry.value.key.currentState == navigator) return entry.key;
    }
    return null;
  }

  void setActive(AppTab tab) {
    if (_active == tab) return;
    _active = tab;
    notifyListeners();
  }
}

class _TabEntry {
  _TabEntry({
    required this.key,
    required this.searchObserver,
    required this.routeObserver,
  });

  final GlobalKey<NavigatorState> key;
  final SearchNavigatorObserver searchObserver;
  final RouteObserver<ModalRoute<void>> routeObserver;
}

/// Inherited access to [TabNavState], mirroring SearchScope / NavBarScope.
class TabNavScope extends InheritedNotifier<TabNavState> {
  const TabNavScope({
    super.key,
    required TabNavState tabs,
    required super.child,
  }) : super(notifier: tabs);

  static TabNavState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabNavScope>()!.notifier!;

  /// Non-subscribing accessor. Returns null when there is no scope ancestor
  /// (e.g. screens pumped in isolation in tests).
  static TabNavState? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabNavScope>()?.notifier;
}
