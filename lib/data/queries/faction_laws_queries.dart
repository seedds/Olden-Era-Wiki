import '../database.dart';
import '../models/faction_law.dart';

/// Port of the faction-law queries in Database.swift.
extension FactionLawsQueries on WikiDatabase {
  List<FactionLawListItem> listFactionLaws() {
    final rows = db.select('''
        SELECT id, name, faction_id, max_level, icon_path
        FROM faction_laws
        WHERE level = 1
          AND name IS NOT NULL
        ORDER BY faction_id, name
        ''');
    return [for (final row in rows) FactionLawListItem.fromRow(row)];
  }

  FactionLawDetail? fetchFactionLawDetail(String id) {
    final lawRows = db.select('''
        SELECT id, name, faction_id, max_level, icon_path
        FROM faction_laws
        WHERE id = ?
        ORDER BY level
        LIMIT 1
        ''', [id]);
    if (lawRows.isEmpty) return null;
    final law = FactionLawListItem.fromRow(lawRows.first);

    final levelRows = db.select('''
        SELECT level, cost, bonus_count, level_description
        FROM faction_laws
        WHERE id = ?
        ORDER BY level
        ''', [id]);

    return FactionLawDetail(
      id: law.id,
      name: law.name,
      factionID: law.factionID,
      maxLevel: law.maxLevel,
      iconPath: law.iconPath,
      levels: [for (final row in levelRows) FactionLawLevelDetail.fromRow(row)],
    );
  }
}
