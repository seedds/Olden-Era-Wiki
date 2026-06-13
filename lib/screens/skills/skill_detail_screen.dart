import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/hero.dart';
import '../../data/models/search.dart';
import '../../data/models/skill.dart';
import '../../data/queries/heroes_queries.dart';
import '../../data/queries/skills_queries.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/hero_row.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';

/// Port of SkillDetailView.swift.
class SkillDetailScreen extends StatefulWidget {
  const SkillDetailScreen({super.key, required this.skillID});

  final String skillID;

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen> {
  SkillDetail? _skill;
  List<HeroListItem> _startingHeroes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      final db = WikiDatabase.instance;
      _skill = db.fetchSkillDetail(widget.skillID);
      _startingHeroes = db.fetchStartingHeroesForSkill(widget.skillID);
    } catch (error) {
      debugPrint('Error loading skill detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final skill = _skill;
    return AppScaffold(
      title: skill?.name ?? 'Skill',
      searchPriority: SearchEntityType.skills,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : skill == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < skill.levels.length; i++) ...[
                        if (i > 0) const SizedBox(height: 24),
                        _SkillLevelCard(level: skill.levels[i]),
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

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

/// Port of SkillLevelCard (SkillDetailView.swift).
class _SkillLevelCard extends StatelessWidget {
  const _SkillLevelCard({required this.level});

  final SkillLevelDetail level;

  String get _levelTitle {
    final levelName = level.levelName;
    if (_hasText(levelName)) return levelName!;
    return 'Level ${level.level}';
  }

  @override
  Widget build(BuildContext context) {
    final description = level.description;
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder(context)),
                ),
                child: LocalImage(level.levelIconPath,
                    size: 64, borderRadius: BorderRadius.circular(8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _levelTitle,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    if (_hasText(description)) ...[
                      const SizedBox(height: 4),
                      HighlightedDescriptionText(description!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          for (final subskill in level.subskills) ...[
            const SizedBox(height: 12),
            _SubskillRow(subskill: subskill),
          ],
        ],
      ),
    );
  }
}

/// Port of SubskillRowView (SkillDetailView.swift).
class _SubskillRow extends StatelessWidget {
  const _SubskillRow({required this.subskill});

  final SubskillSummary subskill;

  @override
  Widget build(BuildContext context) {
    final description = subskill.description;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBorder(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.cardBorder(context)),
            ),
            child: LocalImage(subskill.iconPath,
                size: 40, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subskill.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                if (_hasText(description)) ...[
                  const SizedBox(height: 4),
                  HighlightedDescriptionText(description!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of SkillStartingHeroesSection (SkillDetailView.swift).
class _StartingHeroesSection extends StatelessWidget {
  const _StartingHeroesSection({required this.heroes});

  final List<HeroListItem> heroes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Heroes starting with this skill'),
        const SizedBox(height: 12),
        for (final hero in heroes) ...[
          HeroRow(hero: hero),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
