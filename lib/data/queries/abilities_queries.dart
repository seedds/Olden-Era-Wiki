import 'dart:convert';

import '../database.dart';
import '../models/ability.dart';

/// Port of AbilityGroupKey (Database.swift). Dart records have structural
/// ==/hashCode, matching the Swift Hashable struct.
typedef AbilityGroupKey = ({
  String name,
  String? description,
  bool isActive,
  String? iconPath,
  int? rank,
  int? cooldown,
  int? energyLevel,
  String? attackType,
  String? abilityTypeSID,
  bool endsTurn,
  bool spendsFocusCharges,
});

/// One merged ability variant: the representative row plus every creature
/// sharing that variant (Swift's `(row:creatures:)` tuple).
typedef MergedAbilityVariant = ({
  AbilityDatabaseRow row,
  List<AbilityCreatureSummary> creatures,
});

/// Port of abilityGroupKey(for:) (Database.swift).
AbilityGroupKey abilityGroupKey(AbilityDatabaseRow row) {
  final helperFlags = abilityHelperFlags(row.rawJSON);
  return (
    name: row.name,
    description: row.description,
    isActive: row.isActive,
    iconPath: row.iconPath,
    rank: row.rank,
    cooldown: row.cooldown,
    energyLevel: row.energyLevel,
    attackType: row.attackType,
    abilityTypeSID: row.abilityTypeSID,
    endsTurn: helperFlags.endsTurn,
    spendsFocusCharges: helperFlags.spendsFocusCharges,
  );
}

/// Port of abilityHelperFlags(rawJSON:) (Database.swift).
///
/// Swift semantics: `(raw["actionCost"] as? Int) != 0` is true when the key
/// is absent or not an Int (nil != 0), false only for an actual 0; likewise
/// `(raw["dontUseEnergy"] as? Bool) != true` is false only for an actual
/// `true`. Missing or invalid JSON yields (true, true).
({bool endsTurn, bool spendsFocusCharges}) abilityHelperFlags(String? rawJSON) {
  const fallback = (endsTurn: true, spendsFocusCharges: true);
  if (rawJSON == null) return fallback;

  final Map<String, dynamic> raw;
  try {
    final decoded = jsonDecode(rawJSON);
    if (decoded is! Map<String, dynamic>) return fallback;
    raw = decoded;
  } catch (_) {
    return fallback;
  }

  final actionCost = raw['actionCost'];
  final dontUseEnergy = raw['dontUseEnergy'];
  final endsTurn = actionCost is! int || actionCost != 0;
  final spendsFocusCharges = !(dontUseEnergy is bool && dontUseEnergy == true);
  return (endsTurn: endsTurn, spendsFocusCharges: spendsFocusCharges);
}

/// Port of creatureSummary(from:) (Database.swift).
AbilityCreatureSummary creatureSummary(AbilityDatabaseRow row) =>
    AbilityCreatureSummary(
      unitID: row.unitID,
      unitName: row.unitName,
      unitFactionID: row.unitFactionID,
      unitTier: row.unitTier,
      unitIconPath: row.unitIconPath,
    );

/// Port of mergeAbilityRows(_:) (Database.swift). Rows whose group key
/// matches are merged into a single variant collecting all their creatures.
/// Insertion order of groups is preserved (Dart map literals are
/// LinkedHashMaps).
List<MergedAbilityVariant> mergeAbilityRows(List<AbilityDatabaseRow> rows) {
  final groups = <AbilityGroupKey, MergedAbilityVariant>{};

  for (final row in rows) {
    final key = abilityGroupKey(row);
    final group = groups[key];
    if (group != null) {
      group.creatures.add(creatureSummary(row));
    } else {
      groups[key] = (row: row, creatures: [creatureSummary(row)]);
    }
  }

  for (final group in groups.values) {
    group.creatures.sort(_compareCreatures);
  }
  return groups.values.toList();
}

/// Case-insensitive name compare; equal names sort by tier (null = max).
int _compareCreatures(AbilityCreatureSummary a, AbilityCreatureSummary b) {
  final nameCompare =
      a.unitName.toLowerCase().compareTo(b.unitName.toLowerCase());
  if (nameCompare != 0) return nameCompare;
  const maxTier = 1 << 62;
  return (a.unitTier ?? maxTier).compareTo(b.unitTier ?? maxTier);
}

