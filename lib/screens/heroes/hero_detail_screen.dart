import 'dart:convert';

import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/hero.dart';
import '../../data/models/search.dart';
import '../../data/queries/heroes_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/faction_label.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';
import '../../widgets/stat_icons.dart';
import 'heroes_list_screen.dart' show classDisplayName;

/// Port of HeroDetailView.swift.
class HeroDetailScreen extends StatefulWidget {
  const HeroDetailScreen({super.key, required this.heroID});

  final String heroID;

  @override
  State<HeroDetailScreen> createState() => _HeroDetailScreenState();
}

class _HeroDetailScreenState extends State<HeroDetailScreen> {
  HeroDetail? _hero;
  List<HeroStartingSkillItem> _startingSkills = [];
  List<HeroStartingSpellItem> _startingSpells = [];
  List<HeroStartingSquadItem> _squads = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      final db = WikiDatabase.instance;
      final hero = db.fetchHeroDetail(widget.heroID);
      _hero = hero;
      if (hero != null) {
        _startingSkills = db.fetchHeroStartingSkills(hero);
        _startingSpells = db.fetchHeroStartingSpells(hero);
      }
      _squads = db.fetchHeroStartingSquads(widget.heroID);
    } catch (error) {
      debugPrint('Error loading hero detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final hero = _hero;
    return AppScaffold(
      title: hero?.name ?? 'Hero',
      searchPriority: SearchEntityType.heroes,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : hero == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(hero: hero),
                      if (_LoreSection.hasContent(hero)) ...[
                        const SizedBox(height: 20),
                        _LoreSection(hero: hero),
                      ],
                      const SizedBox(height: 20),
                      _InfoSection(hero: hero),
                      if (_HeroStartStats.tryParse(hero.startStatsJSON)
                          case final stats?) ...[
                        const SizedBox(height: 20),
                        _StatsSection(stats: stats),
                      ],
                      if (_startingSkills.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _StartingItemsSection(
                          title: 'Starting Skills',
                          items: [
                            for (final skill in _startingSkills)
                              (
                                iconPath: skill.iconPath,
                                name: skill.name,
                                detail: 'Level ${skill.level}',
                                onTap: () =>
                                    pushSkillDetail(context, skill.skillID),
                              ),
                          ],
                        ),
                      ],
                      if (_startingSpells.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _StartingItemsSection(
                          title: 'Starting Spells',
                          items: [
                            for (final spell in _startingSpells)
                              (
                                iconPath: spell.iconPath,
                                name: spell.name,
                                detail: 'Level ${spell.level}',
                                onTap: () =>
                                    pushSpellDetail(context, spell.spellID),
                              ),
                          ],
                        ),
                      ],
                      if (_squads.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _StartingArmySection(squads: _squads),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.hero});

  final HeroDetail hero;

  @override
  Widget build(BuildContext context) {
    final factionID = hero.factionID;
    final classType = hero.classType;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: LocalImage(hero.portraitPath,
              size: 140, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          hero.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (factionID != null)
              HeaderPill(
                color: AppTheme.factionColor(context, factionID),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LocalImage(AppTheme.factionIconPath(factionID), size: 22),
                    const SizedBox(width: 6),
                    Text(AppTheme.factionDisplayName(factionID)),
                  ],
                ),
              ),
            if (classType != null)
              HeaderPill(
                color: AppTheme.accent,
                child: Text(classDisplayName(classType)),
              ),
            if (hero.startLevel != null)
              HeaderPill(
                color: AppTheme.accent,
                child: Text('Level ${hero.startLevel}'),
              ),
          ],
        ),
      ],
    );
  }
}

class _LoreSection extends StatelessWidget {
  const _LoreSection({required this.hero});

  final HeroDetail hero;

  static bool _hasText(String? value) =>
      value != null && value.trim().isNotEmpty;

  static bool hasContent(HeroDetail hero) =>
      _hasText(hero.motto) ||
      _hasText(hero.description) ||
      _hasText(hero.specializationName) ||
      _hasText(hero.specializationDescription);

