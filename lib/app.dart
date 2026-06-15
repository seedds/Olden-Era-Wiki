import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'screens/home_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'search/search_state.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'widgets/nav_bar_state.dart';
import 'widgets/root_navigator_scope.dart';
import 'widgets/tab_nav_state.dart';

/// Single source of truth for the persistent glass bottom bar's geometry.
///
/// The bar's total footprint above the bottom safe-area inset is the bar
/// height plus its surrounding vertical padding. Both the space the shell
/// reserves for screen content and the bar's own layout derive from these
/// constants so they can never drift apart.
const double kBottomBarHeight = 52.0;
const double kBottomBarVerticalPadding = 12.0;
const double kBottomBarFootprint =
    kBottomBarHeight + 2 * kBottomBarVerticalPadding;

/// Port of OldenEraWikiApp / RootAppView (App.swift).
class OldenEraWikiApp extends StatefulWidget {
  const OldenEraWikiApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<OldenEraWikiApp> createState() => _OldenEraWikiAppState();
}

class _OldenEraWikiAppState extends State<OldenEraWikiApp> {
  // The outer CupertinoApp navigator. It only ever holds the shell route, so
  // it acts as the top-level overlay host (used to anchor the filter dropdown
  // above both tab navigators).
  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();
  final SearchState _search = SearchState();
  final NavBarState _navBar = NavBarState();
  late final TabNavState _tabs = TabNavState(_search);

  @override
  void initState() {
    super.initState();
    _search.tabs = _tabs;
  }

