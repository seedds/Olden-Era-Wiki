import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/search.dart';
import '../../data/models/spell.dart';
import '../../data/queries/spells_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/local_image.dart';

/// Port of SpellsListView.swift.
class SpellsListScreen extends StatefulWidget {
  const SpellsListScreen({super.key});

  @override
  State<SpellsListScreen> createState() => _SpellsListScreenState();
}

class _SpellsListScreenState extends State<SpellsListScreen> {
  List<SpellListItem> _spells = [];
  List<String> _schools = [];
  String? _selectedSchool;

  @override
  void initState() {
    super.initState();
    try {
      _spells = WikiDatabase.instance.listSpells();
      _schools = _spells
          .map((spell) => spell.school)
          .whereType<String>()
          .where((school) => school.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    } catch (error) {
      debugPrint('Error loading spells: $error');
    }
  }

  List<SpellListItem> get _filteredSpells {
    final school = _selectedSchool;
    if (school == null) return _spells;
    return _spells.where((spell) => spell.school == school).toList();
  }

  @override
  Widget build(BuildContext context) {
    final spells = _filteredSpells;
    return AppScaffold(
      title: 'Spells',
      searchPriority: SearchEntityType.spells,
      trailingExtras: [
        _SchoolFilterButton(
          schools: _schools,
          onSelect: (school) => setState(() => _selectedSchool = school),
        ),
      ],
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: spells.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _SpellRow(spell: spells[index]),
        ),
      ),
    );
  }
}

String _capitalized(String value) =>
    value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

/// Port of SpellFilterToolbar (SpellsListView.swift).
class _SchoolFilterButton extends StatelessWidget {
  const _SchoolFilterButton({required this.schools, required this.onSelect});

  final List<String> schools;
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
            child: const Text('All Schools'),
          ),
          for (final school in schools)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                onSelect(school);
              },
              child: Text(_capitalized(school)),
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

/// Port of SpellRowView (SpellsListView.swift).
class _SpellRow extends StatelessWidget {
  const _SpellRow({required this.spell});

  final SpellListItem spell;

  @override
  Widget build(BuildContext context) {
    final school = spell.school;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushSpellDetail(context, spell.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(spell.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spell.name,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (school != null && school.isNotEmpty)
                        MetadataBadge(
                            text: _capitalized(school), emphasized: true),
                      if (spell.rank != null)
                        MetadataBadge(
                            text: 'Rank ${spell.rank}', emphasized: true),
                      MetadataBadge(
                          text: spell.usedOnMap ? 'World' : 'Battle',
                          emphasized: true),
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
