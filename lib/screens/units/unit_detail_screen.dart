import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/hero.dart';
import '../../data/models/search.dart';
import '../../data/models/unit.dart';
import '../../data/queries/units_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';
import '../../widgets/stat_icons.dart';
import '../../widgets/unit_row.dart';
import '../../widgets/hero_row.dart';

/// Port of UnitDetailView.swift.
class UnitDetailScreen extends StatefulWidget {
  const UnitDetailScreen({super.key, required this.unitID});

  final String unitID;

  @override
  State<UnitDetailScreen> createState() => _UnitDetailScreenState();
}

class _UnitDetailScreenState extends State<UnitDetailScreen> {
  UnitDetail? _unit;
  List<HeroListItem> _heroes = [];
  String? _upgradeCostJSON;
  List<UnitListItem> _upgradeTo = [];
  List<UnitListItem> _upgradeFrom = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    try {
      final db = WikiDatabase.instance;
      final fetched = db.fetchUnitDetail(widget.unitID);
      if (fetched != null) {
        _unit = fetched;
        _heroes = db.fetchStartingHeroes(widget.unitID);
        final upgradeRelations = db.fetchUnitUpgradeRelations(widget.unitID);
        _upgradeTo = upgradeRelations.upgradeTo;
        _upgradeFrom = upgradeRelations.upgradeFrom;
        final upgradeSid = fetched.upgradeSid;
        if (upgradeSid != null) {
          _upgradeCostJSON = db.fetchUpgradeCost(upgradeSid);
        }
      }
    } catch (error) {
      debugPrint('Error: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final unit = _unit;
    return AppScaffold(
      title: unit?.name ?? 'Unit',
      searchPriority: SearchEntityType.units,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : unit == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(unit: unit),
                      const SizedBox(height: 20),
                      _StatsSection(
                          unit: unit, upgradeCostJSON: _upgradeCostJSON),
                      if (_upgradeTo.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _UnitLinksSection(
                            title: 'Upgrade To', units: _upgradeTo),
                      ],
                      if (_upgradeFrom.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _UnitLinksSection(
                            title: 'Upgrade From', units: _upgradeFrom),
                      ],
                      if (unit.abilities.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _AbilitiesSection(abilities: unit.abilities),
                      ],
                      if (_heroes.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _StartingHeroesSection(heroes: _heroes),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.unit});

  final UnitDetail unit;

  @override
  Widget build(BuildContext context) {
    final factionID = unit.factionID;
    final lore = unit.narrativeDescription;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: LocalImage(unit.iconPath,
              size: 140, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          unit.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
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
            if (unit.tier != null)
              HeaderPill(
                color: AppTheme.accent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(CupertinoIcons.star_fill,
                        size: 14, color: AppTheme.accent),
                    const SizedBox(width: 4),
                    Text('Tier ${unit.tier}'),
                  ],
                ),
              ),
          ],
        ),
        if (lore != null && lore.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              lore,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.unit, required this.upgradeCostJSON});

  final UnitDetail unit;
  final String? upgradeCostJSON;

  String? get _moveTypeText {
    final moveType = unit.moveType;
    if (moveType == null || moveType.isEmpty) return null;
    return moveType
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  UnitCost? get _parsedCost => UnitCost.tryParse(unit.costJSON);

  UnitCost? get _parsedUpgradeCost => UnitCost.tryParse(upgradeCostJSON);

  bool get _isBaseUnit {
    final upgradeSid = unit.upgradeSid;
    if (upgradeSid == null || upgradeSid.isEmpty) return false;
    return !unit.id.contains('_upg');
  }

  List<UnitCostItem> get _upgradeCostDeltaItems {
    final baseItems = _parsedCost?.costResArray;
    final upgradedItems = _parsedUpgradeCost?.costResArray;
    if (baseItems == null || upgradedItems == null) return const [];

    final baseCostsByName = {
      for (final item in baseItems) item.name.toLowerCase(): item.cost,
    };

    final deltas = <UnitCostItem>[];
    for (final item in upgradedItems) {
      final delta = item.cost - (baseCostsByName[item.name.toLowerCase()] ?? 0);
      if (delta > 0) {
        deltas.add(UnitCostItem(name: item.name, cost: delta));
      }
    }
    return deltas;
  }

  String _rangedStatText(int? value, int? min, int? max) {
    final baseValue = '${value ?? 0}';
    if (min == null && max == null) return baseValue;
    final minText = min?.toString() ?? 'inf';
    final maxText = max?.toString() ?? 'inf';
    return '$baseValue ($minText, $maxText)';
  }

  @override
  Widget build(BuildContext context) {
    final moveTypeText = _moveTypeText;
    final cost = _parsedCost;
    final upgradeDeltas = _upgradeCostDeltaItems;
    final baseClassName = unit.baseClassName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Creature Stats'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            children: [
              FullWidthStatRow(
                  icon: StatIcons.hp, label: 'Health', value: '${unit.hp ?? 0}'),
              FullWidthStatRow(
                  icon: StatIcons.attack,
                  label: 'Attack',
                  value: '${unit.offence ?? 0}'),
              FullWidthStatRow(
                  icon: StatIcons.defense,
                  label: 'Defense',
                  value: '${unit.defence ?? 0}'),
              FullWidthStatRow(
                  icon: StatIcons.damage,
                  label: 'Damage',
                  value: '${unit.damageMin ?? 0}-${unit.damageMax ?? 0}'),
              if (moveTypeText != null)
                FullWidthStatRow(
                    icon: StatIcons.speed,
                    label: 'Move Type',
                    value: moveTypeText),
              FullWidthStatRow(
                  icon: StatIcons.initiative,
                  label: 'Initiative',
                  value: '${unit.initiative ?? 0}'),
              FullWidthStatRow(
                  icon: StatIcons.speed,
                  label: 'Speed',
                  value: '${unit.speed ?? 0}'),
              FullWidthStatRow(
                  icon: StatIcons.luck,
                  label: 'Luck',
                  value:
                      _rangedStatText(unit.luck, unit.luckMin, unit.luckMax)),
              FullWidthStatRow(
                  icon: StatIcons.morale,
                  label: 'Morale',
                  value: _rangedStatText(
                      unit.morale, unit.moraleMin, unit.moraleMax)),
              FullWidthStatRow(
                  icon: StatIcons.squadValue,
                  label: 'Squad Value',
                  value: '${unit.squadValue ?? 0}'),
              FullWidthStatRow(
                  icon: StatIcons.experience,
                  label: 'Exp Bonus',
                  value: '${(unit.expBonus ?? 0).toInt()}'),
              FullWidthStatRow(
                  icon: StatIcons.squadValue,
                  label: 'Weekly Growth',
                  value: unit.growth?.toString() ?? '-'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                    height: 1, color: AppTheme.cardBorder(context)),
              ),
              if (baseClassName != null && baseClassName.isNotEmpty)
                FullWidthStatRow(
                  icon: unit.baseClassIconPath,
                  label: 'Creature Type',
                  value: baseClassName,
                ),
              if (cost != null)
                CostSummaryRow(label: 'Cost', items: cost.costResArray),
              if (_isBaseUnit && upgradeDeltas.isNotEmpty)
                CostSummaryRow(label: 'Upgrade Cost', items: upgradeDeltas),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnitLinksSection extends StatelessWidget {
  const _UnitLinksSection({required this.title, required this.units});

  final String title;
  final List<UnitListItem> units;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 12),
        for (final unit in units) ...[
          UnitRow(unit: unit),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AbilitiesSection extends StatelessWidget {
  const _AbilitiesSection({required this.abilities});

  final List<UnitAbilitySummary> abilities;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Abilities'),
        const SizedBox(height: 12),
        for (final ability in abilities) ...[
          _AbilityCard(ability: ability),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _AbilityCard extends StatelessWidget {
  const _AbilityCard({required this.ability});

  final UnitAbilitySummary ability;

  @override
  Widget build(BuildContext context) {
    final typeLabel = AbilityPresentation.typeLabel(
      abilityTypeSID: ability.abilityTypeSID,
      attackType: ability.attackType,
    );
    final helperLines = AbilityPresentation.helperLines(ability.rawJSON);
    final description = ability.description;
    final energyLevel = ability.energyLevel;
    final cooldown = ability.cooldown;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushAbilityDetail(context, ability.id),
      child: DetailCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: ability.isActive
                      ? AppTheme.accent.withValues(alpha: 0.5)
                      : AppTheme.cardBorder(context),
                ),
              ),
              child: LocalImage(ability.iconPath,
                  size: 48, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ability.name ?? 'Ability',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      MetadataBadge(
                          text: ability.isActive ? 'Active' : 'Passive',
                          emphasized: true),
                      if (typeLabel != null)
                        MetadataBadge(text: typeLabel, emphasized: true),
                      if (ability.rank != null)
                        MetadataBadge(
                            text: 'Tier ${ability.rank}', emphasized: true),
                      if (energyLevel != null && energyLevel >= 0)
                        MetadataBadge(
                            text: 'Cost $energyLevel', emphasized: true),
                      if (cooldown != null && cooldown > 0)
                        MetadataBadge(
                            text: 'Cooldown $cooldown', emphasized: true),
                    ],
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    HighlightedDescriptionText(description),
                  ],
                  for (final line in helperLines) ...[
                    const SizedBox(height: 4),
                    Text(
                      line,
                      style: TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
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
        const SectionHeader(title: 'Heroes starting with this Unit'),
        const SizedBox(height: 12),
        for (final hero in heroes) ...[
          HeroRow(hero: hero),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
