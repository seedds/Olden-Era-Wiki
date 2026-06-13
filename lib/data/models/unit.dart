import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Cost JSON structs (port of UnitCostItem/UnitCost in Database.swift).
class UnitCostItem {
  const UnitCostItem({required this.name, required this.cost});

  final String name;
  final int cost;

  factory UnitCostItem.fromJson(Map<String, dynamic> json) => UnitCostItem(
        name: json['name'] as String,
        cost: (json['cost'] as num).toInt(),
      );
}

class UnitCost {
  const UnitCost({required this.costResArray});

  final List<UnitCostItem> costResArray;

  static UnitCost? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      final items = decoded['costResArray'];
      if (items is! List) return null;
      return UnitCost(
        costResArray: [
          for (final item in items)
            UnitCostItem.fromJson(item as Map<String, dynamic>),
        ],
      );
    } catch (_) {
      return null;
    }
  }
}

class UnitListItem {
  const UnitListItem({
    required this.id,
    required this.name,
    this.tier,
    this.factionID,
    this.iconPath,
  });

  final String id;
  final String name;
  final int? tier;
  final String? factionID;
  final String? iconPath;

  factory UnitListItem.fromRow(Row row) => UnitListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        tier: row['tier'] as int?,
        factionID: row['faction_id'] as String?,
        iconPath: row['icon_path'] as String?,
      );
}

class UnitAbilitySummary {
  const UnitAbilitySummary({
    required this.id,
    this.name,
    this.description,
    required this.isActive,
    this.iconPath,
    this.rank,
    this.cooldown,
    this.energyLevel,
    this.attackType,
    this.abilityTypeSID,
    this.rawJSON,
  });

  final String id;
  final String? name;
  final String? description;
  final bool isActive;
  final String? iconPath;
  final int? rank;
  final int? cooldown;
  final int? energyLevel;
  final String? attackType;
  final String? abilityTypeSID;
  final String? rawJSON;

  factory UnitAbilitySummary.fromRow(Row row) => UnitAbilitySummary(
        id: row['id'] as String,
        name: row['name'] as String?,
        description: row['description'] as String?,
        isActive: (row['is_active'] as int? ?? 0) != 0,
        iconPath: row['icon_path'] as String?,
        rank: row['rank'] as int?,
        cooldown: row['cooldown'] as int?,
        energyLevel: row['energy_level'] as int?,
        attackType: row['attack_type'] as String?,
        abilityTypeSID: row['ability_type_sid'] as String?,
        rawJSON: row['raw_json'] as String?,
      );
}

class UnitDetail {
  const UnitDetail({
    required this.id,
    required this.name,
    this.description,
    this.narrativeDescription,
    this.tier,
    this.factionID,
    this.iconPath,
    this.baseClassName,
    this.baseClassDescription,
    this.baseClassIconPath,
    this.hp,
    this.offence,
    this.defence,
    this.damageMin,
    this.damageMax,
    this.initiative,
    this.speed,
    this.luck,
    this.luckMin,
    this.luckMax,
    this.morale,
    this.moraleMin,
    this.moraleMax,
    this.squadValue,
    this.expBonus,
    this.growth,
    this.moveType,
    this.upgradeSid,
    this.costJSON,
    required this.abilities,
  });

  final String id;
  final String name;
  final String? description;
  final String? narrativeDescription;
  final int? tier;
  final String? factionID;
  final String? iconPath;
  final String? baseClassName;
  final String? baseClassDescription;
  final String? baseClassIconPath;
  final int? hp;
  final int? offence;
  final int? defence;
  final int? damageMin;
  final int? damageMax;
  final int? initiative;
  final int? speed;
  final int? luck;
  final int? luckMin;
  final int? luckMax;
  final int? morale;
  final int? moraleMin;
  final int? moraleMax;
  final int? squadValue;
  final double? expBonus;
  final int? growth;
  final String? moveType;
  final String? upgradeSid;
  final String? costJSON;
  final List<UnitAbilitySummary> abilities;
}

class UnitUpgradeRelations {
  const UnitUpgradeRelations({
    required this.upgradeTo,
    required this.upgradeFrom,
  });

  final List<UnitListItem> upgradeTo;
  final List<UnitListItem> upgradeFrom;
}
