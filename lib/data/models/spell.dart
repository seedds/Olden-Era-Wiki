import 'package:sqlite3/sqlite3.dart';

/// Port of SpellListItem (Database.swift).
class SpellListItem {
  const SpellListItem({
    required this.id,
    required this.name,
    this.iconPath,
    this.school,
    this.rank,
    this.spellType,
    required this.usedOnMap,
    required this.maxLevel,
  });

  final String id;
  final String name;
  final String? iconPath;
  final String? school;
  final int? rank;
  final String? spellType;
  final bool usedOnMap;
  final int maxLevel;

  factory SpellListItem.fromRow(Row row) => SpellListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        iconPath: row['icon_path'] as String?,
        school: row['school'] as String?,
        rank: row['rank'] as int?,
        spellType: row['spell_type'] as String?,
        usedOnMap: (row['used_on_map'] as int? ?? 0) != 0,
        maxLevel: row['max_level'] as int,
      );
}

/// Port of SpellLevelDetail (Database.swift).
class SpellLevelDetail {
  const SpellLevelDetail({
    required this.level,
    this.manaCost,
    this.description,
  });

  final int level;
  final int? manaCost;
  final String? description;
}

/// Port of SpellDetail (Database.swift).
class SpellDetail {
  const SpellDetail({
    required this.id,
    required this.name,
    this.iconPath,
    this.school,
    this.rank,
    this.spellType,
    required this.usedOnMap,
    this.magicTypeDescription,
    this.learnCostJSON,
    this.upgradeCostJSON,
    required this.levels,
  });

  final String id;
  final String name;
  final String? iconPath;
  final String? school;
  final int? rank;
  final String? spellType;
  final bool usedOnMap;
  final String? magicTypeDescription;
  final String? learnCostJSON;
  final String? upgradeCostJSON;
  final List<SpellLevelDetail> levels;
}
