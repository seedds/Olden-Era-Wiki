import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/search.dart';
import '../../data/models/subclass.dart';
import '../../data/queries/subclasses_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/faction_filter.dart';
import '../../widgets/faction_label.dart';
import '../../widgets/local_image.dart';
import '../heroes/heroes_list_screen.dart' show classDisplayName;

/// Port of SubclassesListView.swift.
class SubclassesListScreen extends StatefulWidget {
  const SubclassesListScreen({super.key});

  @override
  State<SubclassesListScreen> createState() => _SubclassesListScreenState();
}

class _SubclassesListScreenState extends State<SubclassesListScreen> {
  List<SubclassListItem> _subclasses = [];
  List<String> _factions = [];
  String? _selectedFaction;

  @override
  void initState() {
    super.initState();
    try {
      _subclasses = WikiDatabase.instance.listSubclasses();
      _factions = {
        for (final subclass in _subclasses)
          if (subclass.factionID case final factionID?) factionID,
      }.toList()
        ..sort();
    } catch (error) {
      debugPrint('Error loading subclasses: $error');
    }
  }

  List<SubclassListItem> get _filteredSubclasses {
    final selected = _selectedFaction;
    if (selected == null) return _subclasses;
    return [
      for (final subclass in _subclasses)
        if (subclass.factionID == selected) subclass,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final subclasses = _filteredSubclasses;
    return AppScaffold(
      title: 'Subclasses',
      searchPriority: SearchEntityType.subclasses,
      trailingExtras: [
        FactionFilterButton(
          factions: _factions,
          onSelect: (factionID) =>
              setState(() => _selectedFaction = factionID),
        ),
      ],
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, context.scrollBottomInset(extra: 24)),
        itemCount: subclasses.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SubclassRow(subclass: subclasses[index]),
        ),
      ),
    );
  }
}

class _SubclassRow extends StatelessWidget {
  const _SubclassRow({required this.subclass});

  final SubclassListItem subclass;

  @override
  Widget build(BuildContext context) {
    final classType = subclass.classType;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushSubclassDetail(context, subclass.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(subclass.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subclass.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      DefaultTextStyle(
                        style: const TextStyle(fontSize: 12),
                        child: FactionLabel(
                            factionID: subclass.factionID, iconSize: 14),
                      ),
                      if (classType != null) ...[
                        const SizedBox(width: 8),
                        MetadataBadge(
                            text: classDisplayName(classType),
                            emphasized: true),
                      ],
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
