import 'dart:convert';

import 'package:flutter/services.dart';

/// Port of StatIcons.swift — loads icons.json and provides typed access.
abstract final class StatIcons {
  static Map<String, String> _mapping = const {};

  static Future<void> load() async {
    final raw = await rootBundle.loadString('assets/icons.json');
    _mapping = Map<String, String>.from(jsonDecode(raw) as Map);
  }

  static String? pathFor(String key) => _mapping[key];

  static String get hp => _mapping['hp'] ?? '';
  static String get attack => _mapping['attack'] ?? '';
  static String get defense => _mapping['defense'] ?? '';
  static String get damage => _mapping['damage'] ?? '';
  static String get initiative => _mapping['initiative'] ?? '';
  static String get speed => _mapping['speed'] ?? '';
  static String get luck => _mapping['luck'] ?? '';
  static String get morale => _mapping['morale'] ?? '';
  static String get experience => _mapping['experience'] ?? '';
  static String get squadValue => _mapping['squadValue'] ?? '';
  static String get energy => _mapping['energy'] ?? '';
  static String get gold => _mapping['gold'] ?? '';
  static String get lawPoints => _mapping['lawPoints'] ?? '';
  static String get dust => _mapping['dust'] ?? '';
  static String get cooldown => _mapping['cooldown'] ?? '';
}
