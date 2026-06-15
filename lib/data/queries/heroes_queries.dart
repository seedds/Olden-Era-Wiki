import 'dart:convert';
import 'dart:math' as math;

import '../database.dart';
import '../models/hero.dart';

/// Decoded entry of `startSkills` in a hero's raw_json (HeroRawSkill).
typedef _HeroRawSkill = ({String sid, int? skillLevel});

/// Decoded entry of `startMagics` in a hero's raw_json (HeroRawSpell).
typedef _HeroRawSpell = ({String sidConfig, int? level, bool? isLearned});

Map<String, dynamic>? _decodeRawJSON(String? rawJSON) {
  if (rawJSON == null) return null;
  try {
    final decoded = jsonDecode(rawJSON);
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    return null;
  }
}

List<_HeroRawSkill> _parseStartSkills(String? rawJSON) {
  final startSkills = _decodeRawJSON(rawJSON)?['startSkills'];
  if (startSkills is! List) return const [];
  return [
    for (final item in startSkills)
      if (item is Map<String, dynamic> && item['sid'] is String)
        (
          sid: item['sid'] as String,
          skillLevel: (item['skillLevel'] as num?)?.toInt(),
        ),
  ];
}

List<_HeroRawSpell> _parseStartMagics(String? rawJSON) {
  final startMagics = _decodeRawJSON(rawJSON)?['startMagics'];
  if (startMagics is! List) return const [];
  return [
    for (final item in startMagics)
      if (item is Map<String, dynamic> && item['sidConfig'] is String)
        (
          sidConfig: item['sidConfig'] as String,
          level: (item['level'] as num?)?.toInt(),
          isLearned: item['isLearned'] as bool?,
        ),
  ];
}

/// Port of the hero-related queries in Database.swift.
extension HeroesQueries on WikiDatabase {
  List<HeroListItem> listHeroes() {
    final rows = db.select('''
        SELECT id, name, portrait_path, faction_id, class_type, start_level
        FROM heroes
        WHERE id NOT LIKE 'campaign_%'
          AND id NOT LIKE 'tutorial_%'
        ORDER BY name COLLATE NOCASE
        ''');
    return [for (final row in rows) HeroListItem.fromRow(row)];
  }

  HeroDetail? fetchHeroDetail(String id) {
    final rows = db.select('''
        SELECT
            id,
            name,
            portrait_path,
            faction_id,
            class_type,
            specialization_id,
            specialization_name,
            native_biome,
            cost_gold,
            start_level,
            class_icon_path,
            specialization_icon_path,
            start_stats_json,
            raw_json,
            description,
            motto,
            specialization_description
        FROM heroes
        WHERE id = ?
        ''', [id]);
    if (rows.isEmpty) return null;
    final row = rows.first;

    return HeroDetail(
      id: row['id'] as String,
      name: row['name'] as String,
      portraitPath: row['portrait_path'] as String?,
      factionID: row['faction_id'] as String?,
      classType: row['class_type'] as String?,
      specializationID: row['specialization_id'] as String?,
      specializationName: row['specialization_name'] as String?,
      nativeBiome: row['native_biome'] as String?,
      costGold: row['cost_gold'] as int?,
      startLevel: row['start_level'] as int?,
      classIconPath: row['class_icon_path'] as String?,
      specializationIconPath: row['specialization_icon_path'] as String?,
      startStatsJSON: row['start_stats_json'] as String?,
      rawJSON: row['raw_json'] as String?,
      description: row['description'] as String?,
      motto: row['motto'] as String?,
      specializationDescription: row['specialization_description'] as String?,
    );
  }

  List<HeroStartingSkillItem> fetchHeroStartingSkills(HeroDetail hero) {
    final orderedSkills = [
      for (final skill in _parseStartSkills(hero.rawJSON))
        if (skill.sid.isNotEmpty) skill,
    ];
    if (orderedSkills.isEmpty) return [];

    final skillIDs = [for (final skill in orderedSkills) skill.sid];
    final placeholders = List.filled(skillIDs.length, '?').join(', ');

    final rows = db.select('''
        SELECT id, name, icon_path
        FROM skills
        WHERE level = 1 AND id IN (
            $placeholders
        )
          AND id NOT LIKE 'arena_%'
          AND id NOT LIKE 'campaign_%'
          AND EXISTS (
            SELECT 1 FROM skills s2
            WHERE s2.id = skills.id AND s2.level_description IS NOT NULL
          )
        ''', skillIDs);

    final skillsByID = {for (final row in rows) row['id'] as String: row};
    return [
      for (final skill in orderedSkills)
        if (skillsByID[skill.sid] case final row?)
          HeroStartingSkillItem(
            skillID: row['id'] as String,
            name: row['name'] as String,
            iconPath: row['icon_path'] as String?,
            level: math.max(skill.skillLevel ?? 1, 1),
          ),
    ];
  }

