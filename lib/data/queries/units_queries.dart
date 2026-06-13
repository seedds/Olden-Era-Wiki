import '../database.dart';
import '../models/hero.dart';
import '../models/unit.dart';

/// Port of the unit-related queries in Database.swift.
extension UnitsQueries on WikiDatabase {
  List<UnitListItem> listUnits({String? search, String? factionID}) {
    var sql = '''
        SELECT id, name, tier, faction_id, icon_path
        FROM units
        WHERE 1=1
        ''';
    final arguments = <Object?>[];

    if (factionID != null) {
      sql += ' AND faction_id = ?';
      arguments.add(factionID);
    }
    if (search != null && search.isNotEmpty) {
      sql += ' AND name LIKE ?';
      arguments.add('%$search%');
    }
    sql += ' ORDER BY tier, faction_id, name';

    return [
      for (final row in db.select(sql, arguments)) UnitListItem.fromRow(row),
    ];
  }

  UnitDetail? fetchUnitDetail(String id) {
    final rows = db.select('''
        SELECT
          id, name, description, narrative_description,
          tier, faction_id, icon_path,
          base_class_name, base_class_description, base_class_icon_path,
          hp, offence, defence, damage_min, damage_max,
          initiative, speed, luck, luck_min, luck_max, morale, morale_min, morale_max,
          squad_value, exp_bonus, growth, move_type, upgrade_sid, unit_cost_json
        FROM units
        WHERE id = ?
        ''', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;

    final abilityRows = db.select('''
        SELECT
          id, name, description, is_active, icon_path,
          rank, cooldown, energy_level, attack_type, ability_type_sid, raw_json
        FROM unit_abilities
        WHERE unit_id = ?
          AND name IS NOT NULL
          AND trim(name) <> ''
          AND icon_path IS NOT NULL
        ORDER BY sort_order
        ''', [id]);

    return UnitDetail(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      narrativeDescription: row['narrative_description'] as String?,
      tier: row['tier'] as int?,
      factionID: row['faction_id'] as String?,
      iconPath: row['icon_path'] as String?,
      baseClassName: row['base_class_name'] as String?,
      baseClassDescription: row['base_class_description'] as String?,
      baseClassIconPath: row['base_class_icon_path'] as String?,
      hp: row['hp'] as int?,
      offence: row['offence'] as int?,
      defence: row['defence'] as int?,
      damageMin: row['damage_min'] as int?,
      damageMax: row['damage_max'] as int?,
      initiative: row['initiative'] as int?,
      speed: row['speed'] as int?,
      luck: row['luck'] as int?,
      luckMin: row['luck_min'] as int?,
      luckMax: row['luck_max'] as int?,
      morale: row['morale'] as int?,
      moraleMin: row['morale_min'] as int?,
      moraleMax: row['morale_max'] as int?,
      squadValue: row['squad_value'] as int?,
      expBonus: (row['exp_bonus'] as num?)?.toDouble(),
      growth: row['growth'] as int?,
      moveType: row['move_type'] as String?,
      upgradeSid: row['upgrade_sid'] as String?,
      costJSON: row['unit_cost_json'] as String?,
      abilities: [
        for (final abilityRow in abilityRows)
          UnitAbilitySummary.fromRow(abilityRow),
      ],
    );
  }

  UnitUpgradeRelations fetchUnitUpgradeRelations(String unitID) {
    final upgradeTo = db.select('''
        SELECT u.id, u.name, u.tier, u.faction_id, u.icon_path
        FROM units u
        JOIN units base ON base.upgrade_sid = u.id
        WHERE base.id = ?
        ORDER BY u.name COLLATE NOCASE, u.id
        ''', [unitID]);

    final upgradeFrom = db.select('''
        SELECT id, name, tier, faction_id, icon_path
        FROM units
        WHERE upgrade_sid = ?
        ORDER BY name COLLATE NOCASE, id
        ''', [unitID]);

    return UnitUpgradeRelations(
      upgradeTo: [for (final row in upgradeTo) UnitListItem.fromRow(row)],
      upgradeFrom: [for (final row in upgradeFrom) UnitListItem.fromRow(row)],
    );
  }

  List<HeroListItem> fetchStartingHeroes(String unitID) {
    final rows = db.select('''
        SELECT DISTINCT h.id, h.name, h.portrait_path, h.faction_id, h.class_type, h.start_level
        FROM heroes h
        JOIN hero_start_squads hss ON h.id = hss.hero_id
        WHERE hss.unit_id = ?
          AND h.id NOT LIKE 'campaign_%'
          AND h.id NOT LIKE 'tutorial_%'
        ORDER BY h.name
        ''', [unitID]);
    return [for (final row in rows) HeroListItem.fromRow(row)];
  }

  String? fetchUpgradeCost(String upgradeSid) {
    final rows = db.select(
      'SELECT unit_cost_json FROM units WHERE id = ?',
      [upgradeSid],
    );
    if (rows.isEmpty) return null;
    return rows.first['unit_cost_json'] as String?;
  }

  List<String> fetchFactions() {
    final rows = db.select(
      'SELECT DISTINCT faction_id FROM units WHERE faction_id IS NOT NULL ORDER BY faction_id',
    );
    return [for (final row in rows) row['faction_id'] as String];
  }
}
