import 'package:flutter/cupertino.dart';

import '../data/database.dart';
import '../data/models/search.dart';
import '../screens/abilities/abilities_list_screen.dart';
import '../screens/artifacts/artifacts_list_screen.dart';
import '../screens/buildings/buildings_list_screen.dart';
import '../screens/faction_laws/faction_laws_list_screen.dart';
import '../screens/heroes/heroes_list_screen.dart';
import '../screens/map_objects/map_objects_list_screen.dart';
import '../screens/skills/skills_list_screen.dart';
import '../screens/spells/spells_list_screen.dart';
import '../screens/subclasses/subclasses_list_screen.dart';
import '../screens/units/units_list_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_scaffold.dart';

/// Port of HomeSection from HomeView.swift. Declaration order is the order
/// of the rows on the home screen.
enum HomeSection {
  units('Units', CupertinoIcons.shield_lefthalf_fill, SearchEntityType.units),
  abilities('Abilities', CupertinoIcons.bolt_fill, SearchEntityType.abilities),
  heroes('Heroes', CupertinoIcons.person_2_fill, SearchEntityType.heroes),
  skills('Skills', CupertinoIcons.sparkles, SearchEntityType.skills),
  subclasses('Subclasses', CupertinoIcons.star_circle_fill,
      SearchEntityType.subclasses),
  artifacts('Artifacts', CupertinoIcons.rosette, SearchEntityType.artifacts),
  spells('Spells', CupertinoIcons.wand_stars, SearchEntityType.spells),
  buildings(
      'Buildings', CupertinoIcons.building_2_fill, SearchEntityType.buildings),
  factionLaws(
      'Laws', CupertinoIcons.doc_text_fill, SearchEntityType.factionLaws),
  objects(
      'Objects', CupertinoIcons.cube_box_fill, SearchEntityType.mapObjects);

  const HomeSection(this.title, this.icon, this.searchEntityType);

  final String title;
  final IconData icon;
  final SearchEntityType searchEntityType;

  Widget buildScreen() => switch (this) {
        HomeSection.units => const UnitsListScreen(),
        HomeSection.abilities => const AbilitiesListScreen(),
        HomeSection.heroes => const HeroesListScreen(),
        HomeSection.skills => const SkillsListScreen(),
        HomeSection.subclasses => const SubclassesListScreen(),
        HomeSection.artifacts => const ArtifactsListScreen(),
        HomeSection.spells => const SpellsListScreen(),
        HomeSection.buildings => const BuildingsListScreen(),
        HomeSection.factionLaws => const FactionLawsListScreen(),
        HomeSection.objects => const MapObjectsListScreen(),
      };
}

/// Port of HomeView.swift.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    return AppScaffold(
      title: 'Olden Era Wiki',
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 20, 16, context.scrollBottomInset(extra: 20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_gameVersion != null) ...[
              Text(
                'Game version $_gameVersion',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary(context),
                ),
              ),
              const SizedBox(height: 6),
            ],
            for (final section in HomeSection.values) ...[
              _HomeSectionRow(section: section),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeSectionRow extends StatelessWidget {
  const _HomeSectionRow({required this.section});

  final HomeSection section;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        CupertinoPageRoute<void>(builder: (context) => section.buildScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Icon(section.icon, size: 20, color: AppTheme.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                section.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}
