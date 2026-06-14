import 'package:flutter/cupertino.dart';

import '../data/models/search.dart';
import '../routes.dart';
import '../theme/app_theme.dart';
import '../widgets/faction_label.dart';
import '../widgets/local_image.dart';
import 'search_state.dart';

/// Full-screen scrollable card that hosts [GlobalSearchResultsView], rendered
/// by [AppScaffold] above each screen's content (below the nav bar).
class SearchOverlay extends StatelessWidget {
  const SearchOverlay({
    super.key,
    required this.results,
    required this.prioritizedEntityType,
  });

  final List<GlobalSearchResult> results;
  final SearchEntityType? prioritizedEntityType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppTheme.background(context).withValues(alpha: 0.97),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.paddingOf(context).bottom,
        ),
        child: results.isEmpty
            ? const SizedBox.shrink()
            : GlobalSearchResultsView(
                results: results,
                prioritizedEntityType: prioritizedEntityType,
              ),
      ),
    );
  }
}

/// Port of GlobalSearchResultsView (HomeView.swift) without the purchase
/// gating — every result is a plain navigation row.
class GlobalSearchResultsView extends StatelessWidget {
  const GlobalSearchResultsView({
    super.key,
    required this.results,
    required this.prioritizedEntityType,
  });

  final List<GlobalSearchResult> results;
  final SearchEntityType? prioritizedEntityType;

  List<SearchEntityType> get _orderedEntityTypes {
    final prioritized = prioritizedEntityType;
    if (prioritized == null) return SearchEntityType.values;
    return [
      prioritized,
      ...SearchEntityType.values.where((type) => type != prioritized),
    ];
  }

  List<(SearchEntityType, List<GlobalSearchResult>)> get _groupedResults {
    final groups = <(SearchEntityType, List<GlobalSearchResult>)>[];
    for (final type in _orderedEntityTypes) {
      final matches =
          results.where((result) => result.entityType == type).toList();
      if (matches.isNotEmpty) {
        groups.add((type, matches));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    // The overlay is only presented when results exist (SearchState
    // .isShowingResults); this is just a defensive fallback.
    if (results.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (entityType, entityResults) in _groupedResults) ...[
          Row(
            children: [
              Icon(entityType.icon,
                  size: 18, color: AppTheme.textPrimary(context)),
              const SizedBox(width: 6),
              Text(
                entityType.title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final result in entityResults) ...[
            _SearchResultRow(result: result),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result});

  final GlobalSearchResult result;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        SearchScope.of(context).onResultSelected();
        pushSearchResult(context, result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            if (result.iconPath != null)
              LocalImage(
                result.iconPath,
                size: 44,
                borderRadius: BorderRadius.circular(8),
              )
            else
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.background(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(result.entityType.icon,
                    size: 20, color: AppTheme.accent),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary(context),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: _secondaryLabel(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right,
                size: 14, color: AppTheme.textSecondary(context)),
          ],
        ),
      ),
    );
  }

  Widget _secondaryLabel(BuildContext context) {
    final factionID = result.factionID;
    if (factionID != null && factionID.isNotEmpty) {
      return FactionLabel(factionID: factionID, iconSize: 14);
    }
    final subtitle = result.subtitle;
    if (subtitle != null && subtitle.isNotEmpty) {
      return Text(subtitle);
    }
    return Text(result.entityType.title);
  }
}
