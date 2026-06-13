import 'package:sqlite3/sqlite3.dart';

/// Port of BuildingCostItem (Database.swift).
class BuildingCostItem {
  const BuildingCostItem({required this.name, required this.cost});

  final String name;
  final int cost;

  factory BuildingCostItem.fromJson(Map<String, dynamic> json) =>
      BuildingCostItem(
        name: json['name'] as String,
        cost: (json['cost'] as num).toInt(),
      );
}

/// Port of BuildingListItem (Database.swift).
class BuildingListItem {
  const BuildingListItem({
    required this.entityID,
    required this.buildingID,
    required this.level,
    required this.name,
    this.iconPath,
    this.factionID,
    this.groupName,
    this.weeklyGrowth,
  });

  final String entityID;
  final String buildingID;
  final int level;
  final String name;
  final String? iconPath;
  final String? factionID;
  final String? groupName;
  final int? weeklyGrowth;

  factory BuildingListItem.fromRow(Row row) => BuildingListItem(
        entityID: row['entity_id'] as String,
        buildingID: row['id'] as String,
        level: row['level'] as int,
        name: row['name'] as String,
        iconPath: row['icon_path'] as String?,
        factionID: row['faction_id'] as String?,
        groupName: row['group_name'] as String?,
        weeklyGrowth: row['weekly_growth'] as int?,
      );
}

/// Port of BuildingRecruitCreature (Database.swift).
class BuildingRecruitCreature {
  const BuildingRecruitCreature({
    this.unitID,
    required this.unitName,
    this.unitIconPath,
    this.unitFactionID,
    this.unitTier,
    this.weeklyGrowth,
  });

  final String? unitID;
  final String unitName;
  final String? unitIconPath;
  final String? unitFactionID;
  final int? unitTier;
  final int? weeklyGrowth;
}

/// Port of BuildingLinkItem (Database.swift).
class BuildingLinkItem {
  const BuildingLinkItem({
    this.entityID,
    this.buildingID,
    this.level,
    required this.name,
    this.iconPath,
    this.factionID,
    this.groupName,
  });

  final String? entityID;
  final String? buildingID;
  final int? level;
  final String name;
  final String? iconPath;
  final String? factionID;
  final String? groupName;
}

/// Port of BuildingDetail (Database.swift).
class BuildingDetail {
  const BuildingDetail({
    required this.entityID,
    required this.id,
    required this.level,
    required this.name,
    this.description,
    this.iconPath,
    this.factionID,
    this.groupName,
    this.sceneSlot,
    required this.isConstructedOnStart,
    this.levelOnStart,
    this.weeklyGrowth,
    required this.costs,
    required this.recruitCreatures,
    required this.requiredBuildings,
    required this.unlockedBuildings,
  });

  final String entityID;
  final String id;
  final int level;
  final String name;
  final String? description;
  final String? iconPath;
  final String? factionID;
  final String? groupName;
  final String? sceneSlot;
  final bool isConstructedOnStart;
  final int? levelOnStart;
  final int? weeklyGrowth;
  final List<BuildingCostItem> costs;
  final List<BuildingRecruitCreature> recruitCreatures;
  final List<BuildingLinkItem> requiredBuildings;
  final List<BuildingLinkItem> unlockedBuildings;
}

/// Port of the private BuildingHireJSON shape (Database.swift): the decoded
/// form of buildings.units_hire_json.
class BuildingHireJSON {
  const BuildingHireJSON({required this.units});

  final List<BuildingHireUnit> units;

  factory BuildingHireJSON.fromJson(Map<String, dynamic> json) =>
      BuildingHireJSON(
        units: [
          for (final unit in json['units'] as List)
            BuildingHireUnit.fromJson(unit as Map<String, dynamic>),
        ],
      );
}

/// Port of the private BuildingHireUnit shape (Database.swift).
class BuildingHireUnit {
  const BuildingHireUnit({required this.sids, this.weeklyIncrement});

  final List<String> sids;
  final int? weeklyIncrement;

  factory BuildingHireUnit.fromJson(Map<String, dynamic> json) =>
      BuildingHireUnit(
        sids: [for (final sid in json['sids'] as List) sid as String],
        weeklyIncrement: (json['weeklyIncrement'] as num?)?.toInt(),
      );
}

/// Port of the private BuildingRequirementJSON shape (Database.swift): one
/// entry of buildings.prev_buildings_json.
class BuildingRequirementJSON {
  const BuildingRequirementJSON({required this.sid, this.level});

  final String sid;
  final int? level;

  factory BuildingRequirementJSON.fromJson(Map<String, dynamic> json) =>
      BuildingRequirementJSON(
        sid: json['sid'] as String,
        level: (json['level'] as num?)?.toInt(),
      );
}

/// Port of buildingEntityID(id:level:) (Database.swift).
String buildingEntityID(String id, int level) => '$id:$level';

/// Port of parseBuildingEntityID (Database.swift). Building IDs themselves
/// contain ':' (faction prefix, e.g. 'human:barracks'), so the LAST ':'
/// separates the level.
({String buildingID, int level})? parseBuildingEntityID(String entityID) {
  final separatorIndex = entityID.lastIndexOf(':');
  if (separatorIndex == -1) return null;

  final level = int.tryParse(entityID.substring(separatorIndex + 1));
  if (level == null) return null;

  return (buildingID: entityID.substring(0, separatorIndex), level: level);
}

/// Port of buildingFactionPrefix (Database.swift). Splits a building ID such
/// as 'human:barracks' on the FIRST ':' into (factionID, sid).
({String? factionID, String sid}) buildingFactionPrefix(String buildingID) {
  final separatorIndex = buildingID.indexOf(':');
  if (separatorIndex == -1) {
    return (factionID: null, sid: buildingID);
  }

  return (
    factionID: buildingID.substring(0, separatorIndex),
    sid: buildingID.substring(separatorIndex + 1),
  );
}
