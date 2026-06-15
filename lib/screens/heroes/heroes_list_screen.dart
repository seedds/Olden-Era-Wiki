import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/hero.dart';
import '../../data/models/search.dart';
import '../../data/queries/heroes_queries.dart';
import '../../data/queries/units_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/faction_filter.dart';
import '../../widgets/faction_label.dart';
import '../../widgets/local_image.dart';

/// Port of HeroesListView.swift.
class HeroesListScreen extends StatefulWidget {
  const HeroesListScreen({super.key});

  @override
  State<HeroesListScreen> createState() => _HeroesListScreenState();
}

class _HeroesListScreenState extends State<HeroesListScreen> {
  List<HeroListItem> _heroes = [];
  List<String> _factions = [];
  String? _selectedFaction;

  @override
  void initState() {
    super.initState();
    try {
      _heroes = WikiDatabase.instance.listHeroes();
      _factions = WikiDatabase.instance.fetchFactions();
    } catch (error) {
      debugPrint('Error loading heroes: $error');
    }
  }

  List<HeroListItem> get _filteredHeroes {
    final fid = _selectedFaction;
    if (fid == null) return _heroes;
    return _heroes.where((hero) => hero.factionID == fid).toList();
  }

  @override
  Widget build(BuildContext context) {
    final heroes = _filteredHeroes;
    return AppScaffold(
      title: 'Heroes',
      searchPriority: SearchEntityType.heroes,
      trailingExtras: [
        FactionFilterButton(
          factions: _factions,
          onSelect: (factionID) =>
              setState(() => _selectedFaction = factionID),
        ),
      ],
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, context.scrollBottomInset(extra: 24)),
        itemCount: heroes.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _HeroRowView(hero: heroes[index]),
        ),
      ),
    );
  }
}

/// Port of HeroRowView (HeroesListView.swift).
class _HeroRowView extends StatelessWidget {
  const _HeroRowView({required this.hero});

  final HeroListItem hero;

  @override
  Widget build(BuildContext context) {
    final classType = hero.classType;
    final startLevel = hero.startLevel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushHeroDetail(context, hero.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(hero.portraitPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hero.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DefaultTextStyle(
                        style: const TextStyle(fontSize: 12),
                        child: FactionLabel(
                            factionID: hero.factionID, iconSize: 14),
                      ),
                      if (classType != null)
                        MetadataBadge(
                            text: classDisplayName(classType),
                            emphasized: true),
                      if (startLevel != null)
                        MetadataBadge(text: 'Lv $startLevel', emphasized: true),
                    ],
                  ),
                ],
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

/// Port of classDisplayName(for:) (HeroesListView.swift): underscores become
/// spaces, each word capitalized.
String classDisplayName(String classType) => classType
    .replaceAll('_', ' ')
    .split(' ')
    .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
    .join(' ');
