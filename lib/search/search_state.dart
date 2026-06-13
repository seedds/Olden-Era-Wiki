import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../data/database.dart';
import '../data/models/search.dart';
import '../data/queries/search_queries.dart';

/// Port of the search-related @State in AppShellView (App.swift): shared
/// search text, debounced FTS5 querying, overlay presentation, and the
/// restore-on-pop behavior driven by navigation depth.
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

  /// Key for the app's root [Navigator], set by [OldenEraWikiApp].
  /// Used by routing helpers that may be called from contexts outside the
  /// navigator (e.g. the persistent search overlay in the CupertinoApp builder).
  GlobalKey<NavigatorState>? navigatorKey;

  /// Port of searchOverlayRestorePathCount: when a result is opened, the
  /// overlay is hidden and re-presented once navigation pops back to this
  /// depth.
  int? restoreDepth;

  /// Navigation depth (0 = home), maintained by [SearchNavigatorObserver].
  int depth = 0;

  Timer? _debounce;
  String _lastText = '';

  String get trimmedText => controller.text.trim();

  /// The overlay box only exists when there is an actual list to display —
  /// a no-match query shows nothing rather than a lingering empty card.
  bool get isShowingResults =>
      isOverlayPresented && trimmedText.isNotEmpty;

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
      restoreDepth = null;
      results = [];
      notifyListeners();
    } else {
      notifyListeners();
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
  void onResultSelected() {
    isOverlayPresented = false;
    restoreDepth = depth;
    notifyListeners();
  }

  /// Re-present the overlay when popping back to the depth the result was
  /// opened from (port of the onChange(of: path.count) block in App.swift).
  void onDepthChanged() {
    final restore = restoreDepth;
    if (restore != null && depth == restore && trimmedText.isNotEmpty) {
      isOverlayPresented = true;
      restoreDepth = null;
      notifyListeners();
    }
  }

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
    restoreDepth = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    controller.dispose();
    super.dispose();
  }
}

/// Tracks navigation depth so SearchState can restore the overlay on pop.
class SearchNavigatorObserver extends NavigatorObserver {
  SearchNavigatorObserver(this.search);

  final SearchState search;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      search.depth += 1;
      search.onDepthChanged();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    search.depth -= 1;
    search.onDepthChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) {
      search.depth -= 1;
      search.onDepthChanged();
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
}
