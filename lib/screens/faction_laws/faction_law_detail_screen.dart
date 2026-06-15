import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/faction_law.dart';
import '../../data/models/search.dart';
import '../../data/queries/faction_laws_queries.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';
import '../../widgets/stat_icons.dart';
import '../buildings/buildings_list_screen.dart' show BuildingMetadataBadge;

/// Port of FactionLawDetailView (FactionLawsView.swift).
class FactionLawDetailScreen extends StatefulWidget {
  const FactionLawDetailScreen({super.key, required this.lawID});

  final String lawID;

  @override
  State<FactionLawDetailScreen> createState() => _FactionLawDetailScreenState();
}

class _FactionLawDetailScreenState extends State<FactionLawDetailScreen> {
  FactionLawDetail? _law;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      _law = WikiDatabase.instance.fetchFactionLawDetail(widget.lawID);
    } catch (error) {
      debugPrint('Error loading faction law detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final law = _law;
    return AppScaffold(
      title: law?.name ?? 'Law',
      searchPriority: SearchEntityType.factionLaws,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomInset(extra: 32)),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : law == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(law: law),
                      const SizedBox(height: 20),
                      for (final level in law.levels) ...[
                        _LevelCard(level: level),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.law});

  final FactionLawDetail law;

  @override
  Widget build(BuildContext context) {
    final factionID = law.factionID;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
          ),
          child: LocalImage(law.iconPath,
              size: 120, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          law.name,
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
              BuildingMetadataBadge(
                text: AppTheme.factionDisplayName(factionID),
                color: AppTheme.factionColor(context, factionID),
                iconPath: AppTheme.factionIconPath(factionID),
              ),
            if (law.maxLevel != null)
              BuildingMetadataBadge(text: 'Max Level ${law.maxLevel}'),
          ],
        ),
      ],
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level});

  final FactionLawLevelDetail level;

  @override
  Widget build(BuildContext context) {
    final description = level.description;
    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Level ${level.level}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (level.cost != null)
                BuildingMetadataBadge(
                  text: '${level.cost}',
                  iconPath: StatIcons.lawPoints,
                ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            HighlightedDescriptionText(description, fontSize: 17),
          ],
        ],
      ),
    );
  }
}
