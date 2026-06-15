import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';

import '../data/database.dart';
import '../data/models/search.dart';
import '../data/queries/search_queries.dart';
import '../widgets/tab_nav_state.dart';

/// Port of the search-related @State in AppShellView (App.swift): shared
/// search text, debounced FTS5 querying, overlay presentation, and the
/// restore-on-pop behavior driven by navigation depth.
///
/// Navigation depth and the overlay restore point are tracked **per tab**,
/// because each tab owns an independent [Navigator] stack (the app shell keeps
/// both alive in an IndexedStack). A single shared counter would be corrupted
/// by the other tab's pushes/pops.
class SearchState extends ChangeNotifier {
  SearchState() {
    controller.addListener(_onTextChanged);
  }

  /// One controller shared by the search field on every screen, matching the
  /// single shell-level `searchText` in the Swift app.
  final TextEditingController controller = TextEditingController();

  List<GlobalSearchResult> results = [];
  bool isOverlayPresented = false;

  /// The entity type whose search results are listed first, set by the
  /// currently visible screen via [AppScaffold].
  SearchEntityType? searchPriority;

  /// The tab navigation state, set by [OldenEraWikiApp]. Routing helpers use
  /// it to resolve the currently active tab's [Navigator] when called from
  /// contexts outside any navigator (e.g. the persistent search overlay).
  TabNavState? tabs;

  /// Port of searchOverlayRestorePathCount, per tab: when a result is opened,
  /// the overlay is hidden and re-presented once that tab's navigation pops
  /// back to this depth.
  final Map<AppTab, int?> _restoreDepth = {
    for (final tab in AppTab.values) tab: null,
  };

  /// Per-tab navigation depth (0 = the tab's root), maintained by each tab's
  /// [SearchNavigatorObserver].
  final Map<AppTab, int> _depth = {
    for (final tab in AppTab.values) tab: 0,
  };

  AppTab get _activeTab => tabs?.active ?? AppTab.home;

  int depthFor(AppTab tab) => _depth[tab] ?? 0;
  int? restoreDepthFor(AppTab tab) => _restoreDepth[tab];

  String get trimmedText => controller.text.trim();

  /// The overlay box only exists when there is an actual list to display —
  /// a no-match query shows nothing rather than a lingering empty card.
  bool get isShowingResults =>
      isOverlayPresented && trimmedText.isNotEmpty;

  /// Notifies dependents, deferring to after the current frame if called
  /// during the build/layout phase. The glass bottom bar clears the shared
  /// [controller] inside its layout (`SearchPill.didUpdateWidget`), which
  /// drives [_onTextChanged] mid-build; notifying synchronously then would
  /// mark the [SearchScope] dirty during build and throw.
  void _safeNotify() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  /// Re-present the overlay (e.g. when the search field regains focus with
  /// text still in it). Has no visible effect unless there are results.
  void presentOverlay() {
    if (isOverlayPresented) return;
    isOverlayPresented = true;
    notifyListeners();
  }

  void _onTextChanged() {
    if (controller.text == _lastText) return;
    _lastText = controller.text;

    _debounce?.cancel();
    final trimmed = trimmedText;
    isOverlayPresented = trimmed.isNotEmpty;
    if (trimmed.isEmpty) {
      _restoreDepth[_activeTab] = null;
      results = [];
      _safeNotify();
    } else {
      _safeNotify();
      _debounce = Timer(const Duration(milliseconds: 150), () {
        _loadResults(trimmed);
      });
    }
  }

  void _loadResults(String query) {
    try {
      results = WikiDatabase.instance.globalSearch(query: query);
    } catch (error) {
      debugPrint('Error performing global search: $error');
      results = [];
    }
    notifyListeners();
  }

  /// Called when a search result row is tapped, before the detail is pushed.
  /// Records the restore point for the currently active tab.
  void onResultSelected() {
    isOverlayPresented = false;
    _restoreDepth[_activeTab] = _depth[_activeTab];
    notifyListeners();
  }

  /// Re-present the overlay when [tab]'s navigation pops back to the depth the
  /// result was opened from (port of the onChange(of: path.count) block in
  /// App.swift). Only the active tab may restore.
  void onDepthChanged(AppTab tab) {
    if (tab != _activeTab) return;
    final restore = _restoreDepth[tab];
    if (restore != null &&
        _depth[tab] == restore &&
        trimmedText.isNotEmpty) {
      isOverlayPresented = true;
      _restoreDepth[tab] = null;
      notifyListeners();
    }
  }

  void incrementDepth(AppTab tab) => _depth[tab] = (_depth[tab] ?? 0) + 1;
  void decrementDepth(AppTab tab) => _depth[tab] = (_depth[tab] ?? 0) - 1;

  /// Dismiss the overlay without clearing the text (system back gesture).
  void dismissOverlay() {
    if (!isOverlayPresented) return;
    isOverlayPresented = false;
    notifyListeners();
  }

  /// Port of goHome() search cleanup.
  void clear() {
    _debounce?.cancel();
    _lastText = '';
    controller.clear();
    results = [];
    isOverlayPresented = false;
    for (final tab in AppTab.values) {
      _restoreDepth[tab] = null;
    }
    _safeNotify();
  }

  Timer? _debounce;
  String _lastText = '';

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }
}

/// Tracks per-tab navigation depth so SearchState can restore the overlay on
/// pop. One instance is attached to each tab's [Navigator]; it knows which
/// [AppTab] it belongs to.
class SearchNavigatorObserver extends NavigatorObserver {
  SearchNavigatorObserver(this.search, this.tab);

  final SearchState search;
  final AppTab tab;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      search.incrementDepth(tab);
      search.onDepthChanged(tab);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    search.decrementDepth(tab);
    search.onDepthChanged(tab);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      search.decrementDepth(tab);
      search.onDepthChanged(tab);
    }
  }
}

class SearchScope extends InheritedNotifier<SearchState> {
  const SearchScope({
    super.key,
    required SearchState search,
    required super.child,
  }) : super(notifier: search);

  static SearchState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SearchScope>()!.notifier!;

  /// Like [of] but does NOT subscribe the caller to rebuilds. Use when you
  /// only need the notifier to hand to a [ListenableBuilder].
  static SearchState notifierOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SearchScope>()!.notifier!;
}
