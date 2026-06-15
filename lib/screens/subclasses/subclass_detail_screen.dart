import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/search.dart';
import '../../data/models/subclass.dart';
import '../../data/queries/subclasses_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/detail_widgets.dart';
import '../../widgets/faction_label.dart';
import '../../widgets/highlighted_text.dart';
import '../../widgets/local_image.dart';
import '../heroes/heroes_list_screen.dart' show classDisplayName;

/// Port of SubclassDetailView.swift.
class SubclassDetailScreen extends StatefulWidget {
  const SubclassDetailScreen({super.key, required this.subclassID});

  final String subclassID;

  @override
  State<SubclassDetailScreen> createState() => _SubclassDetailScreenState();
}

class _SubclassDetailScreenState extends State<SubclassDetailScreen> {
  SubclassDetail? _subclass;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    try {
      _subclass = WikiDatabase.instance.fetchSubclassDetail(widget.subclassID);
    } catch (error) {
      debugPrint('Error loading subclass detail: $error');
    }
    _isLoading = false;
  }

  @override
  Widget build(BuildContext context) {
    final subclass = _subclass;
    final description = subclass?.description;
    return AppScaffold(
      title: subclass?.name ?? 'Subclass',
      searchPriority: SearchEntityType.subclasses,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.scrollBottomInset(extra: 32)),
        child: _isLoading
            ? const DetailLoadingIndicator()
            : subclass == null
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      _HeaderSection(subclass: subclass),
                      if (description != null &&
                          description.trim().isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _DescriptionSection(description: description),
                      ],
                      if (subclass.requiredSkills.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        _RequiredSkillsSection(
                            skills: subclass.requiredSkills),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.subclass});

  final SubclassDetail subclass;

  @override
  Widget build(BuildContext context) {
    final classType = subclass.classType;
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.2),
                blurRadius: 12,
              ),
            ],
          ),
          child: LocalImage(subclass.iconPath,
              size: 140, borderRadius: BorderRadius.circular(16)),
        ),
        const SizedBox(height: 16),
        Text(
          subclass.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DefaultTextStyle(
              style: const TextStyle(fontSize: 15),
              child: FactionLabel(factionID: subclass.factionID),
            ),
            if (classType != null)
              MetadataBadge(
                  text: classDisplayName(classType), emphasized: true),
          ],
        ),
      ],
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  const _DescriptionSection({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Description'),
        const SizedBox(height: 12),
        DetailCard(
          child: HighlightedDescriptionText(description),
        ),
      ],
    );
  }
}

class _RequiredSkillsSection extends StatelessWidget {
  const _RequiredSkillsSection({required this.skills});

  final List<SubclassRequiredSkill> skills;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Required Skills'),
        const SizedBox(height: 12),
        for (final skill in skills) ...[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => pushSkillDetail(context, skill.skillID),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                      border:
                          Border.all(color: AppTheme.cardBorder(context)),
                    ),
                    child: LocalImage(skill.iconPath,
                        size: 40, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      skill.skillName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                  ),
                  Text(
                    'Level ${skill.skillLevel}',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.accent),
                  ),
                  const SizedBox(width: 8),
                  Icon(CupertinoIcons.chevron_right,
                      size: 14, color: AppTheme.textSecondary(context)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
