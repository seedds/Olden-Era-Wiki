import 'package:flutter/cupertino.dart';

import 'screens/home_screen.dart';
import 'search/search_state.dart';
import 'settings/app_settings.dart';
import 'theme/app_theme.dart';
import 'widgets/app_scaffold.dart';

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
  late final SearchNavigatorObserver _observer = SearchNavigatorObserver(_search);

  @override
  void initState() {
    super.initState();
    _search.navigatorKey = _navigatorKey;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: widget.settings,
      child: SearchScope(
        search: _search,
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
                  child: _PersistentSearchShell(child: child!),
                );
              },
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );
  }
}

/// Persistent shell that renders the search bar at the bottom of the screen.
/// The [child] is the navigator content from [CupertinoApp].
class _PersistentSearchShell extends StatefulWidget {
  const _PersistentSearchShell({required this.child});

  final Widget child;

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

    // Only the search bar rides above the keyboard; the navigator content
    // (and its nav bars) must stay put so opening a screen while the keyboard
    // is up doesn't cause a layout shift when the keyboard later collapses.
    // The inner MediaQuery zeroes viewInsets.bottom so CupertinoPageScaffold
    // doesn't also try to resize for the keyboard (which would cause
    // double-shrinking).
    return MediaQuery(
      data: mq.copyWith(viewInsets: mq.viewInsets.copyWith(bottom: 0)),
      child: Column(
        children: [
          // Navigator content. Tapping here dismisses the keyboard.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _searchFocusNode.unfocus(),
              child: widget.child,
            ),
          ),
          // Persistent search bar at the bottom, padded up by the keyboard
          // height so it slides above the keyboard.
          Padding(
            padding: EdgeInsets.only(bottom: keyboardHeight),
            child: _SearchBar(
              controller: search.controller,
              focusNode: _searchFocusNode,
            ),
          ),
        ],
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

