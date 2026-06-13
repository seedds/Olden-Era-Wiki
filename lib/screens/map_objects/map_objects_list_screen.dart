import 'package:flutter/cupertino.dart';

import '../../data/database.dart';
import '../../data/models/map_object.dart';
import '../../data/models/search.dart';
import '../../data/queries/map_objects_queries.dart';
import '../../routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_scaffold.dart';
import '../../widgets/local_image.dart';

/// Port of MapObjectsListView.swift.
class MapObjectsListScreen extends StatefulWidget {
  const MapObjectsListScreen({super.key});

  @override
  State<MapObjectsListScreen> createState() => _MapObjectsListScreenState();
}

class _MapObjectsListScreenState extends State<MapObjectsListScreen> {
  List<MapObjectListItem> _objects = [];

  @override
  void initState() {
    super.initState();
    try {
      _objects = WikiDatabase.instance.listMapObjects();
    } catch (error) {
      debugPrint('Error loading objects: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Objects',
      searchPriority: SearchEntityType.mapObjects,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        itemCount: _objects.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MapObjectRow(object: _objects[index]),
        ),
      ),
    );
  }
}

class _MapObjectRow extends StatelessWidget {
  const _MapObjectRow({required this.object});

  final MapObjectListItem object;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => pushMapObjectDetail(context, object.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            LocalImage(object.iconPath,
                size: 52, borderRadius: BorderRadius.circular(8)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                object.name,
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
