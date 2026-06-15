import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/building.dart';
import '../../data/models/search.dart';
import '../../data/queries/buildings_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';
import '../../widgets/stat_icons.dart';
import 'buildings_list_screen.dart';

/// Port of BuildingDetailView.swift.
class BuildingDetailScreen extends StatefulWidget {
  const BuildingDetailScreen({super.key, required this.entityID});

  final String entityID;

  @override
  State<BuildingDetailScreen> createState() => _BuildingDetailScreenState();
}

class _BuildingDetailScreenState extends State<BuildingDetailScreen> {
  BuildingDetail? _building;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      _building = WikiDatabase.instance.fetchBuildingDetail(widget.entityID);
    } catch (error) {
      debugPrint('Error loading building detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final building = _building;
    return AppScaffold(
      title: building?.name ?? 'Building',
      searchPriority: SearchEntityType.buildings,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomInset(extra: 32)),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : building == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(building: building),
                      const SizedBox(height: 20),
                      _InfoSection(building: building),
                      if (building.recruitCreatures.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _RecruitCreaturesSection(
                            creatures: building.recruitCreatures),
                      ],
                      if (building.requiredBuildings.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _BuildingLinksSection(
                          title: 'Required Buildings',
                          buildings: building.requiredBuildings,
                        ),
                      ],
                      if (building.unlockedBuildings.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _BuildingLinksSection(
                          title: 'Unlocked Buildings',
                          buildings: building.unlockedBuildings,
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

/// Port of BuildingHeaderSection (BuildingDetailView.swift).
class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.building});

  final BuildingDetail building;

  @override
  Widget build(BuildContext context) {
    final factionID = building.factionID;
    final groupName = building.groupName;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
          ),
          child: LocalImage(building.iconPath,
              size: 120, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          building.name,
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
            if (factionID != null)
              BuildingMetadataBadge(
                text: AppTheme.factionDisplayName(factionID),
                color: AppTheme.factionColor(context, factionID),
                iconPath: AppTheme.factionIconPath(factionID),
              ),
            BuildingMetadataBadge(text: 'Level ${building.level}'),
            if (groupName != null && groupName.isNotEmpty)
              BuildingMetadataBadge(text: buildingGroupText(groupName)),
          ],
        ),
      ],
    );
  }
}

/// Port of BuildingInfoSection (BuildingDetailView.swift).
class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.building});

  final BuildingDetail building;

  bool get _hasDescription {
    final description = building.description;
    return description != null && description.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final description = building.description;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Building Info'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description != null && description.isNotEmpty)
                HighlightedDescriptionText(description),
              if (_hasDescription && building.costs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                      height: 1, color: AppTheme.cardBorder(context)),
                ),
              if (building.costs.isNotEmpty)
                _BuildingCostRow(label: 'Cost', items: building.costs),
            ],
          ),
        ),
      ],
    );
  }
}

/// Port of BuildingCostRow (BuildingDetailView.swift).
class _BuildingCostRow extends StatelessWidget {
  const _BuildingCostRow({required this.label, required this.items});

  final String label;
  final List<BuildingCostItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          LocalImage(StatIcons.gold, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 14,
            children: [
              for (final item in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.cost}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    LocalImage(
                      StatIcons.pathFor(item.name.toLowerCase()),
                      size: 20,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Port of BuildingRecruitCreaturesSection (BuildingDetailView.swift).
class _RecruitCreaturesSection extends StatelessWidget {
  const _RecruitCreaturesSection({required this.creatures});

  final List<BuildingRecruitCreature> creatures;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Recruit Creatures'),
        const SizedBox(height: 12),
        for (final creature in creatures) ...[
          _CreatureRow(creature: creature),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Port of BuildingCreatureRow (BuildingDetailView.swift).
class _CreatureRow extends StatelessWidget {
  const _CreatureRow({required this.creature});

  final BuildingRecruitCreature creature;

  @override
  Widget build(BuildContext context) {
    final unitID = creature.unitID;
    final factionID = creature.unitFactionID;
    final tier = creature.unitTier;
    final weeklyGrowth = creature.weeklyGrowth;

    final row = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        children: [
          LocalImage(creature.unitIconPath,
              size: 46, borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  creature.unitName,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (factionID != null)
                      BuildingMetadataBadge(
                        text: AppTheme.factionDisplayName(factionID),
                        color: AppTheme.factionColor(context, factionID),
                        iconPath: AppTheme.factionIconPath(factionID),
                      ),
                    if (tier != null) BuildingMetadataBadge(text: 'Tier $tier'),
                    if (weeklyGrowth != null)
                      BuildingMetadataBadge(text: '+$weeklyGrowth / week'),
                  ],
                ),
              ],
            ),
          ),
          if (unitID != null)
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
        ],
      ),
    );

    if (unitID == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushUnitDetail(context, unitID),
      child: row,
    );
  }
}

/// Port of BuildingLinksSection (BuildingDetailView.swift).
class _BuildingLinksSection extends StatelessWidget {
  const _BuildingLinksSection({required this.title, required this.buildings});

  final String title;
  final List<BuildingLinkItem> buildings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        const SizedBox(height: 12),
        for (final building in buildings) ...[
          _BuildingLinkRow(building: building),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// Port of BuildingLinkRow (BuildingDetailView.swift).
class _BuildingLinkRow extends StatelessWidget {
  const _BuildingLinkRow({required this.building});

  final BuildingLinkItem building;

  @override
  Widget build(BuildContext context) {
    final entityID = building.entityID;
    final factionID = building.factionID;
    final level = building.level;
    final groupName = building.groupName;

    final row = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Row(
        children: [
          LocalImage(building.iconPath,
              size: 44, borderRadius: BorderRadius.circular(8)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  building.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (factionID != null)
                      BuildingMetadataBadge(
                        text: AppTheme.factionDisplayName(factionID),
                        color: AppTheme.factionColor(context, factionID),
                        iconPath: AppTheme.factionIconPath(factionID),
                      ),
                    if (level != null) BuildingMetadataBadge(text: 'Lv $level'),
                    if (groupName != null && groupName.isNotEmpty)
                      BuildingMetadataBadge(text: buildingGroupText(groupName)),
                  ],
                ),
              ],
            ),
          ),
          if (entityID != null)
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
        ],
      ),
    );

    if (entityID == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushBuildingDetail(context, entityID),
      child: row,
    );
  }
}