  List<HeroStartingSpellItem> fetchHeroStartingSpells(HeroDetail hero) {
    final learnedSpells = [
      for (final spell in _parseStartMagics(hero.rawJSON))
        if ((spell.isLearned ?? false) && spell.sidConfig.isNotEmpty) spell,
    ];
    if (learnedSpells.isEmpty) return [];

    final spellIDs = [for (final spell in learnedSpells) spell.sidConfig];
    final placeholders = List.filled(spellIDs.length, '?').join(', ');

    final rows = db.select('''
        SELECT id, name, icon_path
        FROM spells
        WHERE level = 1 AND id IN (
            $placeholders
        )
        ''', spellIDs);

    final spellsByID = {for (final row in rows) row['id'] as String: row};
    return [
      for (final spell in learnedSpells)
        if (spellsByID[spell.sidConfig] case final row?)
          HeroStartingSpellItem(
            spellID: row['id'] as String,
            name: row['name'] as String,
            iconPath: row['icon_path'] as String?,
            level: math.max(spell.level ?? 1, 1),
          ),
    ];
  }

  List<HeroStartingSquadItem> fetchHeroStartingSquads(String heroID) {
    final rows = db.select('''
        SELECT
            hss.variant,
            hss.slot_index,
            hss.unit_id,
            u.name AS unit_name,
            u.icon_path AS unit_icon_path,
            u.faction_id AS unit_faction_id,
            u.tier AS unit_tier,
            hss.min_count,
            hss.max_count
        FROM hero_start_squads hss
        LEFT JOIN units u ON u.id = hss.unit_id
        WHERE hss.hero_id = ?
        ORDER BY CASE hss.variant WHEN 'default' THEN 0 ELSE 1 END, hss.variant, hss.slot_index
        ''', [heroID]);

    return [
      for (final row in rows)
        HeroStartingSquadItem(
          variant: row['variant'] as String,
          slotIndex: row['slot_index'] as int,
          unitID: row['unit_id'] as String?,
          unitName: row['unit_name'] as String?,
          unitIconPath: row['unit_icon_path'] as String?,
          unitFactionID: row['unit_faction_id'] as String?,
          unitTier: row['unit_tier'] as int?,
          minCount: row['min_count'] as int?,
          maxCount: row['max_count'] as int?,
        ),
    ];
  }

  List<HeroListItem> fetchStartingHeroesForSkill(String skillID) {
    final rows = db.select('''
        SELECT DISTINCT h.id, h.name, h.portrait_path, h.faction_id, h.class_type, h.start_level
        FROM heroes h, json_each(h.raw_json, '\$.startSkills') s
        WHERE json_extract(s.value, '\$.sid') = ?
          AND h.id NOT LIKE 'campaign_%'
          AND h.id NOT LIKE 'tutorial_%'
        ORDER BY h.name
        ''', [skillID]);
    return [for (final row in rows) HeroListItem.fromRow(row)];
  }

  List<HeroListItem> fetchStartingHeroesForSpell(String spellID) {
    final rows = db.select('''
        SELECT DISTINCT h.id, h.name, h.portrait_path, h.faction_id, h.class_type, h.start_level
        FROM heroes h, json_each(h.raw_json, '\$.startMagics') s
        WHERE json_extract(s.value, '\$.sidConfig') = ?
          AND json_extract(s.value, '\$.isLearned') = 1
          AND h.id NOT LIKE 'campaign_%'
          AND h.id NOT LIKE 'tutorial_%'
        ORDER BY h.name
        ''', [spellID]);
    return [for (final row in rows) HeroListItem.fromRow(row)];
  }
}