  @override
  Widget build(BuildContext context) {
    final motto = hero.motto;
    final description = hero.description;
    final specializationDescription = hero.specializationDescription;
    final hasSpecialization = _hasText(hero.specializationName) ||
        _hasText(specializationDescription);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Lore'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_hasText(motto))
                Text(
                  '"$motto"',
                  style: const TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: AppTheme.accent,
                  ),
                ),
              if (_hasText(description)) ...[
                if (_hasText(motto)) const SizedBox(height: 12),
                HighlightedDescriptionText(description!, fontSize: 17),
              ],
              if (hasSpecialization) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                      height: 1, color: AppTheme.cardBorder(context)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    LocalImage(hero.specializationIconPath,
                        size: 40, borderRadius: BorderRadius.circular(8)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hero.specializationName ?? 'Specialization',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary(context),
                            ),
                          ),
                          if (_hasText(specializationDescription)) ...[
                            const SizedBox(height: 4),
                            HighlightedDescriptionText(
                                specializationDescription!),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.hero});

  final HeroDetail hero;

  @override
  Widget build(BuildContext context) {
    final classType = hero.classType;
    final nativeBiome = hero.nativeBiome;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Hero Info'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            children: [
              _InfoRow(
                iconPath: hero.classIconPath,
                label: 'Class',
                value:
                    classType != null ? classDisplayName(classType) : '-',
              ),
              _InfoRow(
                iconPath: AppTheme.factionIconPath(hero.factionID),
                label: 'Faction',
                value: AppTheme.factionDisplayName(hero.factionID),
              ),
              _InfoRow(
                label: 'Starting Level',
                value: hero.startLevel?.toString() ?? '-',
              ),
              _InfoRow(
                label: 'Native Biome',
                value: nativeBiome != null
                    ? _biomeDisplayName(nativeBiome)
                    : '-',
              ),
              _InfoRow(
                iconPath: StatIcons.gold,
                label: 'Hiring Cost',
                value: hero.costGold?.toString() ?? '-',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.stats});

  final _HeroStartStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Starting Stats'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            children: [
              _StatPairRow(
                left: (StatIcons.attack, 'Offence', stats.offenceText),
                right: (StatIcons.defense, 'Defence', stats.defenceText),
              ),
              _StatPairRow(
                left: (StatIcons.energy, 'Spell Power', stats.spellPowerText),
                right: (
                  StatIcons.experience,
                  'Intelligence',
                  stats.intelligenceText
                ),
              ),
              _StatPairRow(
                left: (StatIcons.luck, 'Luck', stats.luckText),
                right: (StatIcons.morale, 'Morale', stats.moraleText),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:
                    Container(height: 1, color: AppTheme.cardBorder(context)),
              ),
              _InfoRow(label: 'View Radius', value: stats.viewRadiusText),
              _InfoRow(
                  label: 'Magic Casts / Round',
                  value: stats.magicCastsPerRoundText),
              _InfoRow(label: 'Tactics', value: stats.tacticsText),
              _InfoRow(
                  label: 'Native Biome Bonus', value: stats.nativeBiomeText),
            ],
          ),
        ),
      ],
    );
  }
}

typedef _StartingItem = ({
  String? iconPath,
  String name,
  String detail,
  VoidCallback onTap,
});

class _StartingItemsSection extends StatelessWidget {
  const _StartingItemsSection({required this.title, required this.items});

