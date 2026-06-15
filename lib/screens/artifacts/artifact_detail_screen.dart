import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/artifact.dart';
import '../../data/models/search.dart';
import '../../data/queries/artifacts_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';
import '../../widgets/stat_icons.dart';

/// Port of ArtifactDetailView.swift.
class ArtifactDetailScreen extends StatefulWidget {
  const ArtifactDetailScreen({super.key, required this.artifactID});

  final String artifactID;

  @override
  State<ArtifactDetailScreen> createState() => _ArtifactDetailScreenState();
}

class _ArtifactDetailScreenState extends State<ArtifactDetailScreen> {
  ArtifactDetail? _artifact;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      _artifact = WikiDatabase.instance.fetchArtifactDetail(widget.artifactID);
    } catch (error) {
      debugPrint('Error loading artifact detail: $error');
    }
    _isLoading = false;
  }

  /// Port of upgradeCost(for:artifact:) in ArtifactDetailView.swift.
  int? _upgradeCost(ArtifactLevelDetail level, ArtifactDetail artifact) {
    final costBase = artifact.costBase;
    final costPerLevel = artifact.costPerLevel;
    if (level.level <= 1 || costBase == null || costPerLevel == null) {
      return null;
    }
    return costBase + costPerLevel * (level.level - 1);
  }

  @override
  Widget build(BuildContext context) {
    final artifact = _artifact;
    return AppScaffold(
      title: artifact?.name ?? 'Artifact',
      searchPriority: SearchEntityType.artifacts,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomInset(extra: 32)),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : artifact == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(artifact: artifact),
                      for (final level in artifact.levels) ...[
                        const SizedBox(height: 20),
                        _LevelSection(
                          level: level,
                          upgradeCost: _upgradeCost(level, artifact),
                        ),
                      ],
                      if (artifact.itemSet != null) ...[
                        const SizedBox(height: 20),
                        _ItemSetSection(
                          itemSet: artifact.itemSet!,
                          currentArtifactID: artifact.id,
                        ),
                      ],
                    ],
                  ),
      ),
    );
  }
}

bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

String _capitalizedWords(String value) => value
    .split(' ')
    .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
    .join(' ');

/// Port of ArtifactHeaderSection (ArtifactDetailView.swift).
class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.artifact});

  final ArtifactDetail artifact;

  @override
  Widget build(BuildContext context) {
    final rarity = artifact.rarity;
    final slot = artifact.slot;
    final lore = artifact.narrativeDescription;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
          ),
          child: LocalImage(artifact.iconPath,
              size: 120, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          artifact.name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.artifactRarityColor(artifact.rarity),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (rarity != null && rarity.isNotEmpty)
              MetadataBadge(text: _capitalizedWords(rarity), emphasized: true),
            if (slot != null && slot.isNotEmpty)
              MetadataBadge(
                  text: _capitalizedWords(slot.replaceAll('_', ' ')),
                  emphasized: true),
            MetadataBadge(text: 'Lv ${artifact.maxLevel}', emphasized: true),
          ],
        ),
        if (lore != null && lore.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            lore,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Port of ArtifactLevelSection (ArtifactDetailView.swift).
class _LevelSection extends StatelessWidget {
  const _LevelSection({required this.level, required this.upgradeCost});

  final ArtifactLevelDetail level;
  final int? upgradeCost;

  @override
  Widget build(BuildContext context) {
    final description = level.description;
    final upgradeCost = this.upgradeCost;
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
              if (description != null && description.isNotEmpty)
                HighlightedDescriptionText(description, fontSize: 17),
              if (upgradeCost != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Container(
                      height: 1, color: AppTheme.cardBorder(context)),
                ),
                Row(
                  children: [
                    Text(
                      'Upgrade Cost: $upgradeCost',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    LocalImage(StatIcons.dust, size: 16),
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

/// Port of ArtifactItemSetSection (ArtifactDetailView.swift).
class _ItemSetSection extends StatelessWidget {
  const _ItemSetSection({
    required this.itemSet,
    required this.currentArtifactID,
  });

  final ArtifactSetDetail itemSet;
  final String currentArtifactID;

  String _bonusTitle(ArtifactSetBonus bonus) {
    final requiredItemsAmount = bonus.requiredItemsAmount;
    if (requiredItemsAmount != null) return '$requiredItemsAmount Piece Bonus';
    return 'Set Bonus';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Item Set'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itemSet.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
              for (final bonus in itemSet.bonuses) ...[
                const SizedBox(height: 10),
                _SetBonusCard(title: _bonusTitle(bonus), bonus: bonus),
              ],
              if (itemSet.members.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Artifacts in Set',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                for (final member in itemSet.members) ...[
                  const SizedBox(height: 10),
                  _SetMemberRow(
                    member: member,
                    isCurrent: member.id == currentArtifactID,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SetBonusCard extends StatelessWidget {
  const _SetBonusCard({required this.title, required this.bonus});

  final String title;
  final ArtifactSetBonus bonus;

  @override
  Widget build(BuildContext context) {
    final description = bonus.description;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBorder(context).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.accent,
            ),
          ),
          if (_hasText(description)) ...[
            const SizedBox(height: 4),
            HighlightedDescriptionText(description!),
          ],
        ],
      ),
    );
  }
}

class _SetMemberRow extends StatelessWidget {
  const _SetMemberRow({required this.member, required this.isCurrent});

  final ArtifactSetMember member;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushArtifactDetail(context, member.id),
      child: Container(
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
              child: LocalImage(member.iconPath,
                  size: 44, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                member.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.artifactRarityColor(member.rarity),
                ),
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              const MetadataBadge(text: 'Current', emphasized: true),
            ],
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }
}
