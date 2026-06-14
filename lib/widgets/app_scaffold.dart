import 'package:flutter/cupertino.dart';

import '../data/models/search.dart';
import '../routes.dart';
import '../search/search_results_view.dart';
import '../search/search_state.dart';
import '../theme/app_theme.dart';

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
  }

  @override
  void dispose() {
    appScaffoldRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // This screen became visible again after a pop — restore its priority.
    _updateSearchPriority();
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
    // Non-reactive handle: only the overlay + PopScope below need to rebuild
    // on search changes, so the nav bar must not subscribe to SearchState.
    final searchState = SearchScope.notifierOf(context);

    // Built once here, outside the ListenableBuilder, so the nav bar (and its
    // Home/Settings buttons) is not rebuilt on every search/navigation notify.
    final navigationBar = CupertinoNavigationBar(
      backgroundColor: AppTheme.background(context),
      middle: Text(widget.title),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...widget.trailingExtras,
          _NavBarButton(
            icon: CupertinoIcons.house_fill,
            onTap: () => goHome(context),
          ),
          _NavBarButton(
            icon: CupertinoIcons.gear,
            onTap: () => pushSettings(context),
          ),
        ],
      ),
    );

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
            navigationBar: navigationBar,
            child: SafeArea(
              bottom: false,
              child: Stack(
                fit: StackFit.expand,
                children: [
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

/// Clears search state and pops to the home screen (port of goHome()).
void goHome(BuildContext context) {
  SearchScope.of(context).clear();
  Navigator.of(context).popUntil((route) => route.isFirst);
}

class _NavBarButton extends StatelessWidget {
  const _NavBarButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(icon, size: 22, color: AppTheme.accent),
      ),
    );
  }
}
