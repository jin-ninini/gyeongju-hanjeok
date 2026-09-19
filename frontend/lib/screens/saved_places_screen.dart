import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/place.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'place_detail_screen.dart';

class SavedPlacesScreen extends StatelessWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final places = controller.savedPlaces;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        title: const Text('저장한 장소'),
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
      ),
      body: places.isEmpty
          ? const EmptyState(
              icon: Icons.bookmark_border,
              title: '저장한 장소가 아직 없어요',
              description:
                  '장소 상세화면에서 북마크를 누르면 여기에서 다시 확인할 수 있어요.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                32,
              ),
              itemCount: places.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final place = places[index];

                return _SavedPlaceTile(
                  place: place,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlaceDetailScreen(
                        place: place,
                      ),
                    ),
                  ),
                  onRemove: () =>
                      controller.toggleSaved(place),
                );
              },
            ),
    );
  }
}

class _SavedPlaceTile extends StatelessWidget {
  const _SavedPlaceTile({
    required this.place,
    required this.onOpen,
    required this.onRemove,
  });

  final Place place;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final congestion =
        (100 - place.quietScore).clamp(0, 100).toInt();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: PlaceImage(
                    place: place,
                    hero: false,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.category,
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      place.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '혼잡도 $congestion%',
                      style: const TextStyle(
                        color: AppColors.forest,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '저장 해제',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.bookmark,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
