import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/map_object.dart';
import '../../data/models/search.dart';
import '../../data/queries/map_objects_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';
import '../../widgets/stat_icons.dart';

/// Port of MapObjectDetailView.swift.
class MapObjectDetailScreen extends StatefulWidget {
  const MapObjectDetailScreen({super.key, required this.objectID});

  final String objectID;

  @override
  State<MapObjectDetailScreen> createState() => _MapObjectDetailScreenState();
}

class _MapObjectDetailScreenState extends State<MapObjectDetailScreen> {
  MapObjectDetail? _object;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      _object = WikiDatabase.instance.fetchMapObjectDetail(widget.objectID);
    } catch (error) {
      debugPrint('Error loading map object detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final object = _object;
    final bankInfo = object?.bankInfo;
    return AppScaffold(
      title: object?.name ?? 'Object',
      searchPriority: SearchEntityType.mapObjects,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomInset(extra: 32)),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : object == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(object: object),
                      const SizedBox(height: 20),
                      _InfoSection(object: object),
                      if (bankInfo != null &&
                          bankInfo.guardVariants.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _GuardsSection(bankInfo: bankInfo),
                      ],
                      if (object.rewardVariants.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _RewardsSection(object: object),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.object});

  final MapObjectDetail object;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
          ),
          child: LocalImage(object.iconPath,
              size: 120, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          object.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),
      ],
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.object});

  final MapObjectDetail object;

  @override
  Widget build(BuildContext context) {
    final description = object.description;
    final narrativeDescription = object.narrativeDescription;
    final hasDescription = description != null && description.isNotEmpty;
    final hasNarrative =
        narrativeDescription != null && narrativeDescription.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Object Info'),
        const SizedBox(height: 12),
        DetailCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDescription) HighlightedDescriptionText(description),
              if (hasNarrative) ...[
                if (hasDescription)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Container(
                        height: 1, color: AppTheme.cardBorder(context)),
                  ),
                Text(
                  narrativeDescription,
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
      ],
    );
  }
}

/// Difficulty scaling for bank guards (port of mapObjectDifficulties in
/// MapObjectDetailView.swift).
typedef _Difficulty = ({String id, String label, double power});

const List<_Difficulty> _difficulties = [
  (id: 'easy', label: 'Easy', power: 0.5),
  (id: 'normal', label: 'Normal', power: 0.75),
  (id: 'hard', label: 'Hard', power: 1.0),
  (id: 'impossible', label: 'Unfair', power: 1.0),
  (id: 'deadly', label: 'Impossible', power: 1.25),
  (id: 'hell', label: 'Apocalyptic', power: 1.5),
];

class _GuardsSection extends StatelessWidget {
  const _GuardsSection({required this.bankInfo});

  final MapObjectBankInfo bankInfo;

  int get _totalRollChance {
    var total = 0;
    for (final variant in bankInfo.guardVariants) {
      final chance = variant.rollChance ?? 0;
      total += chance > 0 ? chance : 0;
    }
    return total;
  }

  List<_Difficulty> get _displayDifficulties =>
      bankInfo.applyDifficultyModifier ? _difficulties : [_difficulties[2]];

  @override
  Widget build(BuildContext context) {
    final difficulties = _displayDifficulties;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Guards'),
        const SizedBox(height: 12),
        DetailCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < difficulties.length; i++) ...[
                if (i > 0)
                  Container(height: 1, color: AppTheme.cardBorder(context)),
                _DifficultyGuardRow(
                  difficulty: difficulties[i],
                  bankInfo: bankInfo,
                  totalRollChance: _totalRollChance,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DifficultyGuardRow extends StatelessWidget {
  const _DifficultyGuardRow({
    required this.difficulty,
    required this.bankInfo,
    required this.totalRollChance,
  });

  final _Difficulty difficulty;
  final MapObjectBankInfo bankInfo;
  final int totalRollChance;

  String? _chanceText(MapObjectGuardVariant variant) {
    final rollChance = variant.rollChance;
    if (rollChance == null) return null;
    final totalChance = totalRollChance > 1 ? totalRollChance : 1;
    final percentage = rollChance / totalChance * 100;
    return '${percentage.toStringAsFixed(1)}%';
  }

  int _scaledAmount(int amount) {
    final scaled = (amount * difficulty.power).toInt();
    return scaled > 1 ? scaled : 1;
  }

  @override
  Widget build(BuildContext context) {
    final variants = bankInfo.guardVariants;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            difficulty.label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < variants.length; i++) ...[
            if (_chanceText(variants[i]) case final chanceText?)
              if (totalRollChance > 0 && variants.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: MetadataBadge(text: chanceText, emphasized: true),
                ),
            for (final guardUnit in variants[i].guards)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => pushUnitDetail(context, guardUnit.unitID),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: Row(
                      children: [
                        LocalImage(guardUnit.unitIconPath, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            guardUnit.unitName,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppTheme.textSecondary(context),
                            ),
                          ),
                        ),
                        Text(
                          '${_scaledAmount(guardUnit.amount)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(CupertinoIcons.chevron_right,
                            size: 14,
                            color: AppTheme.textSecondary(context)),
                      ],
                    ),
                  ),
                ),
              ),
            if (i < variants.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child:
                    Container(height: 1, color: AppTheme.cardBorder(context)),
              ),
          ],
        ],
      ),
    );
  }
}

class _RewardsSection extends StatelessWidget {
  const _RewardsSection({required this.object});

  final MapObjectDetail object;

  int get _totalRollChance {
    var total = 0;
    for (final variant in object.rewardVariants) {
      final chance = variant.rollChance ?? 0;
      total += chance > 0 ? chance : 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final variants = object.rewardVariants;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Rewards'),
        const SizedBox(height: 12),
        DetailCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < variants.length; i++) ...[
                if (i > 0)
                  Container(height: 1, color: AppTheme.cardBorder(context)),
                _RewardVariantRow(
                  variant: variants[i],
                  totalRollChance: _totalRollChance,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RewardVariantRow extends StatelessWidget {
  const _RewardVariantRow({
    required this.variant,
    required this.totalRollChance,
  });

  final MapObjectRewardVariant variant;
  final int totalRollChance;

  String? get _chanceText {
    final rollChance = variant.rollChance;
    if (rollChance == null) return null;
    final totalChance = totalRollChance > 1 ? totalRollChance : 1;
    final percentage = rollChance / totalChance * 100;
    return '${percentage.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final chanceText = _chanceText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chanceText != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: MetadataBadge(text: chanceText, emphasized: true),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final reward in variant.resources) ...[
                    Text(
                      '${reward.amount}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    LocalImage(StatIcons.pathFor(reward.resourceKey),
                        size: 18),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
