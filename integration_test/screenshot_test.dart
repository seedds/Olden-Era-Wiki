// Fully automated screenshot capture test.
//
// Launches the real app, navigates key screens, and captures a screenshot
// of each one.  Run via the shell wrapper:
//
//   ./scripts/take_screenshots.sh
//
// or directly:
//
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_test.dart \
//     -d <simulator_id>
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:olden_era_wiki/app.dart';
import 'package:olden_era_wiki/data/database.dart';
import 'package:olden_era_wiki/settings/app_settings.dart';
import 'package:olden_era_wiki/widgets/stat_icons.dart';
import 'package:olden_era_wiki/widgets/unit_row.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture app screenshots', (tester) async {
    // ── Bootstrap (mirrors main.dart) ──────────────────────────────────
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await WikiDatabase.initialize(prefs);
    await StatIcons.load();
    final settings = AppSettings(prefs);

    // ── Launch the full app ────────────────────────────────────────────
    await tester.pumpWidget(OldenEraWikiApp(settings: settings));
    await tester.pumpAndSettle();

    // view.padding is in physical pixels. The iOS takeScreenshot() does not
    // accept per-call args, so we report the insets back to the host driver
    // via reportData; the driver crops the saved PNGs afterwards.
    final view = tester.view;
    binding.reportData = <String, dynamic>{
      'topInset': view.padding.top.round(),
      'bottomInset': view.padding.bottom.round(),
    };

    // ── Helper ─────────────────────────────────────────────────────────
    Future<void> screenshot(String name) async {
      // Give the GPU a moment to finish rendering.
      await tester.pump(const Duration(milliseconds: 100));
      await binding.takeScreenshot(name);
    }

    // 1. Home screen
    await screenshot('01_home');

    // 2. Units list — tap the "Units" row on the home screen
    await tester.tap(find.text('Units'));
    await tester.pumpAndSettle();
    await screenshot('02_units_list');

    // 3. Unit detail — tap the first UnitRow in the list
    await tester.tap(find.byType(UnitRow).first);
    await tester.pumpAndSettle();
    await screenshot('03_unit_detail');

    // 4. Navigate back to home, then open Heroes list
    final backButton = find.byType(CupertinoNavigationBarBackButton);
    await tester.tap(backButton.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(CupertinoIcons.house_fill).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Heroes'));
    await tester.pumpAndSettle();
    await screenshot('04_heroes_list');

    // 5. Search — go back to home, type a query in the search bar
    await tester.tap(find.byIcon(CupertinoIcons.house_fill).first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(CupertinoSearchTextField),
      'fire',
    );
    // Wait for the debounce (150 ms) + results to build.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    // Dismiss the keyboard so the search results are fully visible.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await screenshot('05_search');
  });
}
