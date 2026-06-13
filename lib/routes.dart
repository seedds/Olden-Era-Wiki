import 'package:flutter/cupertino.dart';

import 'data/models/search.dart';
import 'screens/abilities/ability_detail_screen.dart';
import 'screens/artifacts/artifact_detail_screen.dart';
import 'screens/buildings/building_detail_screen.dart';
import 'screens/faction_laws/faction_law_detail_screen.dart';
import 'screens/heroes/hero_detail_screen.dart';
import 'screens/map_objects/map_object_detail_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/skills/skill_detail_screen.dart';
import 'screens/spells/spell_detail_screen.dart';
import 'screens/subclasses/subclass_detail_screen.dart';
import 'screens/units/unit_detail_screen.dart';
import 'search/search_state.dart';

/// Port of the AppRoute enum + destination(for:) switch in App.swift,
/// expressed as plain CupertinoPageRoute pushes.
///
/// Tries [Navigator.of] first; falls back to the root navigator key stored
/// on [SearchState] (needed when pushing from the persistent search overlay
/// whose context is above the app's Navigator).
void _push(BuildContext context, Widget screen) {
  final nav = Navigator.maybeOf(context) ??
      SearchScope.of(context).navigatorKey?.currentState;
  nav?.push(CupertinoPageRoute<void>(builder: (context) => screen));
}

void pushSettings(BuildContext context) =>
    _push(context, const SettingsScreen());

void pushUnitDetail(BuildContext context, String unitID) =>
    _push(context, UnitDetailScreen(unitID: unitID));

void pushAbilityDetail(BuildContext context, String abilityID) =>
    _push(context, AbilityDetailScreen(abilityID: abilityID));

void pushHeroDetail(BuildContext context, String heroID) =>
    _push(context, HeroDetailScreen(heroID: heroID));

void pushSkillDetail(BuildContext context, String skillID) =>
    _push(context, SkillDetailScreen(skillID: skillID));

void pushSpellDetail(BuildContext context, String spellID) =>
    _push(context, SpellDetailScreen(spellID: spellID));

void pushArtifactDetail(BuildContext context, String artifactID) =>
    _push(context, ArtifactDetailScreen(artifactID: artifactID));

void pushBuildingDetail(BuildContext context, String entityID) =>
    _push(context, BuildingDetailScreen(entityID: entityID));

void pushFactionLawDetail(BuildContext context, String lawID) =>
    _push(context, FactionLawDetailScreen(lawID: lawID));

void pushSubclassDetail(BuildContext context, String subclassID) =>
    _push(context, SubclassDetailScreen(subclassID: subclassID));

void pushMapObjectDetail(BuildContext context, String objectID) =>
    _push(context, MapObjectDetailScreen(objectID: objectID));

/// Port of searchDestination(for:) in HomeView.swift.
void pushSearchResult(BuildContext context, GlobalSearchResult result) {
  switch (result.entityType) {
    case SearchEntityType.units:
      pushUnitDetail(context, result.entityID);
    case SearchEntityType.abilities:
      pushAbilityDetail(context, result.entityID);
    case SearchEntityType.heroes:
      pushHeroDetail(context, result.entityID);
    case SearchEntityType.skills:
      pushSkillDetail(context, result.entityID);
    case SearchEntityType.mapObjects:
      pushMapObjectDetail(context, result.entityID);
    case SearchEntityType.subclasses:
      pushSubclassDetail(context, result.entityID);
    case SearchEntityType.spells:
      pushSpellDetail(context, result.entityID);
    case SearchEntityType.artifacts:
      pushArtifactDetail(context, result.entityID);
    case SearchEntityType.buildings:
      pushBuildingDetail(context, result.entityID);
    case SearchEntityType.factionLaws:
      pushFactionLawDetail(context, result.entityID);
  }
}
