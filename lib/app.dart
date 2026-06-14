import 'package:flutter/cupertino.dart';

import 'routes.dart';
import 'screens/home_screen.dart';
import 'search/search_state.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'widgets/app_scaffold.dart';
import 'widgets/nav_bar_state.dart';

/// Port of OldenEraWikiApp / RootAppView (App.swift).
class OldenEraWikiApp extends StatefulWidget {
  const OldenEraWikiApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<OldenEraWikiApp> createState() => _OldenEraWikiAppState();
}

class _OldenEraWikiAppState extends State<OldenEraWikiApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final SearchState _search = SearchState();
  final NavBarState _navBar = NavBarState();
  late final SearchNavigatorObserver _observer = SearchNavigatorObserver(_search);

  @override
  void initState() {
    super.initState();
    _search.navigatorKey = _navigatorKey;
  }

  @override
  void dispose() {
    _search.dispose();
    _navBar.dispose();
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
          child: ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) {
            return CupertinoApp(
              title: 'Olden Era Wiki',
              debugShowCheckedModeBanner: false,
              navigatorKey: _navigatorKey,
              // The app is dark-only by design.
              theme: const CupertinoThemeData(
                brightness: Brightness.dark,
                primaryColor: AppTheme.accent,
              ),
              navigatorObservers: [_observer, appScaffoldRouteObserver],
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
                  child: _PersistentSearchShell(
                    navigatorKey: _navigatorKey,
                    child: child!,
                  ),
                );
              },
              home: const HomeScreen(),
            );
          },
          ),
        ),
      ),
    );
  }
}

/// Persistent shell that renders the search bar at the bottom of the screen.
/// The [child] is the navigator content from [CupertinoApp].
class _PersistentSearchShell extends StatefulWidget {
  const _PersistentSearchShell({
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<_PersistentSearchShell> createState() => _PersistentSearchShellState();
}

class _PersistentSearchShellState extends State<_PersistentSearchShell> {
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (!_searchFocusNode.hasFocus || !mounted) return;
    final search = SearchScope.of(context);
    if (search.trimmedText.isNotEmpty) {
      search.presentOverlay();
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final search = SearchScope.of(context);
    final mq = MediaQuery.of(context);
    final keyboardHeight = mq.viewInsets.bottom;

    // Matches the _OverlayWrapper SizedBox height of the search bar content.
    const searchBarHeight = 46.0;

    // The navigation bar is a single persistent row at the top of the shell,
    // OUTSIDE the Navigator. It owns the status-bar top inset; the Navigator
    // below gets padding.top zeroed. Because the bar is not part of any route,
    // it never slides, rebuilds, or flashes during push/pop — only the page
    // content underneath transitions. Screens publish their title/trailing to
    // NavBarState via AppScaffold.
    //
    // For the Navigator subtree we:
    //  - zero padding.top (the persistent bar already consumed it),
    //  - zero viewInsets.bottom so scaffolds don't resize for the keyboard,
    //  - add bottom padding equal to the search bar height so content reserves
    //    space and doesn't scroll under the bar.
    return Column(
      children: [
        PersistentNavBar(navigatorKey: widget.navigatorKey),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: MediaQuery(
                  data: mq.copyWith(
                    padding: mq.padding.copyWith(
                      top: 0,
                      bottom: mq.padding.bottom + searchBarHeight,
                    ),
                    viewInsets: mq.viewInsets.copyWith(bottom: 0),
                  ),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => _searchFocusNode.unfocus(),
                    child: widget.child,
                  ),
                ),
              ),
              // Persistent search bar pinned to the bottom, rising above the
              // keyboard when it is present.
              Positioned(
                left: 0,
                right: 0,
                bottom: keyboardHeight,
                child: _SearchBar(
                  controller: search.controller,
                  focusNode: _searchFocusNode,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The single persistent navigation bar, rendered once at the top of the
/// shell above the Navigator. Its container and the Home/Settings buttons are
/// built once and never rebuild on navigation; only the leading back button,
/// title, and trailing extras swap instantly via [NavBarState].
class PersistentNavBar extends StatelessWidget {
  const PersistentNavBar({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  static const double _toolbarHeight = 44;

  @override
  Widget build(BuildContext context) {
    // TEMP DIAGNOSTIC: confirm this builds once, not on navigation.
    debugPrint('[PERSISTENT NAVBAR BUILD]');

    final topInset = MediaQuery.paddingOf(context).top;

    // Home + Settings buttons: built once, never rebuilt by the inner
    // ListenableBuilder below.
    final homeButton = NavBarButton(
      icon: CupertinoIcons.house_fill,
      onTap: () => goHome(context),
    );
    final settingsButton = NavBarButton(
      icon: CupertinoIcons.gear,
      onTap: () => pushSettings(context),
    );

    // Non-subscribing read so PersistentNavBar.build itself is NOT rebuilt
    // when NavBarState notifies; only the inner ListenableBuilder reruns.
    // The shell always provides a NavBarScope ancestor.
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
                      onPressed: () => navigatorKey.currentState?.maybePop(),
                    )
                  : null,
              middle: Text(
                navBar.title,
                style: CupertinoTheme.of(context)
                    .textTheme
                    .navTitleTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...navBar.trailingExtras,
                  homeButton,
                  settingsButton,
                ],
              ),
              middleSpacing: 6,
            );
          },
        ),
      ),
    );
  }
}

/// Wraps the [CupertinoSearchTextField] in its own [Overlay] so that the
/// [EditableText] inside it can find an Overlay ancestor (required for text
/// selection handles). This is necessary because the search bar lives in the
/// [CupertinoApp.builder], which is above the app's [Navigator] and its
/// built-in Overlay.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background(context),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: _OverlayWrapper(
            child: CupertinoSearchTextField(
              controller: controller,
              focusNode: focusNode,
              placeholder: 'Search...',
            ),
          ),
        ),
      ),
    );
  }
}

/// Provides a minimal [Overlay] ancestor for its [child]. Uses
/// [LayoutBuilder] to pass exact constraints to the overlay content so
/// intrinsic sizing works correctly.
class _OverlayWrapper extends StatefulWidget {
  const _OverlayWrapper({required this.child});

  final Widget child;

  @override
  State<_OverlayWrapper> createState() => _OverlayWrapperState();
}

class _OverlayWrapperState extends State<_OverlayWrapper> {
  late final OverlayEntry _entry;

  @override
  void initState() {
    super.initState();
    _entry = OverlayEntry(builder: (_) => widget.child);
  }

  @override
  void didUpdateWidget(_OverlayWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    // The entry must be detached from the Overlay before it can be disposed.
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // CupertinoSearchTextField has a fixed height of 36.
    return SizedBox(
      height: 46,
      child: Overlay(initialEntries: [_entry]),
    );
  }
}

