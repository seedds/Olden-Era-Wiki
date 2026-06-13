import '../database.dart';
import '../models/spell.dart';

/// Port of the spell-related queries in Database.swift.
extension SpellsQueries on WikiDatabase {
  List<SpellListItem> listSpells() {
    final rows = db.select('''
        SELECT
          id,
          name,
          icon_path,
          school,
          rank,
          spell_type,
          used_on_map,
          MAX(level) AS max_level
        FROM spells
        GROUP BY id
        ORDER BY name
        ''');
    return [for (final row in rows) SpellListItem.fromRow(row)];
  }

  SpellDetail? fetchSpellDetail(String id) {
    final rows = db.select('''
        SELECT
          id, level, name, icon_path, school, rank, spell_type, used_on_map,
          magic_type_description, mana_cost, learn_cost_json, upgrade_cost_json, level_description
        FROM spells
        WHERE id = ?
        ORDER BY level
        ''', [id]);
    if (rows.isEmpty) return null;
    final firstRow = rows.first;

    return SpellDetail(
      id: firstRow['id'] as String,
      name: firstRow['name'] as String,
      iconPath: firstRow['icon_path'] as String?,
      school: firstRow['school'] as String?,
      rank: firstRow['rank'] as int?,
      spellType: firstRow['spell_type'] as String?,
      usedOnMap: (firstRow['used_on_map'] as int? ?? 0) != 0,
      magicTypeDescription: firstRow['magic_type_description'] as String?,
      learnCostJSON: firstRow['learn_cost_json'] as String?,
      upgradeCostJSON: firstRow['upgrade_cost_json'] as String?,
      levels: [
        for (final row in rows)
          SpellLevelDetail(
            level: row['level'] as int,
            manaCost: row['mana_cost'] as int?,
            description: row['level_description'] as String?,
          ),
      ],
    );
  }
}
