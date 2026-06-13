import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';
import 'local_image.dart';

/// Port of FactionLabel from Theme.swift.
class FactionLabel extends StatelessWidget {
  const FactionLabel({super.key, required this.factionID, this.iconSize = 18});

  final String? factionID;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final iconPath = AppTheme.factionIconPath(factionID);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconPath != null) ...[
          LocalImage(iconPath, size: iconSize),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            AppTheme.factionDisplayName(factionID),
            style: TextStyle(color: AppTheme.factionColor(context, factionID)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
