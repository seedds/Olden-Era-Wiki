import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/artifact.dart';
import '../../data/models/search.dart';
import '../../data/queries/artifacts_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/local_image.dart';

/// Port of ArtifactsListView.swift.
class ArtifactsListScreen extends StatefulWidget {
  const ArtifactsListScreen({super.key});

  @override
  State<ArtifactsListScreen> createState() => _ArtifactsListScreenState();
}

class _ArtifactsListScreenState extends State<ArtifactsListScreen> {
  List<ArtifactListItem> _artifacts = [];
  List<String> _rarities = [];
  String? _selectedRarity;

  @override
  void initState() {
    super.initState();
    try {
      _artifacts = WikiDatabase.instance.listArtifacts();
      _rarities = _artifacts
          .map((artifact) => artifact.rarity)
          .whereType<String>()
          .where((rarity) => rarity.isNotEmpty)
          .toSet()
          .toList()
        ..sort((lhs, rhs) =>
            _artifactRarityRank(lhs).compareTo(_artifactRarityRank(rhs)));
    } catch (error) {
      debugPrint('Error loading artifacts: $error');
    }
  }

  List<ArtifactListItem> get _filteredArtifacts {
    final rarity = _selectedRarity;
    if (rarity == null) return _artifacts;
    return _artifacts.where((artifact) => artifact.rarity == rarity).toList();
  }

  @override
  Widget build(BuildContext context) {
    final artifacts = _filteredArtifacts;
    return AppScaffold(
      title: 'Artifacts',
      searchPriority: SearchEntityType.artifacts,
      trailingExtras: [
        _RarityFilterButton(
          rarities: _rarities,
          onSelect: (rarity) => setState(() => _selectedRarity = rarity),
        ),
      ],
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, context.scrollBottomInset(extra: 24)),
        itemCount: artifacts.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _ArtifactRow(artifact: artifacts[index]),
        ),
      ),
    );
  }
}

/// Port of artifactRarityRank (ArtifactsListView.swift).
int _artifactRarityRank(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'common':
      return 0;
    case 'uncommon':
      return 1;
    case 'rare':
      return 2;
    case 'epic':
      return 3;
    case 'legendary':
      return 4;
    case 'mythic':
      return 5;
    default:
      return 1 << 62;
  }
}

String _capitalizedWords(String value) => value
    .split(' ')
    .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
    .join(' ');

/// Port of ArtifactRarityFilterToolbar (ArtifactsListView.swift).
class _RarityFilterButton extends StatelessWidget {
  const _RarityFilterButton({required this.rarities, required this.onSelect});

  final List<String> rarities;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showPicker(context),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Icon(
          CupertinoIcons.line_horizontal_3_decrease_circle,
          size: 22,
          color: AppTheme.accent,
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (popupContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(popupContext).pop();
              onSelect(null);
            },
            child: const Text('All Rarities'),
          ),
          for (final rarity in rarities)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                onSelect(rarity);
              },
              child: Text(_capitalizedWords(rarity)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}

/// Port of ArtifactRowView (ArtifactsListView.swift).
class _ArtifactRow extends StatelessWidget {
  const _ArtifactRow({required this.artifact});

  final ArtifactListItem artifact;

  @override
  Widget build(BuildContext context) {
    final rarity = artifact.rarity;
    final slot = artifact.slot;
    final maxLevel = artifact.maxLevel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushArtifactDetail(context, artifact.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(artifact.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artifact.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.artifactRarityColor(artifact.rarity),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (rarity != null && rarity.isNotEmpty)
                        MetadataBadge(
                            text: _capitalizedWords(rarity), emphasized: true),
                      if (slot != null && slot.isNotEmpty)
                        MetadataBadge(
                            text:
                                _capitalizedWords(slot.replaceAll('_', ' ')),
                            emphasized: true),
                      if (maxLevel != null && maxLevel > 1)
                        MetadataBadge(text: 'Lv $maxLevel', emphasized: true),
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
