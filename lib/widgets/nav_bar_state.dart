import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

/// A tappable icon button used in the persistent navigation bar
/// (Home / Settings / per-screen filters share this style).
class NavBarButton extends StatelessWidget {
  const NavBarButton({super.key, required this.icon, required this.onTap});

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

/// Holds the data the single persistent navigation bar (in the app shell)
/// displays for the currently visible screen. Screens publish their title and
/// trailing buttons here via [AppScaffold] instead of building their own
/// nav bar, so the bar's container and Home/Settings buttons are built once
/// and never rebuild, move, or flash on navigation.
class NavBarState extends ChangeNotifier {
  String _title = 'Olden Era Wiki';
  List<Widget> _trailingExtras = const [];
  bool _canPop = false;

  String get title => _title;
  List<Widget> get trailingExtras => _trailingExtras;
  bool get canPop => _canPop;

  /// Called by the active screen to set what the persistent bar shows.
  void publish({
    required String title,
    required List<Widget> trailingExtras,
    required bool canPop,
  }) {
    if (_title == title &&
        identical(_trailingExtras, trailingExtras) &&
        _canPop == canPop) {
      return;
    }
    _title = title;
    _trailingExtras = trailingExtras;
    _canPop = canPop;
    notifyListeners();
  }
}

/// Inherited access to [NavBarState], mirroring SearchScope.
class NavBarScope extends InheritedNotifier<NavBarState> {
  const NavBarScope({
    super.key,
    required NavBarState navBar,
    required super.child,
  }) : super(notifier: navBar);

  /// Subscribing accessor (rebuilds the caller on change).
  static NavBarState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavBarScope>()!.notifier!;

  /// Non-subscribing accessor (use to publish without depending). Returns
  /// null when there is no [NavBarScope] ancestor (e.g. screens pumped in
  /// isolation in tests), so callers can degrade gracefully.
  static NavBarState? maybeNotifierOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<NavBarScope>()?.notifier;
}
