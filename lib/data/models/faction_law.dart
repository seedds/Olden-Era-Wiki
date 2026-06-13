import 'package:sqlite3/sqlite3.dart';

/// Port of FactionLawListItem (Database.swift).
class FactionLawListItem {
  const FactionLawListItem({
    required this.id,
    required this.name,
    this.factionID,
    this.maxLevel,
    this.iconPath,
  });

  final String id;
  final String name;
  final String? factionID;
  final int? maxLevel;
  final String? iconPath;

  factory FactionLawListItem.fromRow(Row row) => FactionLawListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        factionID: row['faction_id'] as String?,
        maxLevel: row['max_level'] as int?,
        iconPath: row['icon_path'] as String?,
      );
}

/// Port of FactionLawLevelDetail (Database.swift).
class FactionLawLevelDetail {
  const FactionLawLevelDetail({
    required this.level,
    this.cost,
    this.bonusCount,
    this.description,
  });

  final int level;
  final int? cost;
  final int? bonusCount;
  final String? description;

  factory FactionLawLevelDetail.fromRow(Row row) => FactionLawLevelDetail(
        level: row['level'] as int,
        cost: row['cost'] as int?,
        bonusCount: row['bonus_count'] as int?,
        description: row['level_description'] as String?,
      );
}

/// Port of FactionLawDetail (Database.swift).
class FactionLawDetail {
  const FactionLawDetail({
    required this.id,
    required this.name,
    this.factionID,
    this.maxLevel,
    this.iconPath,
    required this.levels,
  });

  final String id;
  final String name;
  final String? factionID;
  final int? maxLevel;
  final String? iconPath;
  final List<FactionLawLevelDetail> levels;
}
