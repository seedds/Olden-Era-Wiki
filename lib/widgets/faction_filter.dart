import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import 'local_image.dart';

/// Port of FactionFilterToolbar (ListScreenSupport.swift): a nav-bar button
/// that shows a faction picker.
class FactionFilterButton extends StatelessWidget {
  const FactionFilterButton({
    super.key,
    required this.factions,
    required this.onSelect,
  });

  final List<String> factions;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPicker(context),
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

  void _showPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(popupContext).pop();
              onSelect(null);
            },
            child: const Text('All Factions'),
          ),
          for (final factionID in factions)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                onSelect(factionID);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  LocalImage(AppTheme.factionIconPath(factionID), size: 20),
                  const SizedBox(width: 8),
                  Text(AppTheme.factionDisplayName(factionID)),
                ],
              ),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
