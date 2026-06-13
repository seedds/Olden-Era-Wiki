import 'package:flutter/cupertino.dart';

import '../data/models/unit.dart';
import '../routes.dart';
import '../theme/app_theme.dart';
import 'local_image.dart';

/// Port of UnitRowView (UnitsListView.swift), used by the units list and the
/// upgrade-links sections on the unit detail screen.
class UnitRow extends StatelessWidget {
  const UnitRow({super.key, required this.unit});

  final UnitListItem unit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushUnitDetail(context, unit.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(unit.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    unit.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (unit.tier != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Tier ${unit.tier}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      LocalImage(AppTheme.factionIconPath(unit.factionID),
                          size: 18),
                      const SizedBox(width: 4),
                      Text(
                        AppTheme.factionDisplayName(unit.factionID),
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              AppTheme.factionColor(context, unit.factionID),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}
