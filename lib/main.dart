import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database.dart';
import 'settings/app_settings.dart';
import 'widgets/stat_icons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pre-warm the liquid glass shaders so the search bar renders without a
  // first-frame white flash.
  await LiquidGlassWidgets.initialize();

  final prefs = await SharedPreferences.getInstance();
  await WikiDatabase.initialize(prefs);
  await StatIcons.load();

  runApp(LiquidGlassWidgets.wrap(
    child: OldenEraWikiApp(settings: AppSettings(prefs)),
  ));
}
