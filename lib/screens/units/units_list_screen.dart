import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/search.dart';
import '../../data/models/unit.dart';
import '../../data/queries/units_queries.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/faction_filter.dart';
import '../../widgets/unit_row.dart';

/// Port of UnitsListView.swift.
class UnitsListScreen extends StatefulWidget {
  const UnitsListScreen({super.key});

  @override
  State<UnitsListScreen> createState() => _UnitsListScreenState();
}

class _UnitsListScreenState extends State<UnitsListScreen> {
  List<UnitListItem> _units = [];
  List<String> _factions = [];
  String? _selectedFaction;

  @override
  void initState() {
    super.initState();
    try {
      _units = WikiDatabase.instance.listUnits();
      _factions = WikiDatabase.instance.fetchFactions();
    } catch (error) {
      debugPrint('Error loading units: $error');
    }
  }

  List<UnitListItem> get _filteredUnits {
    var result = _units;
    final fid = _selectedFaction;
    if (fid != null) {
      result = result.where((unit) => unit.factionID == fid).toList();
    } else {
      result = List.of(result);
    }
    result.sort(compareUnits);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final units = _filteredUnits;
    return AppScaffold(
      title: 'Units',
      searchPriority: SearchEntityType.units,
      trailingExtras: [
        FactionFilterButton(
          factions: _factions,
          onSelect: (factionID) =>
              setState(() => _selectedFaction = factionID),
        ),
      ],
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: units.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: UnitRow(unit: units[index]),
        ),
      ),
    );
  }
}

/// Port of compareUnits / baseUnitID / unitVariantRank (UnitsListView.swift):
/// tier → faction → base unit id → variant rank (base, _upg, _upg_alt) →
/// name → id.
int compareUnits(UnitListItem lhs, UnitListItem rhs) {
  final lhsTier = lhs.tier ?? 1 << 62;
  final rhsTier = rhs.tier ?? 1 << 62;
  if (lhsTier != rhsTier) return lhsTier.compareTo(rhsTier);

  final lhsFaction = lhs.factionID ?? '';
  final rhsFaction = rhs.factionID ?? '';
  if (lhsFaction != rhsFaction) return lhsFaction.compareTo(rhsFaction);

  final lhsBaseID = baseUnitID(lhs.id);
  final rhsBaseID = baseUnitID(rhs.id);
  if (lhsBaseID != rhsBaseID) return lhsBaseID.compareTo(rhsBaseID);

  final lhsVariantRank = unitVariantRank(lhs.id);
  final rhsVariantRank = unitVariantRank(rhs.id);
  if (lhsVariantRank != rhsVariantRank) {
    return lhsVariantRank.compareTo(rhsVariantRank);
  }

  if (lhs.name != rhs.name) return lhs.name.compareTo(rhs.name);

  return lhs.id.compareTo(rhs.id);
}

String baseUnitID(String id) {
  if (id.endsWith('_upg_alt')) return id.substring(0, id.length - 8);
  if (id.endsWith('_upg')) return id.substring(0, id.length - 4);
  return id;
}

int unitVariantRank(String id) {
  if (id.endsWith('_upg_alt')) return 2;
  if (id.endsWith('_upg')) return 1;
  return 0;
}
