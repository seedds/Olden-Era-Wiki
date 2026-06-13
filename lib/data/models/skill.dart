import 'package:sqlite3/sqlite3.dart';

/// Port of SkillListItem (Database.swift).
class SkillListItem {
  const SkillListItem({
    required this.id,
    required this.name,
    this.iconPath,
    required this.isPseudo,
    required this.maxLevel,
  });

  final String id;
  final String name;
  final String? iconPath;
  final bool isPseudo;
  final int maxLevel;

  factory SkillListItem.fromRow(Row row) => SkillListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        iconPath: row['icon_path'] as String?,
        isPseudo: (row['is_pseudo'] as int? ?? 0) != 0,
        maxLevel: row['max_level'] as int,
      );
}

/// Port of SubskillSummary (Database.swift).
class SubskillSummary {
  const SubskillSummary({
    required this.id,
    required this.name,
    this.description,
    this.iconPath,
  });

  final String id;
  final String name;
  final String? description;
  final String? iconPath;

  factory SubskillSummary.fromRow(Row row) => SubskillSummary(
        id: row['id'] as String,
        name: row['name'] as String,
        description: row['description'] as String?,
        iconPath: row['icon_path'] as String?,
      );
}

/// Port of SkillLevelDetail (Database.swift).
class SkillLevelDetail {
  const SkillLevelDetail({
    required this.level,
    this.levelName,
    this.levelIconPath,
    this.description,
    required this.subskills,
  });

  final int level;
  final String? levelName;
  final String? levelIconPath;
  final String? description;
  final List<SubskillSummary> subskills;
}

/// Port of SkillDetail (Database.swift).
class SkillDetail {
  const SkillDetail({
    required this.id,
    required this.name,
    this.iconPath,
    required this.isPseudo,
    required this.levels,
  });

  final String id;
  final String name;
  final String? iconPath;
  final bool isPseudo;
  final List<SkillLevelDetail> levels;
}
