import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/database.dart';
import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import 'font_size_screen.dart';

/// Port of SettingsView.swift, without the StoreKit section (the app is
/// fully free).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _gameVersion;

  @override
  void initState() {
    super.initState();
    try {
      _gameVersion = WikiDatabase.instance.fetchGameVersion();
    } catch (error) {
      debugPrint('Error loading game version: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return AppScaffold(
      title: 'Settings',
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            backgroundColor: AppTheme.background(context),
            children: [
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.textformat_size,
                    color: AppTheme.accent),
                title: Text('Font Size',
                    style: TextStyle(color: AppTheme.textPrimary(context))),
                additionalInfo: Text(settings.fontSize.title),
                trailing: const CupertinoListTileChevron(),
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                      builder: (context) => const FontSizeScreen()),
                ),
              ),
              CupertinoListTile(
                leading: const Icon(CupertinoIcons.ant, color: AppTheme.accent),
                title: Text('Report bug',
                    style: TextStyle(color: AppTheme.textPrimary(context))),
                onTap: () => launchUrl(Uri.parse('mailto:seedds@gmail.com')),
              ),
              if (_gameVersion != null)
                CupertinoListTile(
                  leading: const Icon(CupertinoIcons.info,
                      color: AppTheme.accent),
                  title: Text('Game version',
                      style: TextStyle(color: AppTheme.textPrimary(context))),
                  additionalInfo: Text(_gameVersion!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
