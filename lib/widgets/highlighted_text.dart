import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../theme/app_theme.dart';

/// Port of AbilityPresentation (AbilityDetailView.swift:283-413).
abstract final class AbilityPresentation {
  // (?i)\btier[–-]\d+\b | [+-]?\d+(–\d+)?%? | –\d+%?
  static final RegExp _highlightedValueRegex = RegExp(
    r'\btier[–\-]\d+\b|(?:[+-]?\d+(?:[–\-]\d+)?%?)|(?:[–\-]\d+%?)',
    caseSensitive: false,
  );

  static final RegExp _markupTagRegex =
      RegExp(r'<(\/)?([A-Za-z]+)(?:=[^>]+)?>');

  static const Map<String, String> _abilityTypeLabels = {
    'Ability_type_buff': 'Positive effect',
    'Ability_type_attack_alt': 'Alternative Attack',
    'Ability_type_attack': 'Attack',
    'Ability_type_passive': 'Passive',
  };

  static const Map<String, String> _attackTypeLabels = {
    'melee': 'Melee',
    'range': 'Ranged',
    'cast': 'Cast',
  };

  static String? typeLabel({String? abilityTypeSID, String? attackType}) {
    final fromAbilityType = _abilityTypeLabels[abilityTypeSID];
    if (fromAbilityType != null) return fromAbilityType;
    if (attackType == null) return null;
    return _attackTypeLabels[attackType];
  }

  /// Port of highlightedDescription: strips/<applies> markup tags
  /// (`<b>`, `<i>`, `<br>`, others removed) and highlights numeric values
  /// and "tier-N" tokens in the accent color.
  static List<TextSpan> highlightedDescription(
    String description, {
    required Color accent,
    required Color secondary,
    double fontSize = 15,
  }) {
    final spans = <TextSpan>[];
    final activeTags = <String>[];

    TextStyle styleFor({bool isHighlighted = false}) {
      final isBold = isHighlighted || activeTags.contains('b');
      final isItalic = activeTags.contains('i');
      return TextStyle(
        fontSize: fontSize,
        color: isHighlighted ? accent : secondary,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
      );
    }

    void appendText(String text, {bool isHighlighted = false}) {
      if (text.isEmpty) return;
      spans.add(TextSpan(
        text: text,
        style: styleFor(isHighlighted: isHighlighted),
      ));
    }

    void appendHighlightedText(String text) {
      var textIndex = 0;
      for (final match in _highlightedValueRegex.allMatches(text)) {
        appendText(text.substring(textIndex, match.start));
        appendText(text.substring(match.start, match.end),
            isHighlighted: true);
        textIndex = match.end;
      }
      appendText(text.substring(textIndex));
    }

    var currentIndex = 0;
    for (final match in _markupTagRegex.allMatches(description)) {
      appendHighlightedText(description.substring(currentIndex, match.start));

      final tagName = match.group(2)!.toLowerCase();
      final isClosingTag = match.group(1) != null;

      switch (tagName) {
        case 'br':
          appendText('\n');
        case 'b' || 'i':
          if (isClosingTag) {
            final tagIndex = activeTags.lastIndexOf(tagName);
            if (tagIndex != -1) activeTags.removeAt(tagIndex);
          } else {
            activeTags.add(tagName);
          }
        default:
          break;
      }

      currentIndex = match.end;
    }

    appendHighlightedText(description.substring(currentIndex));

    return spans;
  }

  /// Port of helperLines(rawJSON:).
  static List<String> helperLines(String? rawJSON) {
    if (rawJSON == null) return const [];
    Map<String, dynamic> raw;
    try {
      final decoded = jsonDecode(rawJSON);
      if (decoded is! Map<String, dynamic>) return const [];
      raw = decoded;
    } catch (_) {
      return const [];
    }

    final lines = <String>[];
    final actionCost = raw['actionCost'];
    if (actionCost is int && actionCost == 0) {
      lines.add('Does not end the turn.');
    }
    final dontUseEnergy = raw['dontUseEnergy'];
    if (dontUseEnergy is bool && dontUseEnergy) {
      lines.add('Does not spend Focus Charges.');
    }
    return lines;
  }
}

/// Port of HighlightedDescriptionText.swift.
class HighlightedDescriptionText extends StatelessWidget {
  const HighlightedDescriptionText(this.description,
      {super.key, this.fontSize = 15});

  final String description;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: AbilityPresentation.highlightedDescription(
          description,
          accent: AppTheme.accent,
          secondary: AppTheme.textSecondary(context),
          fontSize: fontSize,
        ),
      ),
    );
  }
}
