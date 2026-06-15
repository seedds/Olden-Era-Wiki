import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/hero.dart';
import '../../data/models/search.dart';
import '../../data/models/spell.dart';
import '../../data/queries/heroes_queries.dart';
import '../../data/queries/spells_queries.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/hero_row.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';

/// Port of SpellDetailView.swift.
class SpellDetailScreen extends StatefulWidget {
  const SpellDetailScreen({super.key, required this.spellID});

  final String spellID;

  @override
  State<SpellDetailScreen> createState() => _SpellDetailScreenState();
}

class _SpellDetailScreenState extends State<SpellDetailScreen> {
  SpellDetail? _spell;
  List<HeroListItem> _startingHeroes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      final db = WikiDatabase.instance;
      _spell = db.fetchSpellDetail(widget.spellID);
      _startingHeroes = db.fetchStartingHeroesForSpell(widget.spellID);
    } catch (error) {
      debugPrint('Error loading spell detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final spell = _spell;
    return AppScaffold(
      title: spell?.name ?? 'Spell',
      searchPriority: SearchEntityType.spells,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomInset(extra: 32)),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : spell == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(spell: spell),
                      for (final level in spell.levels) ...[
                        const SizedBox(height: 20),
                        _LevelSection(level: level),
                      ],
                      if (_startingHeroes.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _StartingHeroesSection(heroes: _startingHeroes),
                      ],
                    ],
                  ),
      ),
    );
  }
}

String _capitalized(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Port of SpellHeaderSection (SpellDetailView.swift).
class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.spell});

  final SpellDetail spell;

  @override
  Widget build(BuildContext context) {
    final school = spell.school;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
          ),
          child: LocalImage(spell.iconPath,
              size: 120, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          spell.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (school != null && school.isNotEmpty)
              MetadataBadge(text: _capitalized(school), emphasized: true),
            if (spell.rank != null)
              MetadataBadge(text: 'Rank ${spell.rank}', emphasized: true),
            MetadataBadge(
                text: spell.usedOnMap ? 'World Spell' : 'Battle Spell',
                emphasized: true),
          ],
        ),
      ],
    );
  }
}

/// Port of SpellLevelSection (SpellDetailView.swift).
class _LevelSection extends StatelessWidget {
  const _LevelSection({required this.level});

  final SpellLevelDetail level;

  @override
  Widget build(BuildContext context) {
    final manaCost = level.manaCost;
    final description = level.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Level ${level.level}',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (manaCost != null)
                Text(
                  'Mana Cost: $manaCost',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accent,
                  ),
                ),
              if (manaCost != null &&
                  description != null &&
                  description.isNotEmpty)
                const SizedBox(height: 12),
              if (description != null && description.isNotEmpty)
                HighlightedDescriptionText(description, fontSize: 17),
            ],
          ),
        ),
      ],
    );
  }
}

class _StartingHeroesSection extends StatelessWidget {
  const _StartingHeroesSection({required this.heroes});

  final List<HeroListItem> heroes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Heroes starting with this spell'),
        const SizedBox(height: 12),
        for (final hero in heroes) ...[
          HeroRow(hero: hero),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
