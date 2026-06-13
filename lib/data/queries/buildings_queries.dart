import 'dart:convert';

import '../database.dart';
import '../models/building.dart';
import '../models/unit.dart';

/// Port of decodeJSONList (Database.swift) for building requirement entries.
List<BuildingRequirementJSON> _decodeRequirements(String? json) {
  if (json == null) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        BuildingRequirementJSON.fromJson(item as Map<String, dynamic>),
    ];
  } catch (_) {
    return const [];
  }
}

/// Port of decodeJSONList (Database.swift) for building cost entries.
List<BuildingCostItem> _decodeCosts(String? json) {
  if (json == null) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        BuildingCostItem.fromJson(item as Map<String, dynamic>),
    ];
  } catch (_) {
    return const [];
  }
}

/// Port of the building-related queries in Database.swift.
extension BuildingsQueries on WikiDatabase {
  List<BuildingListItem> listBuildings() {
    final rows = db.select('''
        SELECT
            id || ':' || level AS entity_id,
            id,
            level,
            COALESCE(name, id) AS name,
            icon_path,
            faction_id,
            group_name,
            weekly_growth
        FROM buildings
        WHERE name IS NOT NULL
        ORDER BY faction_id, group_name, name, level
        ''');
    return [for (final row in rows) BuildingListItem.fromRow(row)];
  }

  BuildingDetail? fetchBuildingDetail(String entityID) {
    final key = parseBuildingEntityID(entityID);
    if (key == null) return null;

    final rows = db.select('''
        SELECT
            id,
            level,
            COALESCE(name, id) AS name,
            description,
            icon_path,
            faction_id,
            group_name,
            scene_slot,
            is_constructed_on_start,
            level_on_start,
            weekly_growth,
            cost_json,
            prev_buildings_json,
            units_hire_json
        FROM buildings
        WHERE id = ? AND level = ?
        ''', [key.buildingID, key.level]);
    if (rows.isEmpty) return null;
    final row = rows.first;

    final id = row['id'] as String;
    final level = row['level'] as int;
    final factionID = row['faction_id'] as String?;
    final requirements =
        _decodeRequirements(row['prev_buildings_json'] as String?);

    return BuildingDetail(
      entityID: buildingEntityID(id, level),
      id: id,
      level: level,
      name: row['name'] as String,
      description: row['description'] as String?,
      iconPath: row['icon_path'] as String?,
      factionID: factionID,
      groupName: row['group_name'] as String?,
      sceneSlot: row['scene_slot'] as String?,
      isConstructedOnStart:
          (row['is_constructed_on_start'] as int? ?? 0) != 0,
      levelOnStart: row['level_on_start'] as int?,
      weeklyGrowth: row['weekly_growth'] as int?,
      costs: _decodeCosts(row['cost_json'] as String?),
      recruitCreatures:
          _fetchRecruitCreatures(row['units_hire_json'] as String?),
      requiredBuildings: _fetchBuildingLinks(
        requirements: requirements,
        factionID: factionID,
      ),
      unlockedBuildings: _fetchUnlockedBuildings(
        buildingID: id,
        level: level,
        factionID: factionID,
      ),
    );
  }

  /// Port of fetchBuildingLinks (Database.swift).
  List<BuildingLinkItem> _fetchBuildingLinks({
    required List<BuildingRequirementJSON> requirements,
    required String? factionID,
  }) {
    if (requirements.isEmpty) return const [];

    return [
      for (final requirement in requirements)
        _resolveBuildingLink(requirement, factionID),
    ];
  }