/// Port of groupedAbilityListItems(from:) (Database.swift).
List<AbilityListItem> groupedAbilityListItems(List<AbilityDatabaseRow> rows) {
  final rowsByName = <String, List<AbilityDatabaseRow>>{};
  for (final row in rows) {
    rowsByName.putIfAbsent(row.name, () => []).add(row);
  }

  final items = <AbilityListItem>[];
  for (final nameRows in rowsByName.values) {
    final variants = mergeAbilityRows(nameRows);
    if (variants.isEmpty) continue;
    final representative = variants.first;

    items.add(AbilityListItem(
      id: representative.row.id,
      name: representative.row.name,
      iconPath: representative.row.iconPath,
      variantCount: variants.length,
    ));
  }
  return items;
}

/// Port of abilityVariantDetail(from:) (Database.swift).
AbilityVariantDetail _abilityVariantDetail(MergedAbilityVariant merged) {
  final row = merged.row;
  return AbilityVariantDetail(
    id: row.id,
    description: row.description,
    isActive: row.isActive,
    iconPath: row.iconPath,
    rank: row.rank,
    cooldown: row.cooldown,
    energyLevel: row.energyLevel,
    attackType: row.attackType,
    abilityTypeSID: row.abilityTypeSID,
    rawJSON: row.rawJSON,
    creatures: merged.creatures,
  );
}

/// Port of the ability-related queries in Database.swift.
extension AbilitiesQueries on WikiDatabase {
  List<AbilityListItem> listAbilities() {
    final rows = db.select('''
        SELECT
          ua.id,
          ua.unit_id,
          u.name AS unit_name,
          u.faction_id AS unit_faction_id,
          u.tier AS unit_tier,
          u.icon_path AS unit_icon_path,
          ua.name,
          ua.description,
          ua.is_active,
          ua.icon_path,
          ua.rank,
          ua.cooldown,
          ua.energy_level,
          ua.attack_type,
          ua.ability_type_sid,
          ua.raw_json
        FROM unit_abilities ua
        JOIN units u ON u.id = ua.unit_id
        WHERE ua.name IS NOT NULL
          AND trim(ua.name) <> ''
          AND ua.icon_path IS NOT NULL
        ORDER BY ua.name COLLATE NOCASE, u.name COLLATE NOCASE, ua.id
        ''');

    return groupedAbilityListItems(
      [for (final row in rows) AbilityDatabaseRow.fromRow(row)],
    );
  }

  AbilityDetail? fetchAbilityDetail(String id) {
    final selectedRows = db.select('''
        SELECT
          ua.id,
          ua.unit_id,
          u.name AS unit_name,
          u.faction_id AS unit_faction_id,
          u.tier AS unit_tier,
          u.icon_path AS unit_icon_path,
          ua.name,
          ua.description,
          ua.is_active,
          ua.icon_path,
          ua.rank,
          ua.cooldown,
          ua.energy_level,
          ua.attack_type,
          ua.ability_type_sid,
          ua.raw_json
        FROM unit_abilities ua
        JOIN units u ON u.id = ua.unit_id
        WHERE ua.id = ?
          AND ua.name IS NOT NULL
          AND trim(ua.name) <> ''
        ''', [id]);
    if (selectedRows.isEmpty) return null;
    final selectedRow = AbilityDatabaseRow.fromRow(selectedRows.first);

    final rows = db.select('''
        SELECT
          ua.id,
          ua.unit_id,
          u.name AS unit_name,
          u.faction_id AS unit_faction_id,
          u.tier AS unit_tier,
          u.icon_path AS unit_icon_path,
          ua.name,
          ua.description,
          ua.is_active,
          ua.icon_path,
          ua.rank,
          ua.cooldown,
          ua.energy_level,
          ua.attack_type,
          ua.ability_type_sid,
          ua.raw_json
        FROM unit_abilities ua
        JOIN units u ON u.id = ua.unit_id
        WHERE ua.name = ?
          AND ua.icon_path IS NOT NULL
        ORDER BY ua.rank, ua.is_active DESC, ua.description COLLATE NOCASE, u.name COLLATE NOCASE, ua.id
        ''', [selectedRow.name]);

    final variants = [
      for (final merged in mergeAbilityRows(
        [for (final row in rows) AbilityDatabaseRow.fromRow(row)],
      ))
        _abilityVariantDetail(merged),
    ];
    if (variants.isEmpty) return null;

    return AbilityDetail(
      id: selectedRow.id,
      name: selectedRow.name,
      iconPath: variants.first.iconPath ?? selectedRow.iconPath,
      variants: variants,
    );
  }
}
