import 'dart:convert';

import '../database.dart';
import '../models/subclass.dart';

/// Port of decodeJSONList (Database.swift) for subclass requirement entries.
List<SubclassRequirementJSON> _decodeRequirements(String? json) {
  if (json == null) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        SubclassRequirementJSON.fromJson(item as Map<String, dynamic>),
    ];
  } catch (_) {
    return const [];
  }
}

class _RequiredSkillRow {
  const _RequiredSkillRow({
    required this.id,
    required this.level,
    required this.name,
    this.levelName,
    this.iconPath,
    this.levelIconPath,
  });

  final String id;
  final int level;
  final String name;
  final String? levelName;
  final String? iconPath;
  final String? levelIconPath;
}

/// Port of the subclass queries in Database.swift.
extension SubclassesQueries on WikiDatabase {
  List<SubclassListItem> listSubclasses() {
    final rows = db.select('''
        SELECT id, name, faction_id, class_type, icon_path, description
        FROM subclasses
        ORDER BY faction_id, class_type, name
        ''');
    return [for (final row in rows) SubclassListItem.fromRow(row)];
  }

  SubclassDetail? fetchSubclassDetail(String id) {
    final rows = db.select('''
        SELECT
            id,
            name,
            faction_id,
            class_type,
            icon_path,
            description,
            bonus_type,
            bonus_count,
            activation_conditions_json
        FROM subclasses
        WHERE id = ?
        ''', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;

    final requirements =
        _decodeRequirements(row['activation_conditions_json'] as String?);

    final List<_RequiredSkillRow> requiredSkillRows;
    if (requirements.isEmpty) {
      requiredSkillRows = const [];
    } else {
      final tuplePlaceholders =
          [for (final _ in requirements) '(?, ?)'].join(', ');
      final args = <Object?>[];
      for (final req in requirements) {
        args.add(req.skillSid);
        args.add(req.skillLevel);
      }
      requiredSkillRows = [
        for (final skillRow in db.select('''
            SELECT id, level, name, level_name, icon_path, level_icon_path
            FROM skills
            WHERE (id, level) IN ($tuplePlaceholders)
            ''', args))
          _RequiredSkillRow(
            id: skillRow['id'] as String,
            level: skillRow['level'] as int,
            name: skillRow['name'] as String,
            levelName: skillRow['level_name'] as String?,
            iconPath: skillRow['icon_path'] as String?,
            levelIconPath: skillRow['level_icon_path'] as String?,
          ),
      ];
    }

    final requiredSkillsByID = {
      for (final skill in requiredSkillRows) skill.id: skill,
    };
    final requiredSkills = <SubclassRequiredSkill>[];
    for (final requirement in requirements) {
      final skill = requiredSkillsByID[requirement.skillSid];
      if (skill == null) continue;

      requiredSkills.add(SubclassRequiredSkill(
        skillID: skill.id,
        skillName: skill.levelName ?? skill.name,
        skillLevel: requirement.skillLevel,
        iconPath: skill.levelIconPath ?? skill.iconPath,
      ));
    }

    return SubclassDetail(
      id: row['id'] as String,
      name: row['name'] as String,
      factionID: row['faction_id'] as String?,
      classType: row['class_type'] as String?,
      iconPath: row['icon_path'] as String?,
      description: row['description'] as String?,
      bonusType: row['bonus_type'] as String?,
      bonusCount: row['bonus_count'] as int?,
      requiredSkills: requiredSkills,
    );
  }
}
