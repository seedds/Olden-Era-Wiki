import 'package:sqlite3/sqlite3.dart';

/// Port of AbilityCreatureSummary (Database.swift).
class AbilityCreatureSummary {
  const AbilityCreatureSummary({
    required this.unitID,
    required this.unitName,
    this.unitFactionID,
    this.unitTier,
    this.unitIconPath,
  });

  final String unitID;
  final String unitName;
  final String? unitFactionID;
  final int? unitTier;
  final String? unitIconPath;
}

/// Port of AbilityListItem (Database.swift).
class AbilityListItem {
  const AbilityListItem({
    required this.id,
    required this.name,
    this.iconPath,
    required this.variantCount,
  });

  final String id;
  final String name;
  final String? iconPath;
  final int variantCount;
}

/// Port of AbilityVariantDetail (Database.swift).
class AbilityVariantDetail {
  const AbilityVariantDetail({
    required this.id,
    this.description,
    required this.isActive,
    this.iconPath,
    this.rank,
    this.cooldown,
    this.energyLevel,
    this.attackType,
    this.abilityTypeSID,
    this.rawJSON,
    required this.creatures,
  });

  final String id;
  final String? description;
  final bool isActive;
  final String? iconPath;
  final int? rank;
  final int? cooldown;
  final int? energyLevel;
  final String? attackType;
  final String? abilityTypeSID;
  final String? rawJSON;
  final List<AbilityCreatureSummary> creatures;
}

/// Port of AbilityDetail (Database.swift).
class AbilityDetail {
  const AbilityDetail({
    required this.id,
    required this.name,
    this.iconPath,
    required this.variants,
  });

  final String id;
  final String name;
  final String? iconPath;
  final List<AbilityVariantDetail> variants;
}

/// Port of AbilityDatabaseRow (Database.swift).
class AbilityDatabaseRow {
  const AbilityDatabaseRow({
    required this.id,
    required this.unitID,
    required this.unitName,
    this.unitFactionID,
    this.unitTier,
    this.unitIconPath,
    required this.name,
    this.description,
    required this.isActive,
    this.iconPath,
    this.rank,
    this.cooldown,
    this.energyLevel,
    this.attackType,
    this.abilityTypeSID,
    this.rawJSON,
  });

  final String id;
  final String unitID;
  final String unitName;
  final String? unitFactionID;
  final int? unitTier;
  final String? unitIconPath;
  final String name;
  final String? description;
  final bool isActive;
  final String? iconPath;
  final int? rank;
  final int? cooldown;
  final int? energyLevel;
  final String? attackType;
  final String? abilityTypeSID;
  final String? rawJSON;

  factory AbilityDatabaseRow.fromRow(Row row) => AbilityDatabaseRow(
        id: row['id'] as String,
        unitID: row['unit_id'] as String,
        unitName: row['unit_name'] as String,
        unitFactionID: row['unit_faction_id'] as String?,
        unitTier: row['unit_tier'] as int?,
        unitIconPath: row['unit_icon_path'] as String?,
        name: row['name'] as String,
        description: row['description'] as String?,
        isActive: (row['is_active'] as int? ?? 0) != 0,
        iconPath: row['icon_path'] as String?,
        rank: row['rank'] as int?,
        cooldown: row['cooldown'] as int?,
        energyLevel: row['energy_level'] as int?,
        attackType: row['attack_type'] as String?,
        abilityTypeSID: row['ability_type_sid'] as String?,
        rawJSON: row['raw_json'] as String?,
      );
}
