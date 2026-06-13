import '../database.dart';
import '../models/map_object.dart';

/// Port of canonicalMapObjectsCTE (Database.swift). Interpolated in front of
/// both map-object queries exactly as the Swift code does.
const String _canonicalMapObjectsCTE = '''
WITH canonical_map_objects AS (
    SELECT COALESCE(MIN(CASE WHEN id NOT LIKE 'custom!_%' ESCAPE '!' THEN id END), MIN(id)) AS id
    FROM map_objects
    WHERE icon_path IS NOT NULL
      AND id NOT IN (SELECT id FROM artifacts)
      AND (
        description IS NOT NULL
        OR id IN (SELECT map_object_id FROM map_object_bank_metadata)
      )
    GROUP BY name, description
)
''';

/// Port of the map-object queries in Database.swift.
extension MapObjectsQueries on WikiDatabase {
  List<MapObjectListItem> listMapObjects() {
    final rows = db.select('''
        $_canonicalMapObjectsCTE
        SELECT id, name, category, icon_path, description
        FROM map_objects
        WHERE id IN (SELECT id FROM canonical_map_objects)
        ORDER BY name, id
        ''');
    return [for (final row in rows) MapObjectListItem.fromRow(row)];
  }

  MapObjectDetail? fetchMapObjectDetail(String id) {
    final rows = db.select('''
        $_canonicalMapObjectsCTE
        SELECT
            id,
            source_file,
            category,
            prefab_path,
            icon_path,
            raw_json,
            name,
            description,
            narrative_description
        FROM map_objects
        WHERE id = ?
          AND id IN (SELECT id FROM canonical_map_objects)
        ''', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;

    final rewardRows = db.select('''
        SELECT
            v.variant_index,
            v.roll_chance,
            r.reward_index,
            r.resource_key,
            r.amount
        FROM map_object_reward_variants v
        JOIN map_object_resource_rewards r
          ON r.map_object_id = v.map_object_id
         AND r.variant_index = v.variant_index
        WHERE v.map_object_id = ?
        ORDER BY v.variant_index, r.reward_index
        ''', [id]);

    final groupedRewardRows = <int, List<Map<String, Object?>>>{};
    for (final rewardRow in rewardRows) {
      groupedRewardRows
          .putIfAbsent(rewardRow['variant_index'] as int, () => [])
          .add({
        'roll_chance': rewardRow['roll_chance'],
        'reward_index': rewardRow['reward_index'],
        'resource_key': rewardRow['resource_key'],
        'amount': rewardRow['amount'],
      });
    }
    final rewardVariants = [
      for (final variantIndex in groupedRewardRows.keys.toList()..sort())
        MapObjectRewardVariant(
          variantIndex: variantIndex,
          rollChance: groupedRewardRows[variantIndex]!.first['roll_chance']
              as int?,
          resources: [
            for (final rewardRow in groupedRewardRows[variantIndex]!)
              MapObjectResourceReward(
                rewardIndex: rewardRow['reward_index'] as int,
                resourceKey: rewardRow['resource_key'] as String,
                amount: rewardRow['amount'] as int,
              ),
          ],
        ),
    ];

    final bankMetadataRows = db.select('''
        SELECT visit_type, apply_difficulty_modifier
        FROM map_object_bank_metadata
        WHERE map_object_id = ?
        ''', [id]);

    final guardRows = db.select('''
        SELECT
            gv.variant_index,
            gv.roll_chance,
            gu.guard_index,
            gu.unit_id,
            COALESCE(u.name, gu.unit_id) AS unit_name,
            u.icon_path AS unit_icon_path,
            gu.amount
        FROM map_object_guard_variants gv
        JOIN map_object_guard_units gu
          ON gu.map_object_id = gv.map_object_id
         AND gu.variant_index = gv.variant_index
        LEFT JOIN units u ON u.id = gu.unit_id
        WHERE gv.map_object_id = ?
        ORDER BY gv.variant_index, gu.guard_index
        ''', [id]);

    final groupedGuardRows = <int, List<Map<String, Object?>>>{};
    for (final guardRow in guardRows) {
      groupedGuardRows
          .putIfAbsent(guardRow['variant_index'] as int, () => [])
          .add({
        'roll_chance': guardRow['roll_chance'],
        'guard_index': guardRow['guard_index'],
        'unit_id': guardRow['unit_id'],
        'unit_name': guardRow['unit_name'],
        'unit_icon_path': guardRow['unit_icon_path'],
        'amount': guardRow['amount'],
      });
    }
    final guardVariants = [
      for (final variantIndex in groupedGuardRows.keys.toList()..sort())
        MapObjectGuardVariant(
          variantIndex: variantIndex,
          rollChance: groupedGuardRows[variantIndex]!.first['roll_chance']
              as int?,
          guards: [
            for (final guardRow in groupedGuardRows[variantIndex]!)
              MapObjectGuardUnit(
                guardIndex: guardRow['guard_index'] as int,
                unitID: guardRow['unit_id'] as String,
                unitName: guardRow['unit_name'] as String,
                unitIconPath: guardRow['unit_icon_path'] as String?,
                amount: guardRow['amount'] as int,
              ),
          ],
        ),
    ];

    final MapObjectBankInfo? bankInfo;
    if (bankMetadataRows.isNotEmpty) {
      final bankMetadataRow = bankMetadataRows.first;
      bankInfo = MapObjectBankInfo(
        visitType: bankMetadataRow['visit_type'] as String?,
        applyDifficultyModifier:
            (bankMetadataRow['apply_difficulty_modifier'] as int? ?? 0) != 0,
        guardVariants: guardVariants,
      );
    } else if (guardVariants.isNotEmpty) {
      bankInfo = MapObjectBankInfo(
        visitType: null,
        applyDifficultyModifier: false,
        guardVariants: guardVariants,
      );
    } else {
      bankInfo = null;
    }

    return MapObjectDetail(
      id: row['id'] as String,
      sourceFile: row['source_file'] as String,
      category: row['category'] as String?,
      prefabPath: row['prefab_path'] as String?,
      iconPath: row['icon_path'] as String?,
      rawJSON: row['raw_json'] as String?,
      name: row['name'] as String,
      description: row['description'] as String?,
      narrativeDescription: row['narrative_description'] as String?,
      rewardVariants: rewardVariants,
      bankInfo: bankInfo,
    );
  }
}
