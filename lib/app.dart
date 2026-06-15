import 'dart:ui' show ImageFilter;

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
    final search = SearchScope.of(context);
    if (_searchFocusNode.hasFocus) {
      if (search.trimmedText.isNotEmpty) search.presentOverlay();
      return;
    }
    // Field lost focus: collapse the bar back to the tab row when there's no
    // pending query, matching iOS where an empty dismissed search closes.
    if (search.trimmedText.isEmpty && _searchActive) {
      setState(() => _searchActive = false);
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Activates the search field. Search is always a Home-context action: it
  /// switches to the Home tab so results open in, and return to, Home.
  ///
  /// Because the search field is a single persistent [CupertinoTextField] (it
  /// is never destroyed/swapped during the expand animation), a single
  /// `requestFocus()` reliably opens the keyboard immediately — no retry or
  /// reattach workaround is needed.
  void _openSearch() {
    setState(() => _searchActive = true);
    widget.tabs.setActive(AppTab.home);
    _searchFocusNode.requestFocus();
  }

  /// Collapses the search bar: unfocus, clear the query/overlay, and leave the
  /// user wherever they are. If they opened a detail page from a result, that
  /// page is kept (they can use the back button to return) rather than being
  /// popped away.
  void _closeSearch() {
    _searchFocusNode.unfocus();
    setState(() => _searchActive = false);
    SearchScope.of(context).clear();
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
                      builder: (context, _) => _BottomBar(
                        tabs: widget.tabs,
                        searchController: search.controller,
                        searchFocusNode: _searchFocusNode,
                        searchActive: _searchActive,
                        onTabSelected: _onTabSelected,
                        onOpenSearch: _openSearch,
                        onCloseSearch: _closeSearch,
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

/// The persistent bottom bar: a narrow liquid-glass tab pill (Home/Settings)
/// plus a tap-to-expand search field.
///
/// The search field is a single, persistent [CupertinoTextField] — it is never
/// destroyed or swapped during the expand animation (only its container width
/// animates). This is what makes focus/keyboard work immediately on a single
/// tap, unlike the package's GlassSearchableBottomBar which swapped between two
/// text fields across an animated width threshold.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.tabs,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchActive,
    required this.onTabSelected,
    required this.onOpenSearch,
    required this.onCloseSearch,
  });

  final TabNavState tabs;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool searchActive;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;

  /// Per-slot tab width — total tab pill width is this × 2 tabs.
  static const double _tabWidth = 92.0;

  @override
  Widget build(BuildContext context) {
    // Lift the whole bar above the keyboard when it is present.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: kBottomBarVerticalPadding,
        bottom: kBottomBarVerticalPadding + keyboardInset,
      ),
      child: SizedBox(
        height: kBottomBarHeight,
        child: Row(
          children: [
            // Leading spacer roughly centers the tab pill (the trailing
            // Spacer + search circle balance the right side).
            if (!searchActive) const Spacer(),
            // Tab pill: hidden while searching so the field can use the width.
            // GlassBottomBar uses an internal Stack that needs a bounded width,
            // so constrain it to the tab-pill footprint.
            if (!searchActive)
              SizedBox(
                width: _tabWidth * 2,
                child: GlassBottomBar(
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
                  selectedIndex: tabs.active == AppTab.home ? 0 : 1,
                  onTabSelected: onTabSelected,
                  tabWidth: _tabWidth,
                  barHeight: kBottomBarHeight,
                  verticalPadding: 0,
                  horizontalPadding: 0,
                  selectedIconColor: AppTheme.accent,
                ),
              ),
            if (!searchActive) const Spacer(),
            // Search element: collapsed circle, or expanded frosted field.
            Expanded(
              flex: searchActive ? 1 : 0,
              child: Align(
                alignment: Alignment.centerRight,
                child: searchActive
                    ? _ExpandedSearchField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onCancel: onCloseSearch,
                      )
                    : _CollapsedSearchButton(onTap: onOpenSearch),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular glass button shown when search is collapsed.
class _CollapsedSearchButton extends StatelessWidget {
  const _CollapsedSearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const GlassContainer(
        shape: LiquidOval(),
        child: SizedBox(
          width: kBottomBarHeight,
          height: kBottomBarHeight,
          child: Center(
            child: Icon(CupertinoIcons.search, color: AppTheme.accent),
          ),
        ),
      ),
    );
  }
}

/// Expanded, frosted-glass search field with a trailing cancel (×) button.
class _ExpandedSearchField extends StatelessWidget {
  const _ExpandedSearchField({
    required this.controller,
    required this.focusNode,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(kBottomBarHeight / 2);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: kBottomBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground(context).withValues(alpha: 0.4),
            borderRadius: radius,
            border: Border.all(
              color: AppTheme.textPrimary(context).withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              const Icon(CupertinoIcons.search,
                  color: AppTheme.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: CupertinoTextField(
                  controller: controller,
                  focusNode: focusNode,
                  placeholder: 'Search...',
                  placeholderStyle: TextStyle(
                    color: AppTheme.textSecondary(context),
                    fontSize: 17,
                  ),
                  style: TextStyle(
                    color: AppTheme.textPrimary(context),
                    fontSize: 17,
                  ),
                  cursorColor: AppTheme.accent,
                  padding: EdgeInsets.zero,
                  decoration: null,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onCancel,
                child: Icon(
                  CupertinoIcons.xmark_circle_fill,
                  color: AppTheme.textSecondary(context),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
