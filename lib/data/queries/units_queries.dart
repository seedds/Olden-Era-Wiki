import '../database.dart';
import '../models/hero.dart';
import '../models/unit.dart';

/// Strips upgrade suffixes to derive the base unit id.
/// Port of WikiDatabase.baseUnitID(for:).
String baseUnitID(String id) {
  if (id.endsWith('_upg_alt')) return id.substring(0, id.length - 8);
  if (id.endsWith('_upg')) return id.substring(0, id.length - 4);
  return id;
}

/// Given an upgrade variant id, returns the sibling variant id by toggling the
/// suffix ("_upg" <-> "_upg_alt"). Returns null for non-variant (base) ids.
/// Port of WikiDatabase.siblingVariantID(for:).
String? siblingVariantID(String id) {
  if (id.endsWith('_upg_alt')) return '${id.substring(0, id.length - 8)}_upg';
  if (id.endsWith('_upg')) return '${id}_alt';
  return null;
}

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

  // A base unit forks into two parallel upgrades ("_upg" = path A,
  // "_upg_alt" = path B), rather than upgrading in a linear chain. The raw
  // `upgrade_sid` game data encodes the chain (base -> _upg -> _upg_alt), so
  // relations are derived from the id suffix convention instead: base upgrades
  // to both variants, each variant upgrades from the base.
  UnitUpgradeRelations fetchUnitUpgradeRelations(String unitID) {
    final baseID = baseUnitID(unitID);
    final isVariant = baseID != unitID;

    if (isVariant) {
      // Upgrade variant: no further upgrade; it upgrades FROM its base unit,
      // and links to its sibling variant as the alternative upgrade.
      final upgradeFrom = db.select('''
          SELECT id, name, tier, faction_id, icon_path
          FROM units
          WHERE id = ?
          ''', [baseID]);
      final siblingID = siblingVariantID(unitID);
      final alternativeUpgrade = <UnitListItem>[];
      if (siblingID != null) {
        final rows = db.select('''
          SELECT id, name, tier, faction_id, icon_path
          FROM units
          WHERE id = ?
          ''', [siblingID]);
        for (final row in rows) {
          alternativeUpgrade.add(UnitListItem.fromRow(row));
        }
      }
      return UnitUpgradeRelations(
        upgradeTo: const [],
        upgradeFrom: [for (final row in upgradeFrom) UnitListItem.fromRow(row)],
        alternativeUpgrade: alternativeUpgrade,
      );
    }

    // Base unit: upgrades TO both variants (whichever exist), path A ("_upg")
    // first.
    final upgVariantID = '${baseID}_upg';
    final altVariantID = '${baseID}_upg_alt';
    final upgradeTo = db.select('''
        SELECT id, name, tier, faction_id, icon_path
        FROM units
        WHERE id IN (?, ?)
        ORDER BY (id = ?) DESC
        ''', [upgVariantID, altVariantID, upgVariantID]);
    return UnitUpgradeRelations(
      upgradeTo: [for (final row in upgradeTo) UnitListItem.fromRow(row)],
      upgradeFrom: const [],
      alternativeUpgrade: const [],
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

  /// Port of WikiDatabase.fetchUnitCostJSON(unitID:).
  String? fetchUnitCostJSON(String unitID) {
    final rows = db.select(
      'SELECT unit_cost_json FROM units WHERE id = ?',
      [unitID],
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
