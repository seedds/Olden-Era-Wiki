import 'package:sqlite3/sqlite3.dart';

class HeroListItem {
  const HeroListItem({
    required this.id,
    required this.name,
    this.portraitPath,
    this.factionID,
    this.classType,
    this.startLevel,
  });

  final String id;
  final String name;
  final String? portraitPath;
  final String? factionID;
  final String? classType;
  final int? startLevel;

  factory HeroListItem.fromRow(Row row) => HeroListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        portraitPath: row['portrait_path'] as String?,
        factionID: row['faction_id'] as String?,
        classType: row['class_type'] as String?,
        startLevel: row['start_level'] as int?,
      );
}

class HeroDetail {
  const HeroDetail({
    required this.id,
    required this.name,
    this.portraitPath,
    this.factionID,
    this.classType,
    this.specializationID,
    this.specializationName,
    this.nativeBiome,
    this.costGold,
    this.startLevel,
    this.classIconPath,
    this.specializationIconPath,
    this.startStatsJSON,
    this.rawJSON,
    this.description,
    this.motto,
    this.specializationDescription,
  });

  final String id;
  final String name;
  final String? portraitPath;
  final String? factionID;
  final String? classType;
  final String? specializationID;
  final String? specializationName;
  final String? nativeBiome;
  final int? costGold;
  final int? startLevel;
  final String? classIconPath;
  final String? specializationIconPath;
  final String? startStatsJSON;
  final String? rawJSON;
  final String? description;
  final String? motto;
  final String? specializationDescription;
}

class HeroStartingSkillItem {
  const HeroStartingSkillItem({
    required this.skillID,
    required this.name,
    this.iconPath,
    required this.level,
  });

  final String skillID;
  final String name;
  final String? iconPath;
  final int level;
}

class HeroStartingSpellItem {
  const HeroStartingSpellItem({
    required this.spellID,
    required this.name,
    this.iconPath,
    required this.level,
  });

  final String spellID;
  final String name;
  final String? iconPath;
  final int level;
}

class HeroStartingSquadItem {
  const HeroStartingSquadItem({
    required this.variant,
    required this.slotIndex,
    this.unitID,
    this.unitName,
    this.unitIconPath,
    this.unitFactionID,
    this.unitTier,
    this.minCount,
    this.maxCount,
  });

  final String variant;
  final int slotIndex;
  final String? unitID;
  final String? unitName;
  final String? unitIconPath;
  final String? unitFactionID;
  final int? unitTier;
  final int? minCount;
  final int? maxCount;
}
