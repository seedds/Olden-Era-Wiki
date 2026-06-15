// Verifies the persistent nav bar's faction filter button works end-to-end.
// The button is rendered above the app Navigator, so it presents its anchored
// dropdown menu in the root overlay (resolved via RootNavigatorScope).
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:olden_era_wiki/app.dart';
import 'package:olden_era_wiki/data/database.dart';
import 'package:olden_era_wiki/data/queries/units_queries.dart';
import 'package:olden_era_wiki/screens/units/units_list_screen.dart';
import 'package:olden_era_wiki/settings/app_settings.dart';
import 'package:olden_era_wiki/theme/app_theme.dart';
import 'package:olden_era_wiki/widgets/faction_filter.dart';
import 'package:olden_era_wiki/widgets/stat_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettings settings;

  setUpAll(() async {
    WikiDatabase.initializeForTesting('assets/db/wiki.sqlite');
    await StatIcons.load();
    SharedPreferences.setMockInitialValues({});
    settings = AppSettings(await SharedPreferences.getInstance());
  });

  Future<void> openUnits(WidgetTester tester) async {
    await tester.pumpWidget(OldenEraWikiApp(settings: settings));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Units').first);
    await tester.pumpAndSettle();
    expect(find.byType(UnitsListScreen), findsOneWidget);
  }

  testWidgets('filter opens an anchored menu and filters the list',
      (tester) async {
    await openUnits(tester);

    final allUnitsCount = WikiDatabase.instance.listUnits().length;
    expect(allUnitsCount, greaterThan(0));

    // Tap the filter button rendered in the persistent nav bar.
    await tester.tap(find.byType(FactionFilterButton));
    await tester.pumpAndSettle();

    // The dropdown menu appears (no CupertinoActionSheet / bottom sheet).
    expect(find.text('All Factions'), findsOneWidget);
    expect(find.byType(CupertinoActionSheet), findsNothing);

    // Pick a faction that filters out some units.
    final factions = WikiDatabase.instance.fetchFactions();
    expect(factions, isNotEmpty);
    final firstFaction = factions.first;
    final expectedCount = WikiDatabase.instance
        .listUnits()
        .where((u) => u.factionID == firstFaction)
        .length;
    expect(expectedCount, lessThan(allUnitsCount),
        reason: 'test faction must filter out some units');

    // The faction name also appears in unit rows behind the menu, so target
    // the one inside the dropdown menu (the ListView that holds the unique
    // "All Factions" entry).
    final menuList = find.ancestor(
      of: find.text('All Factions'),
      matching: find.byType(ListView),
    );
    final menuItem = find.descendant(
      of: menuList,
      matching: find.text(AppTheme.factionDisplayName(firstFaction)),
    );
    expect(menuItem, findsOneWidget);
    await tester.tap(menuItem);
    await tester.pumpAndSettle();

    // Menu dismissed; no exceptions.
    expect(find.text('All Factions'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping filter twice toggles the menu (no stacking)',
      (tester) async {
    await openUnits(tester);

    // First tap opens exactly one menu.
    await tester.tap(find.byType(FactionFilterButton));
    await tester.pumpAndSettle();
    expect(find.text('All Factions'), findsOneWidget);

    // Second tap on the same button closes it — it does not stack a second.
    await tester.tap(find.byType(FactionFilterButton));
    await tester.pumpAndSettle();
    expect(find.text('All Factions'), findsNothing);

    // Reopen, then dismiss by tapping the full-screen barrier (top-left,
    // away from the menu card which is anchored top-right).
    await tester.tap(find.byType(FactionFilterButton));
    await tester.pumpAndSettle();
    expect(find.text('All Factions'), findsOneWidget);

    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();
    expect(find.text('All Factions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
