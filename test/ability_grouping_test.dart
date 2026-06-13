import 'package:flutter_test/flutter_test.dart';
import 'package:olden_era_wiki/data/models/ability.dart';
import 'package:olden_era_wiki/data/queries/abilities_queries.dart';

AbilityDatabaseRow row({
  required String id,
  required String unitID,
  required String unitName,
  int? unitTier,
  String name = 'Cleave',
  String? description = 'Hits adjacent enemies.',
  bool isActive = true,
  String? iconPath = 'images/raw/sprite/cleave.png',
  int? rank,
  String? rawJSON,
}) =>
    AbilityDatabaseRow(
      id: id,
      unitID: unitID,
      unitName: unitName,
      unitTier: unitTier,
      name: name,
      description: description,
      isActive: isActive,
      iconPath: iconPath,
      rank: rank,
      rawJSON: rawJSON,
    );

void main() {
  test('rows with identical key fields merge, creatures sorted by name', () {
    final merged = mergeAbilityRows([
      row(id: 'a1', unitID: 'orc', unitName: 'Orc'),
      row(id: 'a2', unitID: 'angel', unitName: 'Angel'),
    ]);

    expect(merged, hasLength(1));
    expect(merged.first.row.id, 'a1');
    expect(
      merged.first.creatures.map((c) => c.unitName).toList(),
      ['Angel', 'Orc'],
    );
  });

  test('equal creature names sort by tier with null last', () {
    final merged = mergeAbilityRows([
      row(id: 'a1', unitID: 'x', unitName: 'Wolf'),
      row(id: 'a2', unitID: 'y', unitName: 'Wolf', unitTier: 2),
    ]);

    expect(merged, hasLength(1));
    expect(merged.first.creatures.map((c) => c.unitID).toList(), ['y', 'x']);
  });

  test('differing descriptions produce separate variants in order', () {
    final merged = mergeAbilityRows([
      row(id: 'a1', unitID: 'orc', unitName: 'Orc', description: 'v1'),
      row(id: 'a2', unitID: 'imp', unitName: 'Imp', description: 'v2'),
      row(id: 'a3', unitID: 'angel', unitName: 'Angel', description: 'v1'),
    ]);

    expect(merged, hasLength(2));
    expect(merged[0].row.description, 'v1');
    expect(merged[0].creatures.map((c) => c.unitName).toList(),
        ['Angel', 'Orc']);
    expect(merged[1].row.description, 'v2');
  });

  test('helper flags from raw_json participate in the group key', () {
    final merged = mergeAbilityRows([
      row(id: 'a1', unitID: 'orc', unitName: 'Orc', rawJSON: '{"actionCost": 0}'),
      row(id: 'a2', unitID: 'imp', unitName: 'Imp', rawJSON: '{"actionCost": 1}'),
    ]);
    expect(merged, hasLength(2));
  });

  test('abilityHelperFlags replicates Swift optional-cast semantics', () {
    // Absent / invalid JSON → defaults (true, true).
    expect(abilityHelperFlags(null),
        (endsTurn: true, spendsFocusCharges: true));
    expect(abilityHelperFlags('garbage'),
        (endsTurn: true, spendsFocusCharges: true));
    // actionCost 0 → does not end turn; dontUseEnergy true → no charges.
    expect(abilityHelperFlags('{"actionCost": 0, "dontUseEnergy": true}'),
        (endsTurn: false, spendsFocusCharges: false));
    // Non-int actionCost behaves like absent (nil != 0 → true in Swift).
    expect(abilityHelperFlags('{"actionCost": "0"}').endsTurn, isTrue);
  });

  test('groupedAbilityListItems counts variants per ability name', () {
    final items = groupedAbilityListItems([
      row(id: 'a1', unitID: 'orc', unitName: 'Orc', description: 'v1'),
      row(id: 'a2', unitID: 'imp', unitName: 'Imp', description: 'v2'),
      row(id: 'b1', unitID: 'orc', unitName: 'Orc', name: 'Roar',
          description: 'roars'),
    ]);

    expect(items, hasLength(2));
    expect(items[0].name, 'Cleave');
    expect(items[0].id, 'a1');
    expect(items[0].variantCount, 2);
    expect(items[1].name, 'Roar');
    expect(items[1].variantCount, 1);
  });
}
