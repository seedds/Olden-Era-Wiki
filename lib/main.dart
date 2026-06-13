import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/database.dart';
import 'settings/app_settings.dart';
import 'widgets/stat_icons.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await WikiDatabase.initialize(prefs);
  await StatIcons.load();

  runApp(OldenEraWikiApp(settings: AppSettings(prefs)));
}
