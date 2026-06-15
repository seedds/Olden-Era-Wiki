import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/search.dart';
import '../../data/models/skill.dart';
import '../../data/queries/skills_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/local_image.dart';

/// Port of SkillsListView.swift.
class SkillsListScreen extends StatefulWidget {
  const SkillsListScreen({super.key});

  @override
  State<SkillsListScreen> createState() => _SkillsListScreenState();
}

class _SkillsListScreenState extends State<SkillsListScreen> {
  List<SkillListItem> _skills = [];

  @override
  void initState() {
    super.initState();
    try {
      _skills = WikiDatabase.instance.listSkills();
    } catch (error) {
      debugPrint('Error loading skills: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Skills',
      searchPriority: SearchEntityType.skills,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, context.scrollBottomInset(extra: 24)),
        itemCount: _skills.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _SkillRow(skill: _skills[index]),
        ),
      ),
    );
  }
}

/// Port of SkillRowView (SkillsListView.swift).
class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill});

  final SkillListItem skill;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushSkillDetail(context, skill.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(skill.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                skill.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
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
