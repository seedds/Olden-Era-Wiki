import '../database.dart';
import '../models/building.dart';
import '../models/search.dart';

/// Port of globalSearch + search metadata loading (Database.swift:2683-2959).
extension SearchQueries on WikiDatabase {
  List<GlobalSearchResult> globalSearch({required String query, int limit = 60}) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return const [];

    final ftsQuery = trimmedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map((token) {
      final escaped = token.replaceAll('"', '""');
      return 'title:"$escaped"*';
    }).join(' ');

    final rawLimit = limit * 10 < limit ? limit : limit * 10;
    final matchRows = db.select('''
        SELECT
            entity_type,
            entity_id,
            title,
            NULL AS subtitle
        FROM search_text
        WHERE entity_type IN ('units', 'abilities', 'heroes', 'skills', 'map_objects', 'artifacts', 'spells', 'buildings', 'faction_laws', 'subclasses')
          AND NOT (
            entity_type = 'skills'
            AND (entity_id LIKE 'arena_%' OR entity_id LIKE 'campaign_%')
          )
          AND NOT (
            entity_type = 'abilities'
            AND entity_id IN (SELECT id FROM unit_abilities WHERE icon_path IS NULL)
          )
          AND NOT (
            entity_type = 'skills'
            AND entity_id NOT IN (SELECT id FROM skills WHERE level_description IS NOT NULL)
          )
          AND NOT (
            entity_type = 'map_objects'
            AND entity_id NOT IN (
                SELECT COALESCE(MIN(CASE WHEN id NOT LIKE 'custom!_%' ESCAPE '!' THEN id END), MIN(id))
                FROM map_objects
                WHERE description IS NOT NULL
                  AND icon_path IS NOT NULL
                  AND id NOT IN (SELECT id FROM artifacts)
                GROUP BY name, description
            )
          )
        AND search_text MATCH ?
        ORDER BY bm25(search_text), title
        LIMIT ?
        ''', [ftsQuery, rawLimit]);

    final matches = <_GlobalSearchMatch>[
      for (final row in matchRows)
        if (SearchEntityType.fromRaw(row['entity_type'] as String?) != null)
          _GlobalSearchMatch(
            entityType:
                SearchEntityType.fromRaw(row['entity_type'] as String)!,
            entityID: row['entity_id'] as String,
            title: row['title'] as String,
            subtitle: row['subtitle'] as String?,
          ),
    ];

    final filteredMatches = <_GlobalSearchMatch>[];
    final seenAbilityTitles = <String>{};
    final abilityVariantCounts = <String, int>{};

    for (final match in matches) {
      if (match.entityType == SearchEntityType.abilities) {
        abilityVariantCounts[match.title] =
            (abilityVariantCounts[match.title] ?? 0) + 1;
      }
    }

    for (final match in matches) {
      if (match.entityType == SearchEntityType.abilities) {
        if (seenAbilityTitles.add(match.title)) {
          filteredMatches.add(match);
        }
      } else {
        filteredMatches.add(match);
      }

      if (filteredMatches.length == limit) break;
    }

    final metadata = _loadSearchMetadata(filteredMatches);