  final String title;
  final List<_StartingItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 12),
        for (final item in items) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: item.onTap,
            child: _LinkCard(
              iconPath: item.iconPath,
              title: item.name,
              subtitle: Text(
                item.detail,
                style: const TextStyle(fontSize: 12, color: AppTheme.accent),
              ),
              showsChevron: true,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _StartingArmySection extends StatelessWidget {
  const _StartingArmySection({required this.squads});

  final List<HeroStartingSquadItem> squads;

  static int _variantSortOrder(String variant) => switch (variant) {
        'default' => 0,
        'alt' => 1,
        _ => 2,
      };

  static String _variantTitle(String variant) => switch (variant) {
        'default' => 'Default Army',
        'alt' => 'Alternative Army',
        _ => _capitalizeWords(variant.replaceAll('_', ' ')),
      };

  List<(String, List<HeroStartingSquadItem>)> get _groupedSquads {
    final groups = <String, List<HeroStartingSquadItem>>{};
    for (final squad in squads) {
      groups.putIfAbsent(squad.variant, () => []).add(squad);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) {
        final order =
            _variantSortOrder(a.key).compareTo(_variantSortOrder(b.key));
        if (order != 0) return order;
        return a.key.compareTo(b.key);
      });
    return [for (final entry in entries) (entry.key, entry.value)];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Starting Army'),
        for (final (variant, items) in _groupedSquads) ...[
          const SizedBox(height: 12),
          Text(
            _variantTitle(variant),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 10),
          for (final squad in items) ...[
            _ArmyRow(squad: squad),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _ArmyRow extends StatelessWidget {
  const _ArmyRow({required this.squad});

  final HeroStartingSquadItem squad;

  String get _countText {
    final min = squad.minCount;
    final max = squad.maxCount;
    if (min != null && max != null) {
      return min == max ? 'Count $min' : 'Count $min-$max';
    }
    if (min != null) return 'Count $min+';
    if (max != null) return 'Up to $max';
    return 'Count unknown';
  }

  @override
  Widget build(BuildContext context) {
    final unitID = squad.unitID;
    final row = _LinkCard(
      iconPath: squad.unitIconPath,
      title: squad.unitName ?? unitID ?? 'Unknown Unit',
      subtitle: Row(
        children: [
          if (squad.unitFactionID != null) ...[
            DefaultTextStyle(
              style: const TextStyle(fontSize: 12),
              child:
                  FactionLabel(factionID: squad.unitFactionID, iconSize: 14),
            ),
            const SizedBox(width: 8),
          ],
          if (squad.unitTier != null) ...[
            Text(
              'Tier ${squad.unitTier}',
              style: const TextStyle(fontSize: 12, color: AppTheme.accent),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            _countText,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ),
      showsChevron: unitID != null,
    );

    if (unitID == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushUnitDetail(context, unitID),
      child: row,
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.iconPath,
    required this.title,
    required this.subtitle,
    this.showsChevron = false,
  });

  final String? iconPath;
  final String title;
  final Widget subtitle;
  final bool showsChevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(context),
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
            child: LocalImage(iconPath,
                size: 44, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                subtitle,
              ],
            ),
          ),
          if (showsChevron)
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({this.iconPath, required this.label, required this.value});

  final String? iconPath;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (iconPath != null) ...[
            LocalImage(iconPath, size: 22),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.statValue(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPairRow extends StatelessWidget {
  const _StatPairRow({required this.left, required this.right});

  final (String?, String, String) left;
  final (String?, String, String) right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: _statCell(context, left)),
          const SizedBox(width: 16),
          Expanded(child: _statCell(context, right)),
        ],
      ),
    );
  }

  Widget _statCell(BuildContext context, (String?, String, String) stat) {
    final (icon, name, value) = stat;
    return Row(
      children: [
        LocalImage(icon, size: 22),
        const SizedBox(width: 8),
        Text(
          name,
          style:
              TextStyle(fontSize: 15, color: AppTheme.textSecondary(context)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.statValue(context),
          ),
        ),
      ],
    );
  }
}

/// Port of HeroStartStats (HeroesListView.swift), decoded from
/// heroes.start_stats_json.
class _HeroStartStats {
  const _HeroStartStats({
    this.viewRadius,
    this.magicCastsPerRound,
    this.enableTactics,
    this.tacticsPlacementSize,
    this.enableHeroNativeBiome,
    this.offence,
    this.defence,
    this.spellPower,
    this.intelligence,
    this.luck,
    this.moral,
  });

  final int? viewRadius;
  final int? magicCastsPerRound;
  final bool? enableTactics;
  final int? tacticsPlacementSize;
  final bool? enableHeroNativeBiome;
  final int? offence;
  final int? defence;
  final int? spellPower;
  final int? intelligence;
  final int? luck;
  final int? moral;

  static _HeroStartStats? tryParse(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      int? asInt(String key) => (decoded[key] as num?)?.toInt();
      bool? asBool(String key) =>
          decoded[key] is bool ? decoded[key] as bool : null;
      return _HeroStartStats(
        viewRadius: asInt('viewRadius'),
        magicCastsPerRound: asInt('magicCastsPerRound'),
        enableTactics: asBool('enableTactics'),
        tacticsPlacementSize: asInt('tacticsPlacementSize'),
        enableHeroNativeBiome: asBool('enableHeroNativeBiome'),
        offence: asInt('offence'),
        defence: asInt('defence'),
        spellPower: asInt('spellPower'),
        intelligence: asInt('intelligence'),
        luck: asInt('luck'),
        moral: asInt('moral'),
      );
    } catch (_) {
      return null;
    }
  }

  String get offenceText => offence?.toString() ?? '-';
  String get defenceText => defence?.toString() ?? '-';
  String get spellPowerText => spellPower?.toString() ?? '-';
  String get intelligenceText => intelligence?.toString() ?? '-';
  String get luckText => luck?.toString() ?? '-';
  String get moraleText => moral?.toString() ?? '-';
  String get viewRadiusText => viewRadius?.toString() ?? '-';
  String get magicCastsPerRoundText => magicCastsPerRound?.toString() ?? '-';

  String get tacticsText {
    final enabled = enableTactics;
    if (enabled == null) return '-';
    if (!enabled) return 'Disabled';
    final size = tacticsPlacementSize;
    if (size != null) return 'Enabled ($size tiles)';
    return 'Enabled';
  }

  String get nativeBiomeText {
    final enabled = enableHeroNativeBiome;
    if (enabled == null) return '-';
    return enabled ? 'Enabled' : 'Disabled';
  }
}

String _biomeDisplayName(String biome) =>
    _capitalizeWords(biome.replaceAll('_', ' '));

String _capitalizeWords(String value) => value
    .split(' ')
    .map((word) =>
        word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
    .join(' ');
