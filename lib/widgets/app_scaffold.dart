import 'package:flutter/cupertino.dart';

import '../data/models/search.dart';
import '../search/search_results_view.dart';
import '../search/search_state.dart';
import '../theme/app_theme.dart';
import 'nav_bar_state.dart';
import 'tab_nav_state.dart';

/// Bottom inset every scrollable screen body should add to its own content
/// padding so its last item rests clear of the persistent glass search bar
/// (while still scrolling *under* it mid-scroll — the liquid glass effect).
///
/// The shell already encodes the bar's footprint plus the device safe-area
/// inset into [MediaQuery]'s bottom padding, so this is the single place that
/// knows how to clear the bar. Pass [extra] for the screen's own desired
/// breathing room (e.g. 24 for lists, 32 for detail pages).
extension AppScaffoldScrollInset on BuildContext {
  double scrollBottomInset({double extra = 0}) =>
      MediaQuery.paddingOf(this).bottom + extra;
}

/// Every screen gets the nav bar with Home + Settings buttons.
/// The search bar is now rendered persistently at the bottom of the screen
/// by [_PersistentSearchShell] in app.dart.
class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.searchPriority,
    this.trailingExtras = const [],
  });

  final String title;
  final Widget child;

  /// The entity type whose search results are listed first on this screen.
  final SearchEntityType? searchPriority;

  /// Extra nav-bar buttons shown before Home/Settings (e.g. faction filter).
  final List<Widget> trailingExtras;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> with RouteAware {
  /// Navigation depth of this screen, captured once. SearchNavigatorObserver
  /// increments SearchState.depth synchronously during Navigator.push, before
  /// the new route's widgets build, so this reads the correct value.
  int? _depth;

  /// The per-tab [RouteObserver] this screen subscribed to. Stored so the
  /// exact same instance is used to unsubscribe (each tab navigator has its
  /// own observer; a NavigatorObserver can't be shared across navigators).
  RouteObserver<ModalRoute<void>>? _routeObserver;

  /// The tab state this screen is listening to, so the active screen of the
  /// newly-selected tab re-publishes its nav bar (and overlay) on tab switch.
  TabNavState? _tabs;

  /// Which tab this screen lives in, resolved from its owning navigator. Used
  /// to read the per-tab navigation depth / restore point from [SearchState].
  AppTab? _tab;

  void _onTabChanged() {
    _updateSearchPriority();
    _publishNavBar();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final tabs = TabNavScope.maybeOf(context);
    if (tabs != _tabs) {
      _tabs?.removeListener(_onTabChanged);
      _tabs = tabs;
      _tabs?.addListener(_onTabChanged);
    }
    _tab ??= tabs?.tabForNavigator(Navigator.of(context));
    // Capture this screen's navigation depth within its own tab once. The
    // tab's SearchNavigatorObserver increments depth synchronously during
    // Navigator.push, before the new route's widgets build, so this reads the
    // correct value.
    _depth ??= _tab != null ? SearchScope.of(context).depthFor(_tab!) : 0;
    final observer = tabs?.routeObserverForNavigator(Navigator.of(context));
    if (route != null && observer != null && observer != _routeObserver) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = observer;
      observer.subscribe(this, route);
    }
    _updateSearchPriority();
    _publishNavBar();
  }

  @override
  void didUpdateWidget(AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Dynamic titles (e.g. detail screens that load their name asynchronously)
    // change widget.title after the first build; republish so the persistent
    // bar reflects the new title.
    if (oldWidget.title != widget.title ||
        !identical(oldWidget.trailingExtras, widget.trailingExtras)) {
      _publishNavBar();
    }
  }

  @override
  void dispose() {
    _routeObserver?.unsubscribe(this);
    _tabs?.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  void didPush() {
    // This screen's route finished pushing and is now the top route.
    _publishNavBar();
  }

  @override
  void didPopNext() {
    // This screen became visible again after a pop — restore its priority
    // and republish its nav bar contents to the persistent bar.
    _updateSearchPriority();
    _publishNavBar();
  }

  /// Publishes this screen's title/trailing/canPop to the persistent nav bar.
  /// Only the current route of the *active* tab should drive the bar — both
  /// tab navigators stay mounted in the shell's IndexedStack, so a screen
  /// that is current within an inactive tab must not publish.
  void _publishNavBar() {
    // Defer to post-frame to avoid mutating shared state during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
      final tabs = TabNavScope.maybeOf(context);
      if (tabs != null && Navigator.of(context) != tabs.activeNavigator) {
        return;
      }
      // No-op when there's no persistent nav bar (e.g. isolated tests).
      NavBarScope.maybeNotifierOf(context)?.publish(
        title: widget.title,
        trailingExtras: widget.trailingExtras,
        canPop: Navigator.of(context).canPop(),
      );
    });
  }

  /// Whether this screen draws the search results overlay. Besides the
  /// normal presented-on-current-screen case, a screen with a pending
  /// restore (a result was opened from it) keeps the overlay painted while
  /// covered, so it's already visible underneath during the pop transition.
  bool _showsOverlay(SearchState search) {
    if (search.trimmedText.isEmpty) return false;
    // Only the active tab's screens may paint the overlay. With both tab
    // navigators kept alive in the shell's IndexedStack, screens at the same
    // depth in the inactive tab would otherwise also match the restore check.
    final tabs = TabNavScope.maybeOf(context);
    if (tabs != null && Navigator.of(context) != tabs.activeNavigator) {
      return false;
    }
    final route = ModalRoute.of(context);
    final restoreDepth =
        _tab != null ? search.restoreDepthFor(_tab!) : null;
    return (search.isOverlayPresented && (route?.isCurrent ?? true)) ||
        restoreDepth == _depth;
  }

  void _updateSearchPriority() {
    final search = SearchScope.of(context);
    if (search.searchPriority != widget.searchPriority) {
      // Use post-frame callback to avoid changing state during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SearchScope.of(context).searchPriority = widget.searchPriority;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The navigation bar is no longer per-screen; it's a single persistent bar
    // in the app shell (PersistentNavBar) that this screen feeds via
    // _publishNavBar. This widget renders only the body + search overlay.
    //
    // Non-reactive handle: only the overlay + PopScope below need to rebuild
    // on search changes.
    final searchState = SearchScope.notifierOf(context);

    return ListenableBuilder(
      listenable: searchState,
      builder: (context, _) {
        return PopScope(
          // System back (Android) dismisses the search overlay before popping.
          canPop: !searchState.isShowingResults,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) searchState.dismissOverlay();
          },
          child: CupertinoPageScaffold(
            backgroundColor: AppTheme.background(context),
            child: SafeArea(
              bottom: false,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // The body fills the full height and scrolls *under* the
                  // translucent glass search bar (the liquid glass effect).
                  // Each scrollable adds [BuildContext.scrollBottomInset] to its
                  // own bottom padding so its last item rests clear of the bar.
                  widget.child,
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _showsOverlay(searchState)
                        ? SearchOverlay(
                            results: searchState.results,
                            prioritizedEntityType: searchState.searchPriority,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
