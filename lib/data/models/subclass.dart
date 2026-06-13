import 'package:sqlite3/sqlite3.dart';

/// Port of SubclassListItem (Database.swift).
class SubclassListItem {
  const SubclassListItem({
    required this.id,
    required this.name,
    this.factionID,
    this.classType,
    this.iconPath,
    this.description,
  });

  final String id;
  final String name;
  final String? factionID;
  final String? classType;
  final String? iconPath;
  final String? description;

  factory SubclassListItem.fromRow(Row row) => SubclassListItem(
        id: row['id'] as String,
        name: row['name'] as String,
        factionID: row['faction_id'] as String?,
        classType: row['class_type'] as String?,
        iconPath: row['icon_path'] as String?,
        description: row['description'] as String?,
      );
}

/// Port of SubclassDetail (Database.swift).
class SubclassDetail {
  const SubclassDetail({
    required this.id,
    required this.name,
    this.factionID,
    this.classType,
    this.iconPath,
    this.description,
    this.bonusType,
    this.bonusCount,
    required this.requiredSkills,
  });

  final String id;
  final String name;
  final String? factionID;
  final String? classType;
  final String? iconPath;
  final String? description;
  final String? bonusType;
  final int? bonusCount;
  final List<SubclassRequiredSkill> requiredSkills;
}

/// Port of SubclassRequiredSkill (Database.swift).
class SubclassRequiredSkill {
  const SubclassRequiredSkill({
    required this.skillID,
    required this.skillName,
    required this.skillLevel,
    this.iconPath,
  });

  final String skillID;
  final String skillName;
  final int skillLevel;
  final String? iconPath;
}

/// Port of the private SubclassRequirementJSON shape (Database.swift): one
/// entry of subclasses.activation_conditions_json.
class SubclassRequirementJSON {
  const SubclassRequirementJSON({
    required this.skillSid,
    required this.skillLevel,
    required this.subSkillSids,
  });

  final String skillSid;
  final int skillLevel;
  final List<String> subSkillSids;

  factory SubclassRequirementJSON.fromJson(Map<String, dynamic> json) =>
      SubclassRequirementJSON(
        skillSid: json['skillSid'] as String,
        skillLevel: (json['skillLevel'] as num).toInt(),
        subSkillSids: [
          for (final sid in json['subSkillSids'] as List) sid as String,
        ],
      );
}
