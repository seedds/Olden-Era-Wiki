import 'package:flutter/cupertino.dart';

import '../widgets/stat_icons.dart';

/// Port of Theme.swift.
abstract final class AppTheme {
  static const Color accent = Color(0xFFE8C355);
  static const Color accentDim = Color(0xFFB8963A);

  static const Color rarityCommon = Color(0xFF4ADE80);
  static const Color rarityUncommon = Color(0xFF1FFF1F);
  static const Color rarityRare = Color(0xFF61A6FA);
  static const Color rarityEpic = Color(0xFFAC8BF8);
  static const Color rarityLegendary = Color(0xFFFF8000);
  static const Color rarityMythic = Color(0xFFE3C782);

  static const Color factionHuman = Color(0xFF5B8DEF);
  static const Color factionDemon = Color(0xFFE05555);
  static const Color factionUndead = Color(0xFF9B6DD7);
  static const Color factionNature = Color(0xFF5BBF5B);
  static const Color factionDungeon = Color(0xFFD98E4C);
  static const Color factionUnfrozen = Color(0xFF55C4D6);

  static Color background(BuildContext context) =>
      CupertinoColors.systemBackground.resolveFrom(context);

  static Color cardBackground(BuildContext context) =>
      CupertinoColors.secondarySystemBackground.resolveFrom(context);

  static Color cardBorder(BuildContext context) =>
      CupertinoColors.separator.resolveFrom(context);

  static Color textPrimary(BuildContext context) =>
      CupertinoColors.label.resolveFrom(context);

  static Color textSecondary(BuildContext context) =>
      CupertinoColors.secondaryLabel.resolveFrom(context);

  static Color statValue(BuildContext context) => textPrimary(context);

  static Color factionColor(BuildContext context, String? factionID) {
    switch (factionID) {
      case 'human':
        return factionHuman;
      case 'demon':
        return factionDemon;
      case 'undead':
        return factionUndead;
      case 'nature':
        return factionNature;
      case 'dungeon':
        return factionDungeon;
      case 'unfrozen':
        return factionUnfrozen;
      default:
        return textSecondary(context);
    }
  }

  static String factionDisplayName(String? factionID) {
    switch (factionID) {
      case 'human':
        return 'Temple';
      case 'demon':
        return 'Hive';
      case 'undead':
        return 'Necropolis';
      case 'nature':
        return 'Grove';
      case 'dungeon':
        return 'Dungeon';
      case 'unfrozen':
        return 'Schism';
      default:
        if (factionID == null || factionID.isEmpty) return 'Unknown';
        return factionID[0].toUpperCase() + factionID.substring(1);
    }
  }

  static String? factionIconPath(String? factionID) {
    if (factionID == null) return null;
    return StatIcons.pathFor('faction.$factionID');
  }

  static Color artifactRarityColor(String? rarity) {
    switch (rarity?.toLowerCase()) {
      case 'common':
        return rarityCommon;
      case 'uncommon':
        return rarityUncommon;
      case 'rare':
        return rarityRare;
      case 'epic':
        return rarityEpic;
      case 'legendary':
        return rarityLegendary;
      case 'mythic':
        return rarityMythic;
      default:
        return accent;
    }
  }
}