  @override
  void dispose() {
    _search.dispose();
    _navBar.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: SearchScope(
        search: _search,
        child: NavBarScope(
          navBar: _navBar,
          child: TabNavScope(
            tabs: _tabs,
            child: ListenableBuilder(
              listenable: widget.settings,
              builder: (context, _) {
                return CupertinoApp(
                  title: 'Olden Era Wiki',
                  debugShowCheckedModeBanner: false,
                  navigatorKey: _rootNavigatorKey,
                  // The app is dark-only by design.
                  theme: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    primaryColor: AppTheme.accent,
                  ),
                  builder: (context, child) {
                    // First launch: snapshot the system text scale into the
                    // font-size preference (port of snapshotDefault in App.swift).
                    if (!widget.settings.hasFontSize) {
                      final systemScale =
                          MediaQuery.textScalerOf(context).scale(17) / 17;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        widget.settings.snapshotDefaultFontSize(systemScale);
                      });
                    }
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(
                            widget.settings.fontSize.scaleFactor),
                      ),
                      child: RootNavigatorScope(
                        navigatorKey: _rootNavigatorKey,
                        child: child!,
                      ),
                    );
                  },
                  home: _PersistentSearchShell(tabs: _tabs),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Persistent shell that hosts the two tab navigators and the glass bottom
/// bar (tabs + expanding search).
class _PersistentSearchShell extends StatefulWidget {
  const _PersistentSearchShell({required this.tabs});

  final TabNavState tabs;

  @override
  State<_PersistentSearchShell> createState() => _PersistentSearchShellState();
}

class _PersistentSearchShellState extends State<_PersistentSearchShell> {
  final FocusNode _searchFocusNode = FocusNode();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!mounted) return;
    if (_searchFocusNode.hasFocus) {
      final search = SearchScope.of(context);
      if (search.trimmedText.isNotEmpty) search.presentOverlay();
      return;
    }
    // Field lost focus: collapse the bar back to the tab row when there's no
    // pending query, matching iOS where an empty dismissed search closes.
    final search = SearchScope.of(context);
    if (search.trimmedText.isEmpty && _searchActive) {
      setState(() => _searchActive = false);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Focuses the search field once it actually exists in the tree.
  ///
  /// The glass bar's text field is only built partway through its expand
  /// animation, so a single early `requestFocus()` lands on a detached node
  /// and is dropped (forcing a second tap). Rather than guessing the animation
  /// duration, this retries on the real condition — "the field is focusable" —
  /// a bounded number of times, self-correcting regardless of package timing.
  void _focusSearchWhenReady({int attemptsLeft = 8}) {
    if (!mounted || !_searchActive) return; // dismissed before it landed
    if (_searchFocusNode.hasFocus) return; // already focused
    _searchFocusNode.requestFocus();
    if (_searchFocusNode.hasFocus || attemptsLeft <= 0) return;
    Future.delayed(
      const Duration(milliseconds: 40),
      () => _focusSearchWhenReady(attemptsLeft: attemptsLeft - 1),
    );
  }

  void _onTabSelected(int index) {
    final tab = index == 0 ? AppTab.home : AppTab.settings;
    // Re-tapping the already-active tab pops its stack to root (standard iOS
    // tab-bar behaviour). The query is kept: popping fires the tab's
    // SearchNavigatorObserver.didPop, which re-presents the search overlay
    // when navigation returns to the depth a result was opened from.
    if (tab == widget.tabs.active) {
      widget.tabs.keyFor(tab).currentState?.popUntil((r) => r.isFirst);
    }
    widget.tabs.setActive(tab);
  }

  Widget _buildTabNavigator(AppTab tab) {
    return Navigator(
      key: widget.tabs.keyFor(tab),
      observers: widget.tabs.observersFor(tab),
      onGenerateRoute: (settings) => CupertinoPageRoute<void>(
        settings: settings,
        builder: (_) =>
            tab == AppTab.home ? const HomeScreen() : const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final search = SearchScope.of(context);
    final mq = MediaQuery.of(context);

    // The navigation bar is a single persistent row at the top of the shell.
    // Each tab below gets its own Navigator inside an IndexedStack so deep
    // navigation state is preserved across tab switches. The Navigator subtree
    // gets padding.top zeroed (the persistent bar consumed it) and bottom
    // padding equal to the bottom bar footprint so content reserves space and
    // scrolls under the glass bar.
    return Column(
      children: [
        PersistentNavBar(tabs: widget.tabs),
        Expanded(
          child: LiquidGlassScope(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GlassBackgroundSource(
                    child: MediaQuery(
                      data: mq.copyWith(
                        padding: mq.padding.copyWith(
                          top: 0,
                          bottom: mq.padding.bottom + kBottomBarFootprint,
                        ),
                        viewInsets: mq.viewInsets.copyWith(bottom: 0),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _searchFocusNode.unfocus(),
                        child: ListenableBuilder(
                          listenable: widget.tabs,
                          builder: (context, _) {
                            return IndexedStack(
                              index: widget.tabs.active == AppTab.home ? 0 : 1,
                              children: [
                                _buildTabNavigator(AppTab.home),
                                _buildTabNavigator(AppTab.settings),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                // Persistent glass bottom bar pinned to the bottom, rising
                // above the keyboard when it is present.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: ListenableBuilder(
                      listenable: widget.tabs,
                      builder: (context, _) => GlassSearchableBottomBar(
                        tabs: const [
                          GlassBottomBarTab(
                            icon: Icon(CupertinoIcons.house_fill),
                            label: 'Home',
                          ),
                          GlassBottomBarTab(
                            icon: Icon(CupertinoIcons.gear),
                            label: 'Settings',
                          ),
                        ],
                        selectedIndex:
                            widget.tabs.active == AppTab.home ? 0 : 1,
                        onTabSelected: _onTabSelected,
                        isSearchActive: _searchActive,
                        barHeight: kBottomBarHeight,
                        verticalPadding: kBottomBarVerticalPadding,
                        selectedIconColor: AppTheme.accent,
                        searchConfig: GlassSearchBarConfig(
                          controller: search.controller,
                          focusNode: _searchFocusNode,
                          hintText: 'Search...',
                          // App-controlled focus (see _focusSearchWhenReady):
                          // the package's auto-focus fires before the field is
                          // built, so we drive focus ourselves on toggle.
                          autoFocusOnExpand: false,
                          // Search is always a Home-context action: activating
                          // it switches to the Home tab so results open in, and
                          // return to, Home. The collapsed pill always shows
                          // the Home icon to match.
                          collapsedLogoBuilder: (_) => const Center(
                            child: Icon(
                              CupertinoIcons.house_fill,
                              color: AppTheme.accent,
                            ),
                          ),
                          onSearchToggle: (active) {
                            setState(() => _searchActive = active);
                            if (active) {
                              widget.tabs.setActive(AppTab.home);
                              _focusSearchWhenReady();
                            } else {
                              // Dismissing search (tapping the collapsed Home
                              // pill) returns to a clean Home root: unfocus,
                              // clear the query/overlay, and pop any detail
                              // that was opened from results — so nothing is
                              // left stranded under the collapsed bar.
                              _searchFocusNode.unfocus();
                              SearchScope.of(context).clear();
                              widget.tabs.keyFor(AppTab.home).currentState
                                  ?.popUntil((r) => r.isFirst);
                            }
                          },
                          onCancelTap: () => SearchScope.of(context).clear(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The single persistent navigation bar, rendered once at the top of the
/// shell above the tab navigators. It shows the back button, title, and
/// per-screen trailing extras (e.g. the faction filter) — published by the
/// active screen via [NavBarState]. Home/Settings now live in the bottom bar.
class PersistentNavBar extends StatelessWidget {
  const PersistentNavBar({super.key, required this.tabs});

  final TabNavState tabs;

  static const double _toolbarHeight = 44;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    // Non-subscribing read so PersistentNavBar.build itself is NOT rebuilt
    // when NavBarState notifies; only the inner ListenableBuilder reruns.
    final navBar = NavBarScope.maybeNotifierOf(context)!;

    return Container(
      color: AppTheme.background(context),
      padding: EdgeInsets.only(top: topInset),
      child: SizedBox(
        height: _toolbarHeight,
        child: ListenableBuilder(
          listenable: navBar,
          builder: (context, _) {
            return NavigationToolbar(
              leading: navBar.canPop
                  ? CupertinoNavigationBarBackButton(
                      color: AppTheme.accent,
                      onPressed: () => tabs.activeNavigator?.maybePop(),
                    )
                  : null,
              middle: Text(
                navBar.title,
                style:
                    CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: navBar.trailingExtras.isEmpty
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: navBar.trailingExtras,
                    ),
              middleSpacing: 6,
            );
          },
        ),
      ),
    );
  }
}
