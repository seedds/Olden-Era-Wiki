import 'package:flutter_test/flutter_test.dart';
import 'package:olden_era_wiki/data/models/building.dart';

void main() {
  test('buildingEntityID joins id and level', () {
    expect(buildingEntityID('human:barracks', 2), 'human:barracks:2');
    expect(buildingEntityID('tavern', 1), 'tavern:1');
  });

  test('parseBuildingEntityID splits on the LAST colon', () {
    final parsed = parseBuildingEntityID('human:barracks:2');
    expect(parsed, isNotNull);
    expect(parsed!.buildingID, 'human:barracks');
    expect(parsed.level, 2);
  });

  test('round-trips through buildingEntityID', () {
    const id = 'undead:bone_pit';
    final parsed = parseBuildingEntityID(buildingEntityID(id, 3));
    expect(parsed!.buildingID, id);
    expect(parsed.level, 3);
  });

  test('rejects strings without a numeric level', () {
    expect(parseBuildingEntityID('human:barracks'), isNull);
    expect(parseBuildingEntityID('nocolon'), isNull);
  });

  test('buildingFactionPrefix splits on the FIRST colon', () {
    final withFaction = buildingFactionPrefix('human:barracks');
    expect(withFaction.factionID, 'human');
    expect(withFaction.sid, 'barracks');

    final nested = buildingFactionPrefix('human:bar:racks');
    expect(nested.factionID, 'human');
    expect(nested.sid, 'bar:racks');

    final noFaction = buildingFactionPrefix('tavern');
    expect(noFaction.factionID, isNull);
    expect(noFaction.sid, 'tavern');
  });
}
