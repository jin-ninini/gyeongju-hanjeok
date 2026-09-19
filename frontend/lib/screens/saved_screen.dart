import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/completed_trip.dart';
import '../models/place.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'place_detail_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({
    super.key,
  });

  @override
  State<SavedScreen> createState() =>
      _SavedScreenState();
}

class _SavedScreenState
    extends State<SavedScreen> {
  int _tab = 0;

  @override
  Widget build(
    BuildContext context,
  ) {
    final controller =
        AppScope.of(context);

    final saved =
        controller.savedPlaces;

    final completed =
        controller.completedTrips;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor:
              AppColors.paper
                  .withValues(
                    alpha: 0.96,
                  ),
          surfaceTintColor:
              Colors.transparent,
          title: const Text(
            '저장한 여행',
          ),
        ),

        SliverPadding(
          padding:
              const EdgeInsets.fromLTRB(
                18,
                8,
                18,
                112,
              ),
          sliver:
              SliverList.list(
                children: [
                  Text(
                    '나의 경주 기록',
                    style:
                        Theme.of(
                          context,
                        ).textTheme
                            .displaySmall,
                  ),

                  const SizedBox(
                    height: 7,
                  ),

                  Text(
                    '마음에 든 장소와 완료한 여행 코스를 한곳에서 다시 볼 수 있어요.',
                    style:
                        Theme.of(
                          context,
                        ).textTheme
                            .bodyMedium,
                  ),

                  const SizedBox(
                    height: 20,
                  ),

                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        icon: const Icon(
                          Icons
                              .bookmark_outline,
                        ),
                        label: Text(
                          '장소 ${saved.length}',
                        ),
                      ),

                      ButtonSegment(
                        value: 1,
                        icon: const Icon(
                          Icons
                              .route_outlined,
                        ),
                        label: Text(
                          '완료 코스 ${completed.length}',
                        ),
                      ),
                    ],
                    selected: {
                      _tab,
                    },
                    onSelectionChanged:
                        (values) {
                      setState(
                        () {
                          _tab =
                              values.first;
                        },
                      );
                    },
                  ),

                  const SizedBox(
                    height: 22,
                  ),

                  if (_tab == 0)
                    _SavedPlacesSection(
                      places: saved,
                      controller:
                          controller,
                    )
                  else
                    _CompletedTripsSection(
                      trips: completed,
                      controller:
                          controller,
                    ),
                ],
              ),
        ),
      ],
    );
  }
}

