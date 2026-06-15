import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import 'local_image.dart';
import 'root_navigator_scope.dart';

/// Port of FactionFilterToolbar (ListScreenSupport.swift): a nav-bar button
/// that shows a faction picker as a dropdown menu anchored at the button,
/// matching the iOS pull-down menu feel.
///
/// The button lives in the persistent nav bar, which is rendered above the
/// app's Navigator. The menu is therefore inserted into the *root* overlay
/// (an ancestor of the whole shell) with a full-screen dismiss barrier, so a
/// tap anywhere — including the nav bar — closes it and a second tap can't
/// stack a new menu on top.
class FactionFilterButton extends StatefulWidget {
  const FactionFilterButton({
    super.key,
    required this.factions,
    required this.onSelect,
  });

  final List<String> factions;
  final ValueChanged<String?> onSelect;

  @override
  State<FactionFilterButton> createState() => _FactionFilterButtonState();
}

class _FactionFilterButtonState extends State<FactionFilterButton> {
  OverlayEntry? _entry;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _removeMenu() {
    _entry?.remove();
    _entry = null;
  }

  void _toggleMenu() {
    // Second tap on the button closes the open menu instead of stacking.
    if (_entry != null) {
      _removeMenu();
      return;
    }

    final overlay = RootNavigatorScope.rootOverlayOf(context);
    final box = context.findRenderObject() as RenderBox?;
    if (overlay == null || box == null || !box.hasSize) return;

    final anchor = box.localToGlobal(Offset.zero) & box.size;

    _entry = OverlayEntry(
      builder: (overlayContext) => _FactionMenu(
        anchor: anchor,
        factions: widget.factions,
        onSelect: (factionID) {
          _removeMenu();
          widget.onSelect(factionID);
        },
        onDismiss: _removeMenu,
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleMenu,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          CupertinoIcons.line_horizontal_3_decrease_circle,
          size: 22,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

/// The dropdown card plus its full-screen dismiss barrier. Anchored to the
/// top-right of the filter button's [anchor] rect.
class _FactionMenu extends StatelessWidget {
  const _FactionMenu({
    required this.anchor,
    required this.factions,
    required this.onSelect,
    required this.onDismiss,
  });

  /// Screen-space rect of the filter button.
  final Rect anchor;
  final List<String> factions;
  final ValueChanged<String?> onSelect;
  final VoidCallback onDismiss;

  static const double _menuWidth = 220;
  static const double _edgePadding = 8;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;

    // Right-align the card to the button's right edge, clamped on screen.
    final left = (anchor.right - _menuWidth)
        .clamp(_edgePadding, screen.width - _menuWidth - _edgePadding);
    final top = anchor.bottom + 4;
    final maxHeight = screen.height - top - media.padding.bottom - _edgePadding;

    return Stack(
      children: [
        // Full-screen barrier: covers everything (including the nav bar) so a
        // tap anywhere dismisses the menu and prevents stacking.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: _menuWidth,
          child: _MenuCard(
            maxHeight: maxHeight,
            factions: factions,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.maxHeight,
    required this.factions,
    required this.onSelect,
  });

  final double maxHeight;
  final List<String> factions;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          children: [
            _MenuRow(
              label: 'All Factions',
              onTap: () => onSelect(null),
            ),
            for (final factionID in factions)
              _MenuRow(
                iconPath: AppTheme.factionIconPath(factionID),
                label: AppTheme.factionDisplayName(factionID),
                onTap: () => onSelect(factionID),
              ),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.iconPath,
  });

  final String label;
  final String? iconPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.cardBorder(context).withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            if (iconPath != null) ...[
              LocalImage(iconPath, size: 20),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
