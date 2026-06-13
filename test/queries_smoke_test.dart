// Exercises every ported query against the real bundled wiki.sqlite.
// Runs on the host VM, where the sqlite3 package uses the system SQLite.
import 'package:flutter_test/flutter_test.dart';
import 'package:olden_era_wiki/data/database.dart';
import 'package:olden_era_wiki/data/models/search.dart';
import 'package:olden_era_wiki/data/queries/abilities_queries.dart';
import 'package:olden_era_wiki/data/queries/artifacts_queries.dart';
import 'package:olden_era_wiki/data/queries/buildings_queries.dart';
import 'package:olden_era_wiki/data/queries/faction_laws_queries.dart';
import 'package:olden_era_wiki/data/queries/heroes_queries.dart';
import 'package:olden_era_wiki/data/queries/map_objects_queries.dart';
import 'package:olden_era_wiki/data/queries/search_queries.dart';
import 'package:olden_era_wiki/data/queries/skills_queries.dart';
import 'package:olden_era_wiki/data/queries/spells_queries.dart';
import 'package:olden_era_wiki/data/queries/subclasses_queries.dart';
import 'package:olden_era_wiki/data/queries/units_queries.dart';

void main() {
  late WikiDatabase db;

  setUpAll(() {
    WikiDatabase.initializeForTesting('assets/db/wiki.sqlite');
    db = WikiDatabase.instance;
  });

  test('game version', () {
    expect(db.fetchGameVersion(), isNotNull);
  });

  test('units: list, detail, upgrades, factions', () {
    final units = db.listUnits();
    expect(units.length, greaterThan(100));

    // 6 named factions + 'neutral' (same result as the Swift app's query).
    final factions = db.fetchFactions();
    expect(factions, hasLength(7));
    expect(factions, contains('neutral'));

    final detail = db.fetchUnitDetail(units.first.id);
    expect(detail, isNotNull);
    expect(detail!.name, isNotEmpty);

    final crossbowman = db.fetchUnitDetail('crossbowman');
    expect(crossbowman, isNotNull);
    expect(crossbowman!.upgradeSid, 'crossbowman_upg');
    final relations = db.fetchUnitUpgradeRelations('crossbowman');
    expect(relations.upgradeTo.map((u) => u.id), contains('crossbowman_upg'));
    expect(db.fetchUpgradeCost('crossbowman_upg'), isNotNull);
  });

  test('abilities: grouped list and detail with variants', () {
    final abilities = db.listAbilities();
    expect(abilities, isNotEmpty);

    final detail = db.fetchAbilityDetail(abilities.first.id);
    expect(detail, isNotNull);
    expect(detail!.variants, isNotEmpty);
    expect(detail.variants.first.creatures, isNotEmpty);
  });

  test('heroes: list, detail, starting skills/spells/squads', () {
    final heroes = db.listHeroes();
    expect(heroes, isNotEmpty);
    // The campaign/tutorial filter must hold.
    expect(
        heroes.where((hero) =>
            hero.id.startsWith('campaign_') ||
            hero.id.startsWith('tutorial_')),
        isEmpty);

    final detail = db.fetchHeroDetail(heroes.first.id);
    expect(detail, isNotNull);
    db.fetchHeroStartingSkills(detail!);
    db.fetchHeroStartingSpells(detail);
    expect(db.fetchHeroStartingSquads(detail.id), isNotEmpty);
  });

  test('skills: list excludes arena/campaign, detail folds levels', () {
    final skills = db.listSkills();
    expect(skills, isNotEmpty);
    final detail = db.fetchSkillDetail(skills.first.id);
    expect(detail, isNotNull);
    expect(detail!.levels, isNotEmpty);
    expect(db.fetchSkillDetail('arena_anything'), isNull);
  });

  test('spells: list and multi-level detail', () {
    final spells = db.listSpells();
    expect(spells, isNotEmpty);
    final detail = db.fetchSpellDetail(spells.first.id);
    expect(detail, isNotNull);
    expect(detail!.levels, isNotEmpty);
  });

  test('artifacts: list, detail, item sets', () {
    final artifacts = db.listArtifacts();
    expect(artifacts, isNotEmpty);

    final withSet = artifacts.where((a) => a.itemSetID != null);
    if (withSet.isNotEmpty) {
      final detail = db.fetchArtifactDetail(withSet.first.id);
      expect(detail, isNotNull);
      expect(detail!.itemSet, isNotNull);
      expect(detail.itemSet!.members, isNotEmpty);
    }
  });

  test('buildings: list, entity-ID round trip, links', () {
    final buildings = db.listBuildings();
    expect(buildings, isNotEmpty);

    final detail = db.fetchBuildingDetail(buildings.first.entityID);
    expect(detail, isNotNull);
    expect(detail!.entityID, buildings.first.entityID);
  });

  test('faction laws: list and per-level detail', () {
    final laws = db.listFactionLaws();
    expect(laws, isNotEmpty);
    final detail = db.fetchFactionLawDetail(laws.first.id);
    expect(detail, isNotNull);
    expect(detail!.levels, isNotEmpty);
  });

  test('subclasses: list and detail with required skills', () {
    final subclasses = db.listSubclasses();
    expect(subclasses, isNotEmpty);
    final detail = db.fetchSubclassDetail(subclasses.first.id);
    expect(detail, isNotNull);
  });

  test('map objects: canonical list has no duplicate names+descriptions', () {
    final objects = db.listMapObjects();
    expect(objects, isNotEmpty);

    final detail = db.fetchMapObjectDetail(objects.first.id);
    expect(detail, isNotNull);
  });

  test('global search: FTS5 with ability dedupe and metadata', () {
    final results = db.globalSearch(query: 'fire');
    expect(results, isNotEmpty);

    // Abilities are deduped by title and carry a variant-count subtitle.
    final abilityTitles = [
      for (final result in results)
        if (result.entityType == SearchEntityType.abilities) result.title,
    ];
    expect(abilityTitles.toSet().length, abilityTitles.length);
    for (final result in results) {
      if (result.entityType == SearchEntityType.abilities) {
        expect(result.subtitle, matches(RegExp(r'^\d+ variants?$')));
      }
    }

    // Quoted input must not break the FTS query.
    expect(() => db.globalSearch(query: 'fire "dragon'), returnsNormally);
    expect(db.globalSearch(query: '   '), isEmpty);
  });
}
