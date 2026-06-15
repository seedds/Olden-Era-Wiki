// Pumps every list and detail screen with the real bundled database and
// asserts they build without exceptions and lay out non-degenerate content.
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:olden_era_wiki/app.dart';
import 'package:olden_era_wiki/data/database.dart';
import 'package:olden_era_wiki/data/queries/abilities_queries.dart';
import 'package:olden_era_wiki/data/queries/artifacts_queries.dart';
import 'package:olden_era_wiki/data/queries/buildings_queries.dart';
import 'package:olden_era_wiki/data/queries/faction_laws_queries.dart';
import 'package:olden_era_wiki/data/queries/heroes_queries.dart';
import 'package:olden_era_wiki/data/queries/map_objects_queries.dart';
import 'package:olden_era_wiki/data/queries/skills_queries.dart';
import 'package:olden_era_wiki/data/queries/spells_queries.dart';
import 'package:olden_era_wiki/data/queries/subclasses_queries.dart';
import 'package:olden_era_wiki/data/queries/units_queries.dart';
import 'package:olden_era_wiki/screens/abilities/abilities_list_screen.dart';
import 'package:olden_era_wiki/screens/abilities/ability_detail_screen.dart';
import 'package:olden_era_wiki/screens/artifacts/artifact_detail_screen.dart';
import 'package:olden_era_wiki/screens/artifacts/artifacts_list_screen.dart';
import 'package:olden_era_wiki/screens/buildings/building_detail_screen.dart';
import 'package:olden_era_wiki/screens/buildings/buildings_list_screen.dart';
import 'package:olden_era_wiki/screens/faction_laws/faction_law_detail_screen.dart';
import 'package:olden_era_wiki/screens/faction_laws/faction_laws_list_screen.dart';
import 'package:olden_era_wiki/screens/heroes/hero_detail_screen.dart';
import 'package:olden_era_wiki/screens/heroes/heroes_list_screen.dart';
import 'package:olden_era_wiki/screens/home_screen.dart';
import 'package:olden_era_wiki/screens/map_objects/map_object_detail_screen.dart';
import 'package:olden_era_wiki/screens/map_objects/map_objects_list_screen.dart';
import 'package:olden_era_wiki/screens/settings/settings_screen.dart';
import 'package:olden_era_wiki/screens/skills/skill_detail_screen.dart';
import 'package:olden_era_wiki/screens/skills/skills_list_screen.dart';
import 'package:olden_era_wiki/screens/spells/spell_detail_screen.dart';
import 'package:olden_era_wiki/screens/spells/spells_list_screen.dart';
import 'package:olden_era_wiki/screens/subclasses/subclass_detail_screen.dart';
import 'package:olden_era_wiki/screens/subclasses/subclasses_list_screen.dart';
import 'package:olden_era_wiki/screens/units/unit_detail_screen.dart';
import 'package:olden_era_wiki/screens/units/units_list_screen.dart';
import 'package:olden_era_wiki/search/search_results_view.dart';
import 'package:olden_era_wiki/search/search_state.dart';
import 'package:olden_era_wiki/settings/app_settings.dart';
import 'package:olden_era_wiki/widgets/nav_bar_state.dart';
import 'package:olden_era_wiki/widgets/tab_nav_state.dart';
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

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    final search = SearchState();
    addTearDown(search.dispose);
    final navBar = NavBarState();
    addTearDown(navBar.dispose);
    await tester.pumpWidget(
      AppSettingsScope(
        settings: settings,
        child: SearchScope(
          search: search,
          child: NavBarScope(
            navBar: navBar,
            child: CupertinoApp(home: screen),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // The screen body must occupy real space (guards against zero-size
    // layout collapses).
    final scrollables = find.byWidgetPredicate(
        (widget) => widget is ScrollView || widget is SingleChildScrollView);
    expect(scrollables, findsWidgets);
    final size = tester.getSize(scrollables.first);
    expect(size.width, greaterThan(100));
    expect(size.height, greaterThan(100));
  }

  testWidgets('home screen', (tester) async {
    await pumpScreen(tester, const HomeScreen());
    expect(find.text('Units'), findsOneWidget);
    expect(find.text('Objects'), findsOneWidget);
  });

  testWidgets('settings screen (no IAP, no theme option)', (tester) async {
    await pumpScreen(tester, const SettingsScreen());
    expect(find.text('Theme'), findsNothing);
    expect(find.text('Font Size'), findsOneWidget);
    expect(find.textContaining('Unlock'), findsNothing);
    expect(find.textContaining('Purchase'), findsNothing);
    expect(find.textContaining('Game version'), findsOneWidget);
  });

  testWidgets('units list + detail', (tester) async {
    final units = WikiDatabase.instance.listUnits();
    await pumpScreen(tester, const UnitsListScreen());
    await pumpScreen(tester, UnitDetailScreen(unitID: units.first.id));
    expect(find.text('Creature Stats'), findsOneWidget);
  });

  testWidgets('abilities list + detail', (tester) async {
    final abilities = WikiDatabase.instance.listAbilities();
    await pumpScreen(tester, const AbilitiesListScreen());
    await pumpScreen(
        tester, AbilityDetailScreen(abilityID: abilities.first.id));
  });

  testWidgets('heroes list + detail', (tester) async {
    final heroes = WikiDatabase.instance.listHeroes();
    await pumpScreen(tester, const HeroesListScreen());
    await pumpScreen(tester, HeroDetailScreen(heroID: heroes.first.id));
    expect(find.text('Hero Info'), findsOneWidget);
  });

  testWidgets('skills list + detail', (tester) async {
    final skills = WikiDatabase.instance.listSkills();
    await pumpScreen(tester, const SkillsListScreen());
    await pumpScreen(tester, SkillDetailScreen(skillID: skills.first.id));
  });

  testWidgets('spells list + detail', (tester) async {
    final spells = WikiDatabase.instance.listSpells();
    await pumpScreen(tester, const SpellsListScreen());
    await pumpScreen(tester, SpellDetailScreen(spellID: spells.first.id));
  });

  testWidgets('artifacts list + detail', (tester) async {
    final artifacts = WikiDatabase.instance.listArtifacts();
    await pumpScreen(tester, const ArtifactsListScreen());
    await pumpScreen(
        tester, ArtifactDetailScreen(artifactID: artifacts.first.id));
  });

  testWidgets('buildings list + detail', (tester) async {
    final buildings = WikiDatabase.instance.listBuildings();
    await pumpScreen(tester, const BuildingsListScreen());
    await pumpScreen(
        tester, BuildingDetailScreen(entityID: buildings.first.entityID));
  });

  testWidgets('faction laws list + detail', (tester) async {
    final laws = WikiDatabase.instance.listFactionLaws();
    await pumpScreen(tester, const FactionLawsListScreen());
    await pumpScreen(tester, FactionLawDetailScreen(lawID: laws.first.id));
  });

  testWidgets('subclasses list + detail', (tester) async {
    final subclasses = WikiDatabase.instance.listSubclasses();
    await pumpScreen(tester, const SubclassesListScreen());
    await pumpScreen(
        tester, SubclassDetailScreen(subclassID: subclasses.first.id));
  });

  testWidgets('map objects list + detail', (tester) async {
    final objects = WikiDatabase.instance.listMapObjects();
    await pumpScreen(tester, const MapObjectsListScreen());
    await pumpScreen(
        tester, MapObjectDetailScreen(objectID: objects.first.id));
    expect(find.text('Object Info'), findsOneWidget);
  });

  testWidgets('tapping the search button focuses the field without a second tap',
      (tester) async {
    // Regression: the search field is a single persistent CupertinoTextField
    // (never swapped during the expand animation), so a single tap must leave
    // it focused and ready for input immediately.
    await tester.pumpWidget(OldenEraWikiApp(settings: settings));
    await tester.pump();

    await tester.tap(find.byIcon(CupertinoIcons.search).first);
    await tester.pumpAndSettle();

    // The visible search field is focused — not just any shared node state.
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue);
    expect(FocusManager.instance.primaryFocus, editable.focusNode);
  });

  testWidgets('search overlay appears with results and restores state',
      (tester) async {
    // The search bar lives in the persistent shell, so pump the real app.
    await tester.pumpWidget(OldenEraWikiApp(settings: settings));
    await tester.pump();
    final search =
        SearchScope.of(tester.element(find.byType(HomeScreen)));

    // The bottom bar starts with a collapsed search pill (a circle button).
    // Tap the magnifying-glass icon to expand the morphing search field, then
    // let the spring/keyboard settle so the EditableText is present.
    await tester.tap(find.byIcon(CupertinoIcons.search).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'fire');
    // Before the debounce fires the overlay shows nothing — no "No results
    // found." flash, no spinner.
    await tester.pump();
    expect(search.results, isEmpty);
    expect(find.text('No results found.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(search.isShowingResults, isTrue);
    expect(search.results, isNotEmpty);
    expect(find.byType(SearchOverlay), findsOneWidget);

    // Tapping a result pushes its detail page. The originating screen keeps
    // the overlay painted in its (covered) subtree so the later pop reveals
    // it with no flash.
    await tester.tap(find.text(search.results.first.title).first);
    await tester.pumpAndSettle();
    expect(search.isOverlayPresented, isFalse);
    expect(search.restoreDepthFor(AppTab.home), 0);
    expect(find.byType(SearchOverlay), findsNothing);
    expect(find.byType(SearchOverlay, skipOffstage: false), findsOneWidget);

    // Popping back re-presents the overlay.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(search.isOverlayPresented, isTrue);
    expect(search.restoreDepthFor(AppTab.home), isNull);
    expect(find.byType(SearchOverlay), findsOneWidget);

    // A query that matches nothing shows an empty box — no "No results
    // found." text.
    await tester.enterText(find.byType(EditableText), 'zzzzqqq');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(search.results, isEmpty);
    expect(find.text('No results found.'), findsNothing);

    // Clearing the text dismisses the overlay.
    await tester.enterText(find.byType(EditableText), '');
    await tester.pump(const Duration(milliseconds: 300));
    expect(search.isShowingResults, isFalse);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('search restores after opening a result from the Settings tab',
      (tester) async {
    await tester.pumpWidget(OldenEraWikiApp(settings: settings));
    await tester.pump();
    final search =
        SearchScope.of(tester.element(find.byType(HomeScreen)));

    // Switch to the Settings tab via the bottom bar.
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    // Activating search is always a Home-context action: tapping the search
    // circle switches back to the Home tab before expanding the field.
    await tester.tap(find.byIcon(CupertinoIcons.search).first);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'fire');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    expect(search.isShowingResults, isTrue);
    expect(find.byType(SearchOverlay), findsOneWidget);

    // Open a result — it pushes a detail page on the Home tab's stack, since
    // search always operates on Home.
    await tester.tap(find.text(search.results.first.title).first);
    await tester.pumpAndSettle();
    expect(search.isOverlayPresented, isFalse);
    expect(search.restoreDepthFor(AppTab.home), 0);
    // The Settings tab must NOT have recorded a restore point.
    expect(search.restoreDepthFor(AppTab.settings), isNull);
    expect(find.byType(SearchOverlay), findsNothing);

    // The top-bar back button pops to root and re-presents the overlay
    // (without clearing the query).
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(search.isOverlayPresented, isTrue);
    expect(search.restoreDepthFor(AppTab.home), isNull);
    expect(find.byType(SearchOverlay), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('re-tapping active Settings tab pops its stack to root',
      (tester) async {
    await tester.pumpWidget(OldenEraWikiApp(settings: settings));
    await tester.pumpAndSettle();

    // Settings tab → push the Font Size sub-screen.
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Font Size'));
    await tester.pumpAndSettle();
    expect(find.text('Font Size'), findsWidgets);
    expect(find.text('Report bug'), findsNothing);

    // Re-tapping the active Settings tab pops back to the Settings root.
    await tester.tap(find.byIcon(CupertinoIcons.gear).first);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Report bug'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
