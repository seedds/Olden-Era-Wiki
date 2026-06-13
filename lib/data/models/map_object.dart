import 'package:sqlite3/sqlite3.dart';

/// Port of MapObjectListItem (Database.swift).
class MapObjectListItem {
  const MapObjectListItem({
    required this.id,
    required this.name,
    this.category,
    this.iconPath,
    this.description,
  });

  final String id;
  final String name;
  final String? category;
  final String? iconPath;
  final String? description;

  factory MapObjectListItem.fromRow(Row row) => MapObjectListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        category: row['category'] as String?,
        iconPath: row['icon_path'] as String?,
        description: row['description'] as String?,
      );
}

/// Port of MapObjectDetail (Database.swift).
class MapObjectDetail {
  const MapObjectDetail({
    required this.id,
    required this.sourceFile,
    this.category,
    this.prefabPath,
    this.iconPath,
    this.rawJSON,
    required this.name,
    this.description,
    this.narrativeDescription,
    required this.rewardVariants,
    this.bankInfo,
  });

  final String id;
  final String sourceFile;
  final String? category;
  final String? prefabPath;
  final String? iconPath;
  final String? rawJSON;
  final String name;
  final String? description;
  final String? narrativeDescription;
  final List<MapObjectRewardVariant> rewardVariants;
  final MapObjectBankInfo? bankInfo;
}

/// Port of MapObjectBankInfo (Database.swift).
class MapObjectBankInfo {
  const MapObjectBankInfo({
    this.visitType,
    required this.applyDifficultyModifier,
    required this.guardVariants,
  });

  final String? visitType;
  final bool applyDifficultyModifier;
  final List<MapObjectGuardVariant> guardVariants;
}

/// Port of MapObjectGuardVariant (Database.swift).
class MapObjectGuardVariant {
  const MapObjectGuardVariant({
    required this.variantIndex,
    this.rollChance,
    required this.guards,
  });

  final int variantIndex;
  final int? rollChance;
  final List<MapObjectGuardUnit> guards;
}

/// Port of MapObjectGuardUnit (Database.swift).
class MapObjectGuardUnit {
  const MapObjectGuardUnit({
    required this.guardIndex,
    required this.unitID,
    required this.unitName,
    this.unitIconPath,
    required this.amount,
  });

  final int guardIndex;
  final String unitID;
  final String unitName;
  final String? unitIconPath;
  final int amount;
}

/// Port of MapObjectRewardVariant (Database.swift).
class MapObjectRewardVariant {
  const MapObjectRewardVariant({
    required this.variantIndex,
    this.rollChance,
    required this.resources,
  });

  final int variantIndex;
  final int? rollChance;
  final List<MapObjectResourceReward> resources;
}

/// Port of MapObjectResourceReward (Database.swift).
class MapObjectResourceReward {
  const MapObjectResourceReward({
    required this.rewardIndex,
    required this.resourceKey,
    required this.amount,
  });

  final int rewardIndex;
  final String resourceKey;
  final int amount;
}
