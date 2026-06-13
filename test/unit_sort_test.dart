import 'package:flutter_test/flutter_test.dart';
import 'package:olden_era_wiki/data/models/unit.dart';
import 'package:olden_era_wiki/screens/units/units_list_screen.dart';

UnitListItem unit(String id, {String name = '', int? tier, String? faction}) =>
    UnitListItem(id: id, name: name, tier: tier, factionID: faction);

void main() {
  test('baseUnitID strips upgrade suffixes', () {
    expect(baseUnitID('angel'), 'angel');
    expect(baseUnitID('angel_upg'), 'angel');
    expect(baseUnitID('angel_upg_alt'), 'angel');
  });

  test('unitVariantRank orders base, upg, upg_alt', () {
    expect(unitVariantRank('angel'), 0);
    expect(unitVariantRank('angel_upg'), 1);
    expect(unitVariantRank('angel_upg_alt'), 2);
  });

  test('compareUnits sorts by tier, faction, base id, variant rank', () {
    final units = [
      unit('zombie_upg', name: 'Rotting Zombie', tier: 2, faction: 'undead'),
      unit('angel_upg_alt', name: 'Seraph', tier: 1, faction: 'human'),
      unit('angel', name: 'Angel', tier: 1, faction: 'human'),
      unit('imp', name: 'Imp', tier: 1, faction: 'demon'),
      unit('zombie', name: 'Zombie', tier: 2, faction: 'undead'),
      unit('angel_upg', name: 'Archangel', tier: 1, faction: 'human'),
    ]..sort(compareUnits);

    expect(units.map((u) => u.id).toList(), [
      'imp', // tier 1, demon < human
      'angel',
      'angel_upg',
      'angel_upg_alt',
      'zombie', // tier 2
      'zombie_upg',
    ]);
  });

  test('units without tier sort last', () {
    final units = [
      unit('b', name: 'B'),
      unit('a', name: 'A', tier: 7),
    ]..sort(compareUnits);
    expect(units.first.id, 'a');
  });
}