    return [
      for (final match in filteredMatches)
        () {
          final metadataItem =
              metadata[_metadataKey(match.entityType, match.entityID)];
          return GlobalSearchResult(
            entityType: match.entityType,
            entityID: match.entityID,
            title: match.title,
            subtitle: match.entityType == SearchEntityType.abilities
                ? _variantCountText(abilityVariantCounts[match.title] ?? 1)
                : match.subtitle,
            iconPath: metadataItem?.iconPath,
            factionID: metadataItem?.factionID,
          );
        }(),
    ];
  }

  Map<String, _SearchMetadataItem> _loadSearchMetadata(
      List<_GlobalSearchMatch> matches) {
    final idsByType = <SearchEntityType, Set<String>>{};
    for (final match in matches) {
      idsByType.putIfAbsent(match.entityType, () => {}).add(match.entityID);
    }

    final metadata = <String, _SearchMetadataItem>{};

    void append(List<_SearchMetadataItem> items, SearchEntityType type) {
      for (final item in items) {
        metadata[_metadataKey(type, item.id)] = item;
      }
    }

    List<String> ids(SearchEntityType type) =>
        idsByType[type]?.toList() ?? const [];

    append(
        _loadSearchMetadataItems(
            table: 'units',
            iconColumn: 'icon_path',
            factionColumn: 'faction_id',
            ids: ids(SearchEntityType.units)),
        SearchEntityType.units);
    append(
        _loadSearchMetadataItems(
            table: 'unit_abilities',
            iconColumn: 'icon_path',
            factionColumn: null,
            ids: ids(SearchEntityType.abilities)),
        SearchEntityType.abilities);
    append(
        _loadSearchMetadataItems(
            table: 'heroes',
            iconColumn: 'portrait_path',
            factionColumn: 'faction_id',
            ids: ids(SearchEntityType.heroes)),
        SearchEntityType.heroes);
    append(
        _loadSearchMetadataItems(
            table: 'skills',
            iconColumn: 'icon_path',
            factionColumn: null,
            ids: ids(SearchEntityType.skills)),
        SearchEntityType.skills);
    append(
        _loadSearchMetadataItems(
            table: 'map_objects',
            iconColumn: 'icon_path',
            factionColumn: null,
            ids: ids(SearchEntityType.mapObjects)),
        SearchEntityType.mapObjects);
    append(
        _loadSearchMetadataItems(
            table: 'artifacts',
            iconColumn: 'icon_path',
            factionColumn: null,
            ids: ids(SearchEntityType.artifacts)),
        SearchEntityType.artifacts);
    append(
        _loadSearchMetadataItems(
            table: 'spells',
            iconColumn: 'icon_path',
            factionColumn: null,
            ids: ids(SearchEntityType.spells)),
        SearchEntityType.spells);
    append(_loadBuildingSearchMetadataItems(ids(SearchEntityType.buildings)),
        SearchEntityType.buildings);
    append(
        _loadSearchMetadataItems(
            table: 'faction_laws',
            iconColumn: 'icon_path',
            factionColumn: 'faction_id',
            ids: ids(SearchEntityType.factionLaws)),
        SearchEntityType.factionLaws);
    append(
        _loadSearchMetadataItems(
            table: 'subclasses',
            iconColumn: 'icon_path',
            factionColumn: 'faction_id',
            ids: ids(SearchEntityType.subclasses)),
        SearchEntityType.subclasses);

    return metadata;
  }

  List<_SearchMetadataItem> _loadSearchMetadataItems({
    required String table,
    required String iconColumn,
    required String? factionColumn,
    required List<String> ids,
  }) {
    if (ids.isEmpty) return const [];

    final placeholders = List.filled(ids.length, '?').join(', ');
    final factionSelection = factionColumn ?? 'NULL';

    final rows = db.select('''
        SELECT id, $iconColumn AS icon_path, $factionSelection AS faction_id
        FROM $table
        WHERE id IN ($placeholders)
        ''', ids);

    return [
      for (final row in rows)
        _SearchMetadataItem(
          id: row['id'] as String,
          iconPath: row['icon_path'] as String?,
          factionID: row['faction_id'] as String?,
        ),
    ];
  }

  List<_SearchMetadataItem> _loadBuildingSearchMetadataItems(
      List<String> ids) {
    final keys = [
      for (final id in ids)
        if (parseBuildingEntityID(id) case final key?) key,
    ];
    if (keys.isEmpty) return const [];

    final conditions =
        List.filled(keys.length, '(id = ? AND level = ?)').join(' OR ');
    final arguments = <Object?>[
      for (final key in keys) ...[key.buildingID, key.level],
    ];

    final rows = db.select('''
        SELECT id || ':' || level AS id, icon_path, faction_id
        FROM buildings
        WHERE $conditions
        ''', arguments);

    return [
      for (final row in rows)
        _SearchMetadataItem(
          id: row['id'] as String,
          iconPath: row['icon_path'] as String?,
          factionID: row['faction_id'] as String?,
        ),
    ];
  }

  String _metadataKey(SearchEntityType type, String id) =>
      '${type.rawValue}:$id';

  String _variantCountText(int count) =>
      count == 1 ? '1 variant' : '$count variants';
}

class _GlobalSearchMatch {
  const _GlobalSearchMatch({
    required this.entityType,
    required this.entityID,
    required this.title,
    this.subtitle,
  });

  final SearchEntityType entityType;
  final String entityID;
  final String title;
  final String? subtitle;
}

class _SearchMetadataItem {
  const _SearchMetadataItem({
    required this.id,
    this.iconPath,
    this.factionID,
  });

  final String id;
  final String? iconPath;
  final String? factionID;
}
