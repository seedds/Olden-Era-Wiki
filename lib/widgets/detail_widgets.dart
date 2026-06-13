import 'package:flutter/cupertino.dart';

import '../data/models/unit.dart';
import '../theme/app_theme.dart';
import 'local_image.dart';
import 'stat_icons.dart';

/// Port of SectionHeader (UnitDetailView.swift).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary(context),
      ),
    );
  }
}

/// A rounded card container matching the Swift detail-card styling.
class DetailCard extends StatelessWidget {
  const DetailCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder(context)),
      ),
      child: child,
    );
  }
}

/// Port of FullWidthStatRow (UnitDetailView.swift).
class FullWidthStatRow extends StatelessWidget {
  const FullWidthStatRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
  });

  final String? icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          LocalImage(icon, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary(context),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.statValue(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Port of CostSummaryRow (UnitDetailView.swift).
class CostSummaryRow extends StatelessWidget {
  const CostSummaryRow({super.key, required this.label, required this.items});

  final String label;
  final List<UnitCostItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          LocalImage(StatIcons.gold, size: 22),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary(context),
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 14,
            children: [
              for (final item in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.cost}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    LocalImage(
                      StatIcons.pathFor(item.name.toLowerCase()),
                      size: 20,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Port of AbilityMetadataBadge.
class MetadataBadge extends StatelessWidget {
  const MetadataBadge({super.key, required this.text, this.emphasized = false});

  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: emphasized ? FontWeight.w600 : FontWeight.normal,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}

/// Small badge used in headers (faction / tier pills).
class HeaderPill extends StatelessWidget {
  const HeaderPill({
    super.key,
    required this.color,
    required this.child,
  });

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        child: child,
      ),
    );
  }
}

/// Centered loading spinner used while a detail screen loads.
class DetailLoadingIndicator extends StatelessWidget {
  const DetailLoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 100),
      child: Center(child: CupertinoActivityIndicator(radius: 14)),
    );
  }
}
