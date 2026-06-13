import 'package:flutter/cupertino.dart';

import '../data/models/hero.dart';
import '../routes.dart';
import '../theme/app_theme.dart';
import 'faction_label.dart';
import 'local_image.dart';

/// Hero card row (port of the hero rows in StartingHeroesSection /
/// HeroesListView).
class HeroRow extends StatelessWidget {
  const HeroRow({super.key, required this.hero});

  final HeroListItem hero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushHeroDetail(context, hero.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.cardBorder(context)),
        ),
        child: Row(
          children: [
            LocalImage(hero.portraitPath,
                size: 44, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hero.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  if (hero.factionID != null) ...[
                    const SizedBox(height: 4),
                    DefaultTextStyle(
                      style: const TextStyle(fontSize: 12),
                      child: FactionLabel(
                          factionID: hero.factionID, iconSize: 14),
                    ),
                  ],
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
