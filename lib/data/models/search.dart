import 'package:flutter/cupertino.dart';

/// Port of SearchEntityType from Database.swift. Declaration order matters:
/// it is the section order used when grouping global search results.
enum SearchEntityType {
  units('units', 'Units'),
  abilities('abilities', 'Abilities'),
  heroes('heroes', 'Heroes'),
  skills('skills', 'Skills'),
  mapObjects('map_objects', 'Objects'),
  artifacts('artifacts', 'Artifacts'),
  spells('spells', 'Spells'),
  buildings('buildings', 'Buildings'),
  factionLaws('faction_laws', 'Faction Laws'),
  subclasses('subclasses', 'Subclasses');

  const SearchEntityType(this.rawValue, this.title);

  final String rawValue;
  final String title;

  static SearchEntityType? fromRaw(String? raw) {
    for (final value in values) {
      if (value.rawValue == raw) return value;
    }
    return null;
  }

  /// Nearest CupertinoIcons equivalents of the SF Symbols in the Swift app.
  IconData get icon => switch (this) {
        SearchEntityType.units => CupertinoIcons.shield_lefthalf_fill,
        SearchEntityType.abilities => CupertinoIcons.bolt_fill,
        SearchEntityType.heroes => CupertinoIcons.person_2_fill,
        SearchEntityType.skills => CupertinoIcons.sparkles,
        SearchEntityType.mapObjects => CupertinoIcons.cube_box_fill,
        SearchEntityType.artifacts => CupertinoIcons.rosette,
        SearchEntityType.spells => CupertinoIcons.wand_stars,
        SearchEntityType.buildings => CupertinoIcons.building_2_fill,
        SearchEntityType.factionLaws => CupertinoIcons.doc_text_fill,
        SearchEntityType.subclasses => CupertinoIcons.star_circle_fill,
      };
}

/// Port of GlobalSearchResult from Database.swift.
class GlobalSearchResult {
  const GlobalSearchResult({
    required this.entityType,
    required this.entityID,
    required this.title,
    this.subtitle,
    this.iconPath,
    this.factionID,
  });

  final SearchEntityType entityType;
  final String entityID;
  final String title;
  final String? subtitle;
  final String? iconPath;
  final String? factionID;

  String get id => '${entityType.rawValue}:$entityID';

  GlobalSearchResult copyWith({String? iconPath, String? factionID}) {
    return GlobalSearchResult(
      entityType: entityType,
      entityID: entityID,
      title: title,
      subtitle: subtitle,
      iconPath: iconPath ?? this.iconPath,
      factionID: factionID ?? this.factionID,
    );
  }
}
