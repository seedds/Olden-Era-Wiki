import 'package:flutter/cupertino.dart';

import '../../settings/app_settings.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';

/// Port of FontSizeSettingsView.swift.
class FontSizeScreen extends StatelessWidget {
  const FontSizeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);

    return AppScaffold(
      title: 'Font Size',
      child: ListView(
        children: [
          CupertinoListSection.insetGrouped(
            backgroundColor: AppTheme.background(context),
            children: [
              for (final preference in AppFontSizePreference.values)
                CupertinoListTile(
                  title: Text(preference.title,
                      style: TextStyle(color: AppTheme.textPrimary(context))),
                  trailing: settings.fontSize == preference
                      ? const Icon(CupertinoIcons.check_mark,
                          color: AppTheme.accent, size: 18)
                      : null,
                  onTap: () => settings.fontSize = preference,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
