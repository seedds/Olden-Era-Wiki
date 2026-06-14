import 'package:flutter/cupertino.dart';

import '../data/models/search.dart';
import '../search/search_results_view.dart';
import '../search/search_state.dart';
import '../theme/app_theme.dart';
import 'nav_bar_state.dart';

/// [RouteObserver] used by [AppScaffold] to detect when a screen becomes
/// visible again after a pop, so it can restore its [searchPriority].
final RouteObserver<ModalRoute<void>> appScaffoldRouteObserver =
    RouteObserver<ModalRoute<void>>();

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _depth ??= SearchScope.of(context).depth;
    final route = ModalRoute.of(context);
    if (route != null) {
      appScaffoldRouteObserver.subscribe(this, route);
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
    appScaffoldRouteObserver.unsubscribe(this);
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
  /// Only the currently-visible (current) route should drive the bar.
  void _publishNavBar() {
    // Defer to post-frame to avoid mutating shared state during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route == null || !route.isCurrent) return;
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
    final route = ModalRoute.of(context);
    return (search.isOverlayPresented && (route?.isCurrent ?? true)) ||
        search.restoreDepth == _depth;
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
                  // Reserve space for the persistent search bar pinned at the
                  // bottom of the shell so screen content isn't hidden behind
                  // it. The shell encodes the bar height in padding.bottom.
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    child: widget.child,
                  ),
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

/// Clears search state and pops to the home screen (port of goHome()).
/// Uses the root navigator key fallback so it works from the persistent
/// nav bar context (which sits above the app's Navigator).
void goHome(BuildContext context) {
  final search = SearchScope.of(context);
  search.clear();
  final nav = Navigator.maybeOf(context) ?? search.navigatorKey?.currentState;
  nav?.popUntil((route) => route.isFirst);
}
