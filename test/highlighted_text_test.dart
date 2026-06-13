import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olden_era_wiki/widgets/highlighted_text.dart';

const accent = Color(0xFFE8C355);
const secondary = Color(0xFF888888);

String plainText(List<TextSpan> spans) =>
    spans.map((span) => span.text ?? '').join();

List<String> highlightedRuns(List<TextSpan> spans) => [
      for (final span in spans)
        if (span.style?.color == accent) span.text ?? '',
    ];

List<TextSpan> render(String description) =>
    AbilityPresentation.highlightedDescription(
      description,
      accent: accent,
      secondary: secondary,
    );

void main() {
  group('highlightedDescription', () {
    test('highlights numbers, ranges and percentages', () {
      final spans = render('Deals 10-12 damage and heals 50% of it.');
      expect(plainText(spans), 'Deals 10-12 damage and heals 50% of it.');
      expect(highlightedRuns(spans), ['10-12', '50%']);
    });

    test('strips markup tags and converts <br> to newline', () {
      final spans = render('First line.<br>Second <color=#fff>line</color>.');
      expect(plainText(spans), 'First line.\nSecond line.');
    });

    test('applies bold inside <b> tags', () {
      final spans = render('A <b>bold move</b> indeed.');
      final boldSpans = spans
          .where((span) => span.style?.fontWeight == FontWeight.bold)
          .toList();
      // "bold move" is bold (and not value-highlighted).
      expect(boldSpans.any((span) => span.text == 'bold move'), isTrue);
      expect(plainText(spans), 'A bold move indeed.');
    });

    test('highlights tier-N tokens and signed values', () {
      final spans = render('Summons a tier-3 creature with +2 morale.');
      expect(highlightedRuns(spans), ['tier-3', '+2']);
    });
  });

  group('helperLines', () {
    test('reports actionCost 0 and dontUseEnergy', () {
      expect(
        AbilityPresentation.helperLines(
            '{"actionCost": 0, "dontUseEnergy": true}'),
        ['Does not end the turn.', 'Does not spend Focus Charges.'],
      );
    });

    test('empty for default flags and invalid json', () {
      expect(
          AbilityPresentation.helperLines('{"actionCost": 1}'), isEmpty);
      expect(AbilityPresentation.helperLines('not json'), isEmpty);
      expect(AbilityPresentation.helperLines(null), isEmpty);
    });
  });

  group('typeLabel', () {
    test('prefers ability type over attack type', () {
      expect(
        AbilityPresentation.typeLabel(
            abilityTypeSID: 'Ability_type_attack', attackType: 'range'),
        'Attack',
      );
      expect(
        AbilityPresentation.typeLabel(abilityTypeSID: null, attackType: 'range'),
        'Ranged',
      );
      expect(
        AbilityPresentation.typeLabel(abilityTypeSID: null, attackType: null),
        isNull,
      );
    });
  });
}
