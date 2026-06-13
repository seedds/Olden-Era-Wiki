import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/building.dart';
import '../../data/models/search.dart';
import '../../data/queries/buildings_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/faction_filter.dart';
import '../../widgets/local_image.dart';

/// Port of BuildingsListView.swift.
class BuildingsListScreen extends StatefulWidget {
  const BuildingsListScreen({super.key});

  @override
  State<BuildingsListScreen> createState() => _BuildingsListScreenState();
}

class _BuildingsListScreenState extends State<BuildingsListScreen> {
  List<BuildingListItem> _buildings = [];
  List<String> _factions = [];
  String? _selectedFaction;

  @override
  void initState() {
    super.initState();
    try {
      _buildings = WikiDatabase.instance.listBuildings();
      _factions = {
        for (final building in _buildings)
          if (building.factionID != null) building.factionID!,
      }.toList()
        ..sort();
    } catch (error) {
      debugPrint('Error loading buildings: $error');
    }
  }

  List<BuildingListItem> get _filteredBuildings {
    final fid = _selectedFaction;
    if (fid == null) return _buildings;
    return _buildings.where((building) => building.factionID == fid).toList();
  }

  @override
  Widget build(BuildContext context) {
    final buildings = _filteredBuildings;
    return AppScaffold(
      title: 'Buildings',
      searchPriority: SearchEntityType.buildings,
      trailingExtras: [
        FactionFilterButton(
          factions: _factions,
          onSelect: (factionID) =>
              setState(() => _selectedFaction = factionID),
        ),
      ],
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: buildings.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _BuildingRow(building: buildings[index]),
        ),
      ),
    );
  }
}

/// Port of BuildingRowView (BuildingsListView.swift).
class _BuildingRow extends StatelessWidget {
  const _BuildingRow({required this.building});

  final BuildingListItem building;

  @override
  Widget build(BuildContext context) {
    final factionID = building.factionID;
    final groupName = building.groupName;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushBuildingDetail(context, building.entityID),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(building.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
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
                  const SizedBox(height: 6),
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
                      if (groupName != null && groupName.isNotEmpty)
                        BuildingMetadataBadge(
                            text: buildingGroupText(groupName)),
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

/// Port of BuildingMetadataBadge (BuildingsListView.swift): a caption badge
/// with an optional leading icon and a customizable tint color.
class BuildingMetadataBadge extends StatelessWidget {
  const BuildingMetadataBadge({
    super.key,
    required this.text,
    this.color = AppTheme.accent,
    this.iconPath,
  });

  final String text;
  final Color color;
  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconPath != null) ...[
            LocalImage(iconPath, size: 18),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of buildingGroupText (BuildingsListView.swift).
String buildingGroupText(String groupName) {
  return groupName
      .replaceAll('_', ' ')
      .split(' ')
      .map((word) =>
          word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