  BuildingLinkItem _resolveBuildingLink(
    BuildingRequirementJSON requirement,
    String? factionID,
  ) {
    final requiredLevel = requirement.level ?? 1;
    final requiredID = factionID != null
        ? '$factionID:${requirement.sid}'
        : requirement.sid;

    final rows = db.select('''
        SELECT
            id || ':' || level AS entity_id,
            id,
            level,
            COALESCE(name, id) AS name,
            icon_path,
            faction_id,
            group_name,
            weekly_growth
        FROM buildings
        WHERE id = ? AND level = ?
        ''', [requiredID, requiredLevel]);

    if (rows.isNotEmpty) {
      final row = BuildingListItem.fromRow(rows.first);
      return BuildingLinkItem(
        entityID: row.entityID,
        buildingID: row.buildingID,
        level: row.level,
        name: row.name,
        iconPath: row.iconPath,
        factionID: row.factionID,
        groupName: row.groupName,
      );
    }

    return BuildingLinkItem(
      entityID: null,
      buildingID: requiredID,
      level: requiredLevel,
      name: '${requirement.sid} Lv $requiredLevel',
      iconPath: null,
      factionID: factionID,
      groupName: null,
    );
  }

  /// Port of fetchUnlockedBuildings (Database.swift): scans all of the
  /// faction's buildings' prev_buildings_json for a match on sid + level.
  /// `faction_id IS ?` matches NULL when factionID is null.
  List<BuildingLinkItem> _fetchUnlockedBuildings({
    required String buildingID,
    required int level,
    required String? factionID,
  }) {
    final sid = buildingFactionPrefix(buildingID).sid;

    final rows = db.select('''
        SELECT id, level, COALESCE(name, id) AS name, icon_path, faction_id, group_name, prev_buildings_json
        FROM buildings
        WHERE faction_id IS ?
          AND prev_buildings_json IS NOT NULL
        ORDER BY group_name, name, level
        ''', [factionID]);

    final links = <BuildingLinkItem>[];
    for (final row in rows) {
      final requirements =
          _decodeRequirements(row['prev_buildings_json'] as String?);
      final matches = requirements.any(
        (requirement) =>
            requirement.sid == sid && (requirement.level ?? 1) == level,
      );
      if (!matches) continue;

      links.add(BuildingLinkItem(
        entityID: buildingEntityID(row['id'] as String, row['level'] as int),
        buildingID: row['id'] as String,
        level: row['level'] as int,
        name: row['name'] as String,
        iconPath: row['icon_path'] as String?,
        factionID: row['faction_id'] as String?,
        groupName: row['group_name'] as String?,
      ));
    }
    return links;
  }

  /// Port of fetchRecruitCreatures (Database.swift).
  List<BuildingRecruitCreature> _fetchRecruitCreatures(
    String? unitsHireJSON,
  ) {
    if (unitsHireJSON == null) return const [];

    BuildingHireJSON decoded;
    try {
      final json = jsonDecode(unitsHireJSON);
      if (json is! Map<String, dynamic>) return const [];
      decoded = BuildingHireJSON.fromJson(json);
    } catch (_) {
      return const [];
    }

    final unitIDs = [
      for (final hireUnit in decoded.units) ...hireUnit.sids,
    ];
    if (unitIDs.isEmpty) return const [];

    final placeholders = [for (final _ in unitIDs) '?'].join(', ');
    final rows = db.select('''
        SELECT id, name, tier, faction_id, icon_path
        FROM units
        WHERE id IN ($placeholders)
        ''', unitIDs);
    final unitsByID = {
      for (final row in rows) row['id'] as String: UnitListItem.fromRow(row),
    };

    return [
      for (final hireUnit in decoded.units)
        for (final unitID in hireUnit.sids)
          _recruitCreature(unitsByID[unitID], unitID, hireUnit.weeklyIncrement),
    ];
  }

  BuildingRecruitCreature _recruitCreature(
    UnitListItem? unit,
    String unitID,
    int? weeklyIncrement,
  ) {
    if (unit != null) {
      return BuildingRecruitCreature(
        unitID: unit.id,
        unitName: unit.name,
        unitIconPath: unit.iconPath,
        unitFactionID: unit.factionID,
        unitTier: unit.tier,
        weeklyGrowth: weeklyIncrement,
      );
    }

    return BuildingRecruitCreature(
      unitID: null,
      unitName: unitID,
      unitIconPath: null,
      unitFactionID: null,
      unitTier: null,
      weeklyGrowth: weeklyIncrement,
    );
  }
}
