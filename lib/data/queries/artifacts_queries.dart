import 'dart:convert';

import '../database.dart';
import '../models/artifact.dart';

/// Port of the artifact-related queries in Database.swift.
extension ArtifactsQueries on WikiDatabase {
  List<ArtifactListItem> listArtifacts() {
    final rows = db.select('''
        SELECT
          id,
          name,
          icon_path,
          slot,
          rarity,
          item_set_id,
          max_level,
          goods_value,
          bonus_count,
          bonus_type
        FROM artifacts
        WHERE level = 1
        ORDER BY name
        ''');
    return [for (final row in rows) ArtifactListItem.fromRow(row)];
  }

  ArtifactDetail? fetchArtifactDetail(String id) {
    final rows = db.select('''
        SELECT
          id, level, name, narrative_description, icon_path, slot, rarity, item_set_id,
          max_level, goods_value, cost_base, cost_per_level, reward_for_destroy,
          bonus_count, bonus_type, level_description, upgrade_description
        FROM artifacts
        WHERE id = ?
        ORDER BY level
        ''', [id]);
    if (rows.isEmpty) return null;
    final firstRow = rows.first;

    final itemSet = fetchArtifactSetDetail(firstRow['item_set_id'] as String?);

    return ArtifactDetail(
      id: firstRow['id'] as String,
      name: firstRow['name'] as String,
      narrativeDescription: firstRow['narrative_description'] as String?,
      iconPath: firstRow['icon_path'] as String?,
      slot: firstRow['slot'] as String?,
      rarity: firstRow['rarity'] as String?,
      itemSetID: firstRow['item_set_id'] as String?,
      maxLevel: firstRow['max_level'] as int? ?? 1,
      goodsValue: firstRow['goods_value'] as int?,
      costBase: firstRow['cost_base'] as int?,
      costPerLevel: firstRow['cost_per_level'] as int?,
      rewardForDestroy: firstRow['reward_for_destroy'] as int?,
      bonusCount: firstRow['bonus_count'] as int?,
      bonusType: firstRow['bonus_type'] as String?,
      itemSet: itemSet,
      levels: [
        for (final row in rows)
          ArtifactLevelDetail(
            level: row['level'] as int,
            description: row['level_description'] as String?,
            upgradeDescription: row['upgrade_description'] as String?,
          ),
      ],
    );
  }

  ArtifactSetDetail? fetchArtifactSetDetail(String? id) {
    if (id == null || id.isEmpty) return null;

    final rows = db.select('''
        SELECT id, name, description, item_count, bonus_count, bonuses_json
        FROM item_sets
        WHERE id = ?
        ''', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;

    final bonuses = _parseSetBonuses(row['bonuses_json'] as String?);

    final memberRows = db.select('''
        SELECT id, name, icon_path, rarity
        FROM artifacts
        WHERE item_set_id = ?
          AND level = 1
        ORDER BY name
        ''', [id]);
    final members = [
      for (final memberRow in memberRows) ArtifactSetMember.fromRow(memberRow),
    ];

    return ArtifactSetDetail(
      id: row['id'] as String,
      name: row['name'] as String,
      description: row['description'] as String?,
      itemCount: row['item_count'] as int? ?? members.length,
      bonusCount: row['bonus_count'] as int? ?? bonuses.length,
      bonuses: bonuses,
      members: members,
    );
  }
}

/// `bonuses_json` decodes to a list of {required_items_amount, description}.
List<ArtifactSetBonus> _parseSetBonuses(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        ArtifactSetBonus.fromJson(item as Map<String, dynamic>),
    ];
  } catch (_) {
    return const [];
  }
}
