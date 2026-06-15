import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/ability.dart';
import '../../data/models/search.dart';
import '../../data/queries/abilities_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/local_image.dart';

/// Port of AbilitiesListView.swift.
class AbilitiesListScreen extends StatefulWidget {
  const AbilitiesListScreen({super.key});

  @override
  State<AbilitiesListScreen> createState() => _AbilitiesListScreenState();
}

class _AbilitiesListScreenState extends State<AbilitiesListScreen> {
  List<AbilityListItem> _abilities = [];

  @override
  void initState() {
    super.initState();
    try {
      _abilities = WikiDatabase.instance.listAbilities();
    } catch (error) {
      debugPrint('Error loading abilities: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Abilities',
      searchPriority: SearchEntityType.abilities,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, context.scrollBottomInset(extra: 24)),
        itemCount: _abilities.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _AbilityRow(ability: _abilities[index]),
        ),
      ),
    );
  }
}

/// Port of AbilityRowView (AbilitiesListView.swift).
class _AbilityRow extends StatelessWidget {
  const _AbilityRow({required this.ability});

  final AbilityListItem ability;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushAbilityDetail(context, ability.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder(context)),
              ),
              child: LocalImage(ability.iconPath,
                  size: 52, borderRadius: BorderRadius.circular(8)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ability.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  if (ability.variantCount != 1) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${ability.variantCount} variants',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary(context),
                      ),
                    ),
                  ],
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
