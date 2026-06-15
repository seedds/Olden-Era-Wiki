import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/faction_law.dart';
import '../../data/models/search.dart';
import '../../data/queries/faction_laws_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/local_image.dart';
import '../buildings/buildings_list_screen.dart';

/// Port of FactionLawsListView (FactionLawsView.swift).
class FactionLawsListScreen extends StatefulWidget {
  const FactionLawsListScreen({super.key});

  @override
  State<FactionLawsListScreen> createState() => _FactionLawsListScreenState();
}

class _FactionLawsListScreenState extends State<FactionLawsListScreen> {
  List<FactionLawListItem> _laws = [];

  @override
  void initState() {
    super.initState();
    try {
      _laws = WikiDatabase.instance.listFactionLaws();
    } catch (error) {
      debugPrint('Error loading faction laws: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Laws',
      searchPriority: SearchEntityType.factionLaws,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, context.scrollBottomInset(extra: 24)),
        itemCount: _laws.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _FactionLawRow(law: _laws[index]),
        ),
      ),
    );
  }
}

/// Port of FactionLawRowView (FactionLawsView.swift).
class _FactionLawRow extends StatelessWidget {
  const _FactionLawRow({required this.law});

  final FactionLawListItem law;

  @override
  Widget build(BuildContext context) {
    final factionID = law.factionID;
    final maxLevel = law.maxLevel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushFactionLawDetail(context, law.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(law.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    law.name,
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
                      if (maxLevel != null)
                        BuildingMetadataBadge(text: 'Max Lv $maxLevel'),
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
