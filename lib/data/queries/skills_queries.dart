import '../database.dart';
import '../models/skill.dart';

/// Port of the skill-related queries in Database.swift.
extension SkillsQueries on WikiDatabase {
  List<SkillListItem> listSkills() {
    final rows = db.select('''
        SELECT
          id,
          name,
          icon_path,
          is_pseudo,
          MAX(level) AS max_level
        FROM skills
        WHERE id NOT LIKE 'arena_%'
          AND id NOT LIKE 'campaign_%'
        GROUP BY id
        HAVING SUM(CASE WHEN level_description IS NOT NULL THEN 1 ELSE 0 END) > 0
        ORDER BY name
        ''');
    return [for (final row in rows) SkillListItem.fromRow(row)];
  }

  SkillDetail? fetchSkillDetail(String id) {
    if (id.startsWith('arena_') || id.startsWith('campaign_')) {
      return null;
    }

    final skillRows = db.select('''
        SELECT id, level, name, icon_path, is_pseudo, description, level_name, level_icon_path, level_description
        FROM skills
        WHERE id = ?
        ORDER BY level
        ''', [id]);
    if (skillRows.isEmpty) return null;
    final firstRow = skillRows.first;

    final hasLevelDescription =
        skillRows.any((row) => row['level_description'] != null);
    if (!hasLevelDescription) return null;

    final subskillRows = db.select('''
        SELECT skill_level, id, name, description, icon_path
        FROM subskills
        WHERE skill_id = ?
        ORDER BY skill_level, sort_order
        ''', [id]);

    final subskillsByLevel = <int, List<SubskillSummary>>{};
    for (final row in subskillRows) {
      subskillsByLevel
          .putIfAbsent(row['skill_level'] as int, () => [])
          .add(SubskillSummary.fromRow(row));
    }

    return SkillDetail(
      id: firstRow['id'] as String,
      name: firstRow['name'] as String,
      iconPath: firstRow['icon_path'] as String?,
      isPseudo: (firstRow['is_pseudo'] as int? ?? 0) != 0,
      levels: [
        for (final row in skillRows)
          SkillLevelDetail(
            level: row['level'] as int,
            levelName: row['level_name'] as String?,
            levelIconPath: row['level_icon_path'] as String?,
            description: (row['level_description'] as String?) ??
                row['description'] as String?,
            subskills: subskillsByLevel[row['level'] as int] ?? const [],
          ),
      ],
    );
  }
}
