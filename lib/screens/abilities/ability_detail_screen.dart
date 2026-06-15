import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/ability.dart';
import '../../data/models/search.dart';
import '../../data/queries/abilities_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/faction_label.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';

/// Port of AbilityDetailView.swift.
class AbilityDetailScreen extends StatefulWidget {
  const AbilityDetailScreen({super.key, required this.abilityID});

  final String abilityID;

  @override
  State<AbilityDetailScreen> createState() => _AbilityDetailScreenState();
}

class _AbilityDetailScreenState extends State<AbilityDetailScreen> {
  AbilityDetail? _ability;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      _ability = WikiDatabase.instance.fetchAbilityDetail(widget.abilityID);
    } catch (error) {
      debugPrint('Error loading ability detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final ability = _ability;
    return AppScaffold(
      title: ability?.name ?? 'Ability',
      searchPriority: SearchEntityType.abilities,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomInset(extra: 32)),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : ability == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(ability: ability),
                      const SizedBox(height: 20),
                      _VariantsSection(ability: ability),
                    ],
                  ),
      ),
    );
  }
}

/// Port of AbilityHeaderSection.
class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.ability});

  final AbilityDetail ability;

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
          child: LocalImage(ability.iconPath,
              size: 120, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          ability.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),
        if (ability.variants.length != 1) ...[
          const SizedBox(height: 16),
          Text(
            '${ability.variants.length} variants',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary(context),
            ),
          ),
        ],
      ],
    );
  }
}

/// Port of AbilityVariantsSection.
class _VariantsSection extends StatelessWidget {
  const _VariantsSection({required this.ability});

  final AbilityDetail ability;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < ability.variants.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _VariantCard(variant: ability.variants[i]),
        ],
      ],
    );
  }
}

/// Port of AbilityVariantCard.
class _VariantCard extends StatelessWidget {
  const _VariantCard({required this.variant});

  final AbilityVariantDetail variant;

  @override
  Widget build(BuildContext context) {
    final typeLabel = AbilityPresentation.typeLabel(
      abilityTypeSID: variant.abilityTypeSID,
      attackType: variant.attackType,
    );
    final helperLines = AbilityPresentation.helperLines(variant.rawJSON);
    final description = variant.description;
    final rank = variant.rank;
    final cost = variant.energyLevel;
    final cooldown = variant.cooldown;

    return DetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              MetadataBadge(
                  text: variant.isActive ? 'Active' : 'Passive',
                  emphasized: true),
              if (typeLabel != null)
                MetadataBadge(text: typeLabel, emphasized: true),
              if (rank != null)
                MetadataBadge(text: 'Tier $rank', emphasized: true),
              if (cost != null && cost >= 0)
                MetadataBadge(text: 'Cost $cost', emphasized: true),
              if (cooldown != null && cooldown > 0)
                MetadataBadge(text: 'Cooldown $cooldown', emphasized: true),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            HighlightedDescriptionText(description),
          ],
          for (final line in helperLines) ...[
            const SizedBox(height: 12),
            Text(
              line,
              style: TextStyle(
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: AppTheme.textSecondary(context),
              ),
            ),
          ],
          if (variant.creatures.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Creatures with this ability',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary(context),
              ),
            ),
          ],
          for (final creature in variant.creatures) ...[
            const SizedBox(height: 12),
            _CreatureRow(creature: creature),
          ],
        ],
      ),
    );
  }
}

/// Port of the creature row inside AbilityVariantCard.
class _CreatureRow extends StatelessWidget {
  const _CreatureRow({required this.creature});

  final AbilityCreatureSummary creature;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushUnitDetail(context, creature.unitID),
      child: Container(
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
              child: LocalImage(creature.unitIconPath,
                  size: 44, borderRadius: BorderRadius.circular(8)),
            ),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (creature.unitFactionID != null) ...[
                        DefaultTextStyle(
                          style: const TextStyle(fontSize: 12),
                          child: FactionLabel(
                              factionID: creature.unitFactionID,
                              iconSize: 14),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (creature.unitTier != null)
                        Text(
                          'Tier ${creature.unitTier}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                          ),
                        ),
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
