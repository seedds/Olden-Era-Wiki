import 'package:sqlite3/sqlite3.dart';

/// Port of ArtifactListItem (Database.swift).
class ArtifactListItem {
  const ArtifactListItem({
    required this.id,
    required this.name,
    this.iconPath,
    this.slot,
    this.rarity,
    this.itemSetID,
    this.maxLevel,
    this.goodsValue,
    this.bonusCount,
    this.bonusType,
  });

  final String id;
  final String name;
  final String? iconPath;
  final String? slot;
  final String? rarity;
  final String? itemSetID;
  final int? maxLevel;
  final int? goodsValue;
  final int? bonusCount;
  final String? bonusType;

  factory ArtifactListItem.fromRow(Row row) => ArtifactListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        iconPath: row['icon_path'] as String?,
        slot: row['slot'] as String?,
        rarity: row['rarity'] as String?,
        itemSetID: row['item_set_id'] as String?,
        maxLevel: row['max_level'] as int?,
        goodsValue: row['goods_value'] as int?,
        bonusCount: row['bonus_count'] as int?,
        bonusType: row['bonus_type'] as String?,
      );
}

/// Port of ArtifactLevelDetail (Database.swift).
class ArtifactLevelDetail {
  const ArtifactLevelDetail({
    required this.level,
    this.description,
    this.upgradeDescription,
  });

  final int level;
  final String? description;
  final String? upgradeDescription;
}

/// Port of ArtifactSetBonus (Database.swift). Decoded from the
/// `bonuses_json` column of `item_sets`.
class ArtifactSetBonus {
  const ArtifactSetBonus({this.requiredItemsAmount, this.description});

  final int? requiredItemsAmount;
  final String? description;

  factory ArtifactSetBonus.fromJson(Map<String, dynamic> json) =>
      ArtifactSetBonus(
        requiredItemsAmount: (json['required_items_amount'] as num?)?.toInt(),
        description: json['description'] as String?,
      );
}

/// Port of ArtifactSetMember (Database.swift).
class ArtifactSetMember {
  const ArtifactSetMember({
    required this.id,
    required this.name,
    this.iconPath,
    this.rarity,
  });

  final String id;
  final String name;
  final String? iconPath;
  final String? rarity;

  factory ArtifactSetMember.fromRow(Row row) => ArtifactSetMember(
        id: row['id'] as String,
        name: row['name'] as String,
        iconPath: row['icon_path'] as String?,
        rarity: row['rarity'] as String?,
      );
}

/// Port of ArtifactSetDetail (Database.swift).
class ArtifactSetDetail {
  const ArtifactSetDetail({
    required this.id,
    required this.name,
    this.description,
    required this.itemCount,
    required this.bonusCount,
    required this.bonuses,
    required this.members,
  });

  final String id;
  final String name;
  final String? description;
  final int itemCount;
  final int bonusCount;
  final List<ArtifactSetBonus> bonuses;
  final List<ArtifactSetMember> members;
}

/// Port of ArtifactDetail (Database.swift).
class ArtifactDetail {
  const ArtifactDetail({
    required this.id,
    required this.name,
    this.narrativeDescription,
    this.iconPath,
    this.slot,
    this.rarity,
    this.itemSetID,
    required this.maxLevel,
    this.goodsValue,
    this.costBase,
    this.costPerLevel,
    this.rewardForDestroy,
    this.bonusCount,
    this.bonusType,
    this.itemSet,
    required this.levels,
  });

  final String id;
  final String name;
  final String? narrativeDescription;
  final String? iconPath;
  final String? slot;
  final String? rarity;
  final String? itemSetID;
  final int maxLevel;
  final int? goodsValue;
  final int? costBase;
  final int? costPerLevel;
  final int? rewardForDestroy;
  final int? bonusCount;
  final String? bonusType;
  final ArtifactSetDetail? itemSet;
  final List<ArtifactLevelDetail> levels;
}