class _SavedPlacesSection
    extends StatelessWidget {
  const _SavedPlacesSection({
    required this.places,
    required this.controller,
  });

  final List<Place> places;
  final AppController controller;

  @override
  Widget build(
    BuildContext context,
  ) {
    if (places.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.only(
              top: 70,
            ),
        child: EmptyState(
          icon:
              Icons.bookmark_border,
          title:
              '저장한 장소가 아직 없어요',
          description:
              '마음에 드는 장소의 북마크 버튼을 누르면 여기에서 다시 확인할 수 있어요.',
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title:
              '다시 가고 싶은 곳',
          subtitle:
              '저장한 관광지와 음식점을 모아봤어요.',
        ),

        const SizedBox(
          height: 13,
        ),

        GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing:
                    12,
                mainAxisSpacing:
                    12,
                childAspectRatio:
                    0.76,
              ),
          itemCount:
              places.length,
          itemBuilder:
              (
                context,
                index,
              ) {
            final place =
                places[index];

            return _SavedCard(
              place: place,
              visited:
                  controller
                      .isVisited(
                        place.id,
                      ),
              onTap: () =>
                  Navigator.of(
                    context,
                  ).push(
                    MaterialPageRoute<
                      void
                    >(
                      builder:
                          (_) =>
                              PlaceDetailScreen(
                                place:
                                    place,
                              ),
                    ),
                  ),
              onRemove:
                  () async {
                await controller
                    .toggleSaved(
                      place,
                    );

                if (!context
                    .mounted) {
                  return;
                }

                showAppSnackBar(
                  context,
                  '저장을 해제했어요.',
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _CompletedTripsSection
    extends StatelessWidget {
  const _CompletedTripsSection({
    required this.trips,
    required this.controller,
  });

  final List<CompletedTrip> trips;
  final AppController controller;

  @override
  Widget build(
    BuildContext context,
  ) {
    if (trips.isEmpty) {
      return const Padding(
        padding:
            EdgeInsets.only(
              top: 70,
            ),
        child: EmptyState(
          icon:
              Icons.route_outlined,
          title:
              '완료한 여행이 아직 없어요',
          description:
              '코스 여행의 마지막 장소까지 완료하면 이곳에 자동으로 저장돼요.',
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title:
              '완료한 여행',
          subtitle:
              '직접 다녀온 코스를 날짜별로 보관하고 있어요.',
        ),

        const SizedBox(
          height: 13,
        ),

        ...trips.map(
          (trip) =>
              Padding(
                padding:
                    const EdgeInsets.only(
                      bottom: 12,
                    ),
                child:
                    _CompletedTripCard(
                      trip: trip,
                      onOpen:
                          () =>
                              _showTripDetail(
                                context,
                                trip,
                              ),
                      onDelete:
                          () async {
                            final confirmed =
                                await showDialog<
                                  bool
                                >(
                                  context:
                                      context,
                                  builder:
                                      (
                                        dialogContext,
                                      ) =>
                                          AlertDialog(
                                            title:
                                                const Text(
                                                  '완료 코스를 삭제할까요?',
                                                ),
                                            content:
                                                Text(
                                                  '${trip.route.title} 기록을 저장 탭에서 삭제합니다.',
                                                ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(
                                                          dialogContext,
                                                          false,
                                                        ),
                                                child:
                                                    const Text(
                                                      '취소',
                                                    ),
                                              ),
                                              FilledButton(
                                                onPressed:
                                                    () =>
                                                        Navigator.pop(
                                                          dialogContext,
                                                          true,
                                                        ),
                                                child:
                                                    const Text(
                                                      '삭제',
                                                    ),
                                              ),
                                            ],
                                          ),
                                );

                            if (confirmed !=
                                true) {
                              return;
                            }

                            await controller
                                .removeCompletedTrip(
                                  trip.id,
                                );
                          },
                    ),
              ),
        ),
      ],
    );
  }

  Future<void>
      _showTripDetail(
    BuildContext context,
    CompletedTrip trip,
  ) async {
    await showModalBottomSheet<
      void
    >(
      context: context,
      showDragHandle: true,
      isScrollControlled:
          true,
      backgroundColor:
          AppColors.paper,
      builder:
          (
            sheetContext,
          ) {
        return SafeArea(
          child:
              DraggableScrollableSheet(
                initialChildSize:
                    0.72,
                minChildSize:
                    0.45,
                maxChildSize:
                    0.92,
                expand: false,
                builder:
                    (
                      context,
                      scrollController,
                    ) =>
                        ListView(
                          controller:
                              scrollController,
                          padding:
                              const EdgeInsets.fromLTRB(
                                18,
                                4,
                                18,
                                24,
                              ),
                          children: [
                            Text(
                              trip.route.title,
                              style:
                                  Theme.of(
                                    context,
                                  ).textTheme
                                      .titleLarge,
                            ),

                            const SizedBox(
                              height: 7,
                            ),

                            Text(
                              '${_dateLabel(trip.completedAt)} 완료 · '
                              '${trip.route.stops.length}곳 · '
                              '${_durationLabel(trip.route.totalMinutes)} · '
                              '${trip.route.totalDistanceKm.toStringAsFixed(1)}km',
                              style:
                                  Theme.of(
                                    context,
                                  ).textTheme
                                      .bodySmall,
                            ),

                            const SizedBox(
                              height: 20,
                            ),

                            ...trip
                                .route
                                .stops
                                .map(
                                  (
                                    stop,
                                  ) =>
                                      ListTile(
                                        contentPadding:
                                            EdgeInsets.zero,
                                        leading:
                                            CircleAvatar(
                                              backgroundColor:
                                                  AppColors.sage,
                                              foregroundColor:
                                                  AppColors.forest,
                                              child:
                                                  Text(
                                                    '${stop.order}',
                                                    style:
                                                        const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w900,
                                                        ),
                                                  ),
                                            ),
                                        title:
                                            Text(
                                              stop.place.name,
                                            ),
                                        subtitle:
                                            Text(
                                              '${stop.place.category} · 혼잡도 ${100 - stop.place.quietScore}%',
                                            ),
                                        trailing:
                                            const Icon(
                                              Icons.chevron_right,
                                            ),
                                        onTap:
                                            () =>
                                                Navigator.of(
                                                  sheetContext,
                                                ).push(
                                                  MaterialPageRoute<
                                                    void
                                                  >(
                                                    builder:
                                                        (_) =>
                                                            PlaceDetailScreen(
                                                              place:
                                                                  stop.place,
                                                            ),
                                                  ),
                                                ),
                                      ),
                                ),
                          ],
                        ),
              ),
        );
      },
    );
  }
}

class _CompletedTripCard
    extends StatelessWidget {
  const _CompletedTripCard({
    required this.trip,
    required this.onOpen,
    required this.onDelete,
  });

  final CompletedTrip trip;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(
    BuildContext context,
  ) {
    final names =
        trip.route.stops
            .take(3)
            .map(
              (stop) =>
                  stop.place.name,
            )
            .join(' · ');

    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius:
            BorderRadius.circular(
              21,
            ),
        child: Ink(
          padding:
              const EdgeInsets.all(
                16,
              ),
          decoration:
              softCardDecoration(
                radius: 21,
              ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration:
                    BoxDecoration(
                      color:
                          AppColors.sage,
                      borderRadius:
                          BorderRadius.circular(
                            17,
                          ),
                    ),
                child:
                    const Icon(
                      Icons
                          .check_circle_outline,
                      color:
                          AppColors.forest,
                    ),
              ),

              const SizedBox(
                width: 13,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            trip.route.title,
                            maxLines: 2,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                Theme.of(
                                  context,
                                ).textTheme
                                    .titleMedium,
                          ),
                        ),

                        IconButton(
                          tooltip:
                              '기록 삭제',
                          onPressed:
                              onDelete,
                          icon:
                              const Icon(
                                Icons
                                    .delete_outline,
                                size: 20,
                              ),
                        ),
                      ],
                    ),

                    if (names
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        names,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            Theme.of(
                              context,
                            ).textTheme
                                .bodySmall,
                      ),
                    ],

                    const SizedBox(
                      height: 8,
                    ),

                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _TripPill(
                          text:
                              _dateLabel(
                                trip.completedAt,
                              ),
                        ),
                        _TripPill(
                          text:
                              '${trip.route.stops.length}곳',
                        ),
                        _TripPill(
                          text:
                              _durationLabel(
                                trip.route.totalMinutes,
                              ),
                        ),
                        _TripPill(
                          text:
                              '${trip.route.totalDistanceKm.toStringAsFixed(1)}km',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripPill
    extends StatelessWidget {
  const _TripPill({
    required this.text,
  });

  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
      decoration:
          BoxDecoration(
            color:
                AppColors.sage
                    .withValues(
                      alpha: 0.7,
                    ),
            borderRadius:
                BorderRadius.circular(
                  999,
                ),
          ),
      child: Text(
        text,
        style:
            const TextStyle(
              color:
                  AppColors.forest,
              fontSize: 9.5,
              fontWeight:
                  FontWeight.w800,
            ),
      ),
    );
  }
}

class _SavedCard
    extends StatelessWidget {
  const _SavedCard({
    required this.place,
    required this.visited,
    required this.onTap,
    required this.onRemove,
  });

  final Place place;
  final bool visited;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color:
          Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
              21,
            ),
        child: Ink(
          decoration:
              softCardDecoration(
                radius: 21,
              ),
          child: ClipRRect(
            borderRadius:
                BorderRadius.circular(
                  21,
                ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    fit:
                        StackFit.expand,
                    children: [
                      PlaceImage(
                        place: place,
                        hero: false,
                      ),

                      const DecoratedBox(
                        decoration:
                            BoxDecoration(
                              gradient:
                                  LinearGradient(
                                    begin:
                                        Alignment.topCenter,
                                    end:
                                        Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Color(
                                        0x48162A23,
                                      ),
                                    ],
                                  ),
                            ),
                      ),

                      Positioned(
                        right: 7,
                        top: 7,
                        child:
                            IconButton.filled(
                              onPressed:
                                  onRemove,
                              style:
                                  IconButton.styleFrom(
                                    backgroundColor:
                                        AppColors.gold,
                                    foregroundColor:
                                        Colors.white,
                                    minimumSize:
                                        const Size(
                                          36,
                                          36,
                                        ),
                                  ),
                              icon:
                                  const Icon(
                                    Icons.bookmark,
                                    size: 18,
                                  ),
                            ),
                      ),

                      if (visited)
                        Positioned(
                          left: 9,
                          bottom: 9,
                          child:
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 5,
                                    ),
                                decoration:
                                    BoxDecoration(
                                      color:
                                          AppColors.forest,
                                      borderRadius:
                                          BorderRadius.circular(
                                            999,
                                          ),
                                    ),
                                child:
                                    const Text(
                                      '방문 완료',
                                      style:
                                          TextStyle(
                                            color:
                                                Colors.white,
                                            fontSize:
                                                9,
                                            fontWeight:
                                                FontWeight.w800,
                                          ),
                                    ),
                              ),
                        ),
                    ],
                  ),
                ),

                Padding(
                  padding:
                      const EdgeInsets.all(
                        12,
                      ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                              fontSize:
                                  13,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        '${place.category} · 혼잡도 ${100 - place.quietScore}%',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            Theme.of(
                              context,
                            ).textTheme
                                .bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _dateLabel(
  DateTime value,
) {
  final local =
      value.toLocal();

  return '${local.year}.'
      '${local.month.toString().padLeft(2, '0')}.'
      '${local.day.toString().padLeft(2, '0')}';
}

String _durationLabel(
  int minutes,
) {
  final hours =
      minutes ~/ 60;

  final remain =
      minutes % 60;

  if (hours == 0) {
    return '$remain분';
  }

  return remain == 0
      ? '$hours시간'
      : '$hours시간 $remain분';
}
