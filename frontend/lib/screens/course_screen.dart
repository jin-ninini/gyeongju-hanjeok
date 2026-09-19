import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_env.dart';
import '../core/app_theme.dart';
import '../models/completed_trip.dart';
import '../models/friend.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/shared_route.dart';
import '../services/kakao_invite_service.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'place_detail_screen.dart';
import 'qr_scanner_screen.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({
    super.key,
    this.onOpenCommunityReview,
  });

  final ValueChanged<CompletedTrip>? onOpenCommunityReview;

  @override
  State<CourseScreen> createState() =>
      _CourseScreenState();
}

class _CourseScreenState
    extends State<CourseScreen> {
  double _hours = 4;
  static const double _radius = 30;

  bool _showPlanner = false;
  int _libraryTab = 0;

  String _transport = 'driving';
  DateTime _travelDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();

  double? _routeStartLatitude;
  double? _routeStartLongitude;
  String _routeStartLabel = '현재 위치 기준';
  String _routeStartAddress = '';
  bool _routeStartLoading = false;
  bool _routeStartInitialized = false;

  final Set<String> _themes = {
    '문화유산',
    '산책',
  };

  bool _avoidPaid = false;
  bool _weatherAware = true;
  bool _includeRest = true;

  final _includeController =
  TextEditingController();

  final _excludeController =
  TextEditingController();

  final _memoController =
  TextEditingController();

  final _chatController =
  TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_routeStartInitialized) {
      return;
    }

    _routeStartInitialized = true;

    final controller = AppScope.of(context);

    _routeStartLatitude = controller.latitude;
    _routeStartLongitude = controller.longitude;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      unawaited(
        _resolveRouteStartInfo(
          controller,
          controller.latitude,
          controller.longitude,
        ),
      );
    });
  }

  bool _isTouristStartCandidate(Place place) {
    final category = place.category.trim();

    if (
    place.contentTypeId == '39' ||
        category == '맛집' ||
        category == '카페' ||
        category == '음식점' ||
        category == '숙박' ||
        category == '쇼핑'
    ) {
      return false;
    }

    return true;
  }

  Future<_RouteStartSelection> _resolveStartSelection(
      AppController controller,
      double latitude,
      double longitude,
      ) async {
    // 코스 알고리즘과 같은 방식:
    // 경주시 전체 관광지 목록에서 실제 좌표상 가장 가까운 관광지를 찾습니다.
    final nearest =
    await controller.fetchNearestTouristAt(
      latitude: latitude,
      longitude: longitude,
    );

    if (nearest != null) {
      return _RouteStartSelection(
        latitude: latitude,
        longitude: longitude,
        label: '${nearest.name} 근처',
        address: nearest.address,
        nearestPlace: nearest,
      );
    }

    // 전체 관광지 목록 조회가 실패한 경우에만 기존 주변검색 fallback.
    try {
      final nearby = await controller.fetchPlacesAt(
        latitude: latitude,
        longitude: longitude,
        radiusKm: 10,
      );

      final tourists = nearby
          .where(_isTouristStartCandidate)
          .toList()
        ..sort(
              (a, b) =>
              a.distanceKm.compareTo(
                b.distanceKm,
              ),
        );

      if (tourists.isNotEmpty) {
        final fallback =
            tourists.first;

        return _RouteStartSelection(
          latitude: latitude,
          longitude: longitude,
          label: '${fallback.name} 근처',
          address: fallback.address,
          nearestPlace: fallback,
        );
      }
    } catch (_) {
      // 선택 좌표 자체는 계속 출발점으로 사용할 수 있습니다.
    }

    return _RouteStartSelection(
      latitude: latitude,
      longitude: longitude,
      label: '선택한 출발 위치',
      address: '주변 관광지 정보를 확인하지 못했어요.',
    );
  }

  Future<void> _resolveRouteStartInfo(
      AppController controller,
      double latitude,
      double longitude,
      ) async {
    if (!mounted) return;

    setState(() {
      _routeStartLoading = true;
    });

    final resolved = await _resolveStartSelection(
      controller,
      latitude,
      longitude,
    );

    if (!mounted) return;

    setState(() {
      _routeStartLatitude = resolved.latitude;
      _routeStartLongitude = resolved.longitude;
      _routeStartLabel = resolved.label;
      _routeStartAddress = resolved.address;
      _routeStartLoading = false;
    });
  }

  Future<void> _openRouteStartPicker(
      AppController controller,
      ) async {
    final selected = await Navigator.of(context)
        .push<_RouteStartSelection>(
      MaterialPageRoute<_RouteStartSelection>(
        fullscreenDialog: true,
        builder: (_) => _RouteStartMapPicker(
          controller: controller,
          initialLatitude:
          _routeStartLatitude ?? controller.latitude,
          initialLongitude:
          _routeStartLongitude ?? controller.longitude,
          initialLabel: _routeStartLabel,
          initialAddress: _routeStartAddress,
          resolveSelection: (
              latitude,
              longitude,
              ) => _resolveStartSelection(
            controller,
            latitude,
            longitude,
          ),
        ),
      ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _routeStartLatitude = selected.latitude;
      _routeStartLongitude = selected.longitude;
      _routeStartLabel = selected.label;
      _routeStartAddress = selected.address;
      _routeStartLoading = false;
    });
  }

  Future<void> _pickTravelDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate.isBefore(DateTime(now.year, now.month, now.day))
          ? DateTime(now.year, now.month, now.day)
          : _travelDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: '여행 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (picked == null || !mounted) return;
    setState(() => _travelDate = picked);
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
      helpText: '여행 시작 시각 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (picked == null || !mounted) return;
    setState(() => _startTime = picked);
  }

  String _travelDateValue() {
    final y = _travelDate.year.toString().padLeft(4, '0');
    final m = _travelDate.month.toString().padLeft(2, '0');
    final d = _travelDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _startTimeValue() {
    final h = _startTime.hour.toString().padLeft(2, '0');
    final m = _startTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  void dispose() {
    _includeController.dispose();
    _excludeController.dispose();
    _memoController.dispose();
    _chatController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller =
    AppScope.of(context);

    if (controller.tripActive &&
        controller.routePlan != null) {
      return _TripView(
        controller: controller,
        transport: _transport,
      );
    }

    if (controller.tripJustCompleted &&
        controller.lastCompletedTrip != null) {
      return _TripCompletedView(
        trip: controller.lastCompletedTrip!,
        onCreateNewRoute: controller.closeTripCompletion,
        onReviewCourse: widget.onOpenCommunityReview,
      );
    }

    if (controller.routePlan != null) {
      return _RouteResult(
        controller: controller,
        transport: _transport,
        chatController:
        _chatController,
        onReset: () {
          controller.clearRoute();
          setState(() {
            _showPlanner = true;
          });
        },
      );
    }

    if (!_showPlanner) {
      return _CourseLibrary(
        controller: controller,
        selectedTab: _libraryTab,
        onTabChanged: (value) {
          setState(() {
            _libraryTab = value;
          });
        },
        onCreateRoute: () {
          setState(() {
            _showPlanner = true;
          });
        },
        onReviewCourse: widget.onOpenCommunityReview,
      );
    }

    return _PlannerForm(
      hours: _hours,
      transport: _transport,
      themes: _themes,
      travelDate: _travelDate,
      startTime: _startTime,
      avoidPaid: _avoidPaid,
      weatherAware: _weatherAware,
      includeRest: _includeRest,
      includeController:
      _includeController,
      excludeController:
      _excludeController,
      memoController:
      _memoController,
      loading:
      controller.isBuildingRoute,
      startLabel: _routeStartLabel,
      startAddress: _routeStartAddress,
      startLoading: _routeStartLoading,

      onTravelDateTap: _pickTravelDate,
      onStartTimeTap: _pickStartTime,

      onHoursChanged: (value) {
        setState(
              () => _hours = value,
        );
      },

      onTransportChanged: (value) {
        setState(
              () => _transport = value,
        );
      },

      onThemeChanged: (
          theme,
          selected,
          ) {
        setState(() {
          if (selected) {
            _themes.add(theme);
          } else {
            _themes.remove(theme);
          }
        });
      },

      onAvoidPaidChanged: (value) {
        setState(
              () => _avoidPaid = value,
        );
      },

      onWeatherChanged: (value) {
        setState(
              () => _weatherAware = value,
        );
      },

      onRestChanged: (value) {
        setState(
              () => _includeRest = value,
        );
      },

      onLocate: () =>
          _openRouteStartPicker(
            controller,
          ),

      onSubmit: () =>
          _buildRoute(controller),
      onBack: () {
        setState(() {
          _showPlanner = false;
        });
      },
    );
  }

  Future<void> _buildRoute(
      AppController controller,
      ) async {
    if (_themes.isEmpty) {
      showAppSnackBar(
        context,
        '선호 테마를 하나 이상 선택해주세요.',
      );

      return;
    }

    final preferences =
    RoutePreferences(
      startLatitude:
      _routeStartLatitude ??
          controller.latitude,
      startLongitude:
      _routeStartLongitude ??
          controller.longitude,
      availableHours: _hours,
      transportType: _transport,
      radiusKm: _radius,
      preferredCategories:
      _themes.toList(),
      avoidPaid: _avoidPaid,
      weatherAware:
      _weatherAware,
      includeRestStops:
      _includeRest,
      expectedInclude:
      _includeController.text
          .trim(),
      expectedExclude:
      _excludeController.text
          .trim(),
      memo:
      _memoController.text
          .trim(),
      travelDate: _travelDateValue(),
      startTime: _startTimeValue(),
      visitedPlaceIds:
      controller
          .visitedPlaceIds
          .toList(),
    );

    await controller.buildRoute(
      preferences,
    );

    if (!mounted) return;

    // AppController도 notifyListeners()를 호출하지만,
    // 코스 탭 자체에서도 결과 화면 전환을 한 번 확실히 갱신합니다.
    setState(() {});

    if (controller.routePlan == null &&
        controller.routeMessage != null) {
      showAppSnackBar(
        context,
        controller.routeMessage!,
      );
    }
  }
}

// ============================================================
// 카카오맵 길찾기
// ============================================================

Future<void> _openKakaoMapRoute({
  required BuildContext context,
  required double startLatitude,
  required double startLongitude,
  required Place destination,
  required String transport,
}) async {
  String kakaoTransport;

  switch (transport) {
    case 'walking':
      kakaoTransport = 'foot';
      break;

    case 'public_transport':
      kakaoTransport = 'publictransit';
      break;

    case 'driving':
    default:
      kakaoTransport = 'car';
      break;
  }

  final destinationLatitude =
      destination.latitude;

  final destinationLongitude =
      destination.longitude;

  final appUri = Uri.parse(
    'kakaomap://route'
        '?sp=$startLatitude,$startLongitude'
        '&ep=$destinationLatitude,$destinationLongitude'
        '&by=$kakaoTransport',
  );

  // 카카오맵 앱이 없을 때 사용할 모바일 웹 주소
  final mobileWebUri = Uri.parse(
    'https://m.map.kakao.com/scheme/route'
        '?sp=$startLatitude,$startLongitude'
        '&ep=$destinationLatitude,$destinationLongitude'
        '&by=$kakaoTransport',
  );

  try {
    final opened = await launchUrl(
      appUri,
      mode:
      LaunchMode.externalApplication,
    );

    if (opened) {
      return;
    }
  } catch (_) {
    // 앱 실행 실패 시 아래에서 모바일 웹으로 이동
  }

  try {
    final openedWeb =
    await launchUrl(
      mobileWebUri,
      mode:
      LaunchMode.externalApplication,
    );

    if (!openedWeb &&
        context.mounted) {
      showAppSnackBar(
        context,
        '카카오맵을 실행하지 못했어요.',
      );
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        '카카오맵을 실행하지 못했어요.',
      );
    }
  }
}

// ============================================================
// 블로그 / YouTube 콘텐츠 탐색
// ============================================================

bool _isYouTubeLink(ContentLink link) {
  final type = link.type.toLowerCase();
  final title = link.title.toLowerCase();
  final url = link.url.toLowerCase();

  return type.contains('youtube') ||
      type.contains('video') ||
      title.contains('youtube') ||
      title.contains('유튜브') ||
      url.contains('youtube.com') ||
      url.contains('youtu.be');
}

bool _isBlogLink(ContentLink link) {
  final type = link.type.toLowerCase();
  final title = link.title.toLowerCase();
  final url = link.url.toLowerCase();

  return type.contains('blog') ||
      type.contains('naver') ||
      title.contains('블로그') ||
      title.contains('naver') ||
      title.contains('네이버') ||
      url.contains('blog.naver.com') ||
      url.contains('m.blog.naver.com');
}

Future<void> _openExternalContent(
    BuildContext context,
    ContentLink link,
    ) async {
  final uri = Uri.tryParse(link.url);

  if (uri == null) {
    if (context.mounted) {
      showAppSnackBar(context, '콘텐츠 주소를 확인할 수 없어요.');
    }
    return;
  }

  try {
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      showAppSnackBar(context, '콘텐츠를 열지 못했어요.');
    }
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, '콘텐츠를 열지 못했어요.');
    }
  }
}

Future<void> _openPlaceContents({
  required BuildContext context,
  required AppController controller,
  required Place place,
  required String kind,
}) async {
  try {
    showAppSnackBar(
      context,
      kind == 'youtube'
          ? '관련 YouTube 영상을 찾고 있어요.'
          : '관련 블로그 글을 찾고 있어요.',
    );

    final detail = await controller.fetchPlaceDetail(place);

    if (!context.mounted) return;

    final links = detail.contentLinks.where((link) {
      if (kind == 'youtube') {
        return _isYouTubeLink(link);
      }
      return _isBlogLink(link);
    }).toList();

    if (links.isEmpty) {
      showAppSnackBar(
        context,
        kind == 'youtube'
            ? '이 장소의 YouTube 콘텐츠를 아직 찾지 못했어요.'
            : '이 장소의 블로그 콘텐츠를 아직 찾지 못했어요.',
      );
      return;
    }

    if (links.length == 1) {
      await _openExternalContent(context, links.first);
      return;
    }

    final selected = await showModalBottomSheet<ContentLink>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) {
        final label = kind == 'youtube' ? 'YouTube' : '블로그';

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${place.name} $label',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '살펴볼 콘텐츠를 선택하세요.',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: links.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final link = links[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          kind == 'youtube'
                              ? Icons.play_circle_outline_rounded
                              : Icons.article_outlined,
                          color: AppColors.forest,
                        ),
                        title: Text(
                          link.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => Navigator.pop(sheetContext, link),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null && context.mounted) {
      await _openExternalContent(context, selected);
    }
  } catch (error) {
    if (context.mounted) {
      showAppSnackBar(
        context,
        '관련 콘텐츠를 불러오지 못했어요. ${error.toString()}',
      );
    }
  }
}

int _congestionPercent(Place place) {
  return (100 - place.quietScore).clamp(0, 100);
}

Color _congestionColor(int score) {
  if (score <= 20) return const Color(0xFF1E88E5);
  if (score <= 40) return const Color(0xFF26A69A);
  if (score <= 60) return const Color(0xFFFBC02D);
  if (score <= 80) return const Color(0xFFF57C00);
  return const Color(0xFFE53935);
}


String _durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remain = minutes % 60;

  if (hours == 0) {
    return '$remain분';
  }

  return remain == 0
      ? '$hours시간'
      : '$hours시간 $remain분';
}

String _dateLabel(DateTime dateTime) {
  final local = dateTime.toLocal();
  return '${local.month}월 ${local.day}일';
}

class _CourseLibrary extends StatelessWidget {
  const _CourseLibrary({
    required this.controller,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onCreateRoute,
    this.onReviewCourse,
  });

  final AppController controller;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onCreateRoute;
  final ValueChanged<CompletedTrip>? onReviewCourse;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E8D7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 18,
        title: const Text(
          '코스',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: AppColors.forest,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => controller.loadRouteLibrary(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 118),
          children: [
            _CourseLibraryHero(onCreateRoute: onCreateRoute),
            const SizedBox(height: 26),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '내 코스',
                    style: TextStyle(
                      fontFamily: 'MaruBuri',
                      color: Color(0xFF3E3127),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '총 ${controller.savedRoutes.length + controller.sharedRoutes.length + controller.completedTrips.length}개',
                  style: const TextStyle(
                    fontFamily: 'WantedSans',
                    color: AppColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CourseLibraryTabs(
              selectedTab: selectedTab,
              savedCount: controller.savedRoutes.length,
              sharedCount: controller.sharedRoutes.length,
              completedCount: controller.completedTrips.length,
              onChanged: onTabChanged,
            ),
            const SizedBox(height: 18),
            if (controller.isLoadingRouteLibrary)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 54),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppColors.forest),
                      SizedBox(height: 14),
                      Text(
                        '불러오는 중',
                        style: TextStyle(
                          fontFamily: 'WantedSans',
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (selectedTab == 0)
              _SavedRouteLibrary(
                routes: controller.savedRoutes,
                controller: controller,
              )
            else if (selectedTab == 1)
                _SharedRouteLibrary(
                  routes: controller.sharedRoutes,
                  controller: controller,
                )
              else
                _CompletedRouteLibrary(
                  trips: controller.completedTrips,
                  controller: controller,
                  onReviewCourse: onReviewCourse,
                ),
          ],
        ),
      ),
    );
  }
}


class _CourseLibraryTabs extends StatelessWidget {
  const _CourseLibraryTabs({
    required this.selectedTab,
    required this.savedCount,
    required this.sharedCount,
    required this.completedCount,
    required this.onChanged,
  });

  final int selectedTab;
  final int savedCount;
  final int sharedCount;
  final int completedCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE9DFCF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CourseTabButton(
              selected: selectedTab == 0,
              icon: Icons.bookmark_outline,
              label: '저장',
              count: savedCount,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CourseTabButton(
              selected: selectedTab == 1,
              icon: Icons.group_outlined,
              label: '동행',
              count: sharedCount,
              onTap: () => onChanged(1),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _CourseTabButton(
              selected: selectedTab == 2,
              icon: Icons.check_circle_outline,
              label: '완료',
              count: completedCount,
              onTap: () => onChanged(2),
            ),
          ),
        ],
      ),
    );
  }
}


class _CourseTabButton extends StatelessWidget {
  const _CourseTabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? AppColors.forest
        : const Color(0xFF6A5C50);

    return Semantics(
      button: true,
      selected: selected,
      label: '$label 코스 $count개',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 50,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFFFFCF7)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'WantedSans',
                  color: foreground,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE3EEE7)
                      : const Color(0x22FFFFFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'WantedSans',
                    color: foreground,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CourseLibraryHero extends StatelessWidget {
  const _CourseLibraryHero({
    required this.onCreateRoute,
  });

  final VoidCallback onCreateRoute;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCreateRoute,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 19, 16, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD8C9B5),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4EDE6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '한적한 경주 여행',
                        style: TextStyle(
                          fontFamily: 'WantedSans',
                          color: AppColors.forest,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '나만의 코스 만들기',
                      style: TextStyle(
                        fontFamily: 'MaruBuri',
                        color: Color(0xFF3E3127),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      '시간과 취향을 고르면 지금 상황에 맞는\n경주 코스를 추천해드려요.',
                      style: TextStyle(
                        fontFamily: 'WantedSans',
                        color: Color(0xFF74695F),
                        fontSize: 10.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 13),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '코스 만들기',
                          style: TextStyle(
                            fontFamily: 'WantedSans',
                            color: AppColors.forest,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.forest,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 94,
                height: 108,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: 2,
                      top: 0,
                      child: _CourseHeroIcon(
                        assetPath: 'assets/images/course/course_travel_type_heritage.png',
                        fallbackIcon: Icons.account_balance_outlined,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 31,
                      child: _CourseHeroIcon(
                        assetPath: 'assets/images/course/course_travel_type_nature.png',
                        fallbackIcon: Icons.park_outlined,
                      ),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 0,
                      child: _CourseHeroIcon(
                        assetPath: 'assets/images/course/course_travel_type_night_view.png',
                        fallbackIcon: Icons.nightlight_outlined,
                      ),
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

class _CourseHeroIcon extends StatelessWidget {
  const _CourseHeroIcon({
    required this.assetPath,
    required this.fallbackIcon,
  });

  final String assetPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBDD),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDCC9AD)),
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          fallbackIcon,
          color: AppColors.forest,
          size: 24,
        ),
      ),
    );
  }
}


class _SavedRouteLibrary extends StatelessWidget {
  const _SavedRouteLibrary({
    required this.routes,
    required this.controller,
  });

  final List<RoutePlan> routes;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const _RouteLibraryEmpty(
        icon: Icons.bookmark_border,
        title: '저장한 코스가 아직 없어요',
      );
    }

    return Column(
      children: routes
          .map(
            (route) => _LibraryRouteCard(
          title: route.title,
          summary: route.summary,
          meta:
          '${route.stops.length}곳 · ${_durationLabel(route.totalMinutes)} · ${route.totalDistanceKm.toStringAsFixed(1)}km',
          icon: Icons.bookmark,
          onOpen: () => controller.openSavedRoute(route),
          onDelete: () => controller.removeSavedRoute(route.id),
        ),
      )
          .toList(),
    );
  }
}

class _SharedRouteLibrary extends StatelessWidget {
  const _SharedRouteLibrary({
    required this.routes,
    required this.controller,
  });

  final List<SharedRoute> routes;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) {
      return const _RouteLibraryEmpty(
        icon: Icons.group_outlined,
        title: '동행 코스가 아직 없어요',
      );
    }

    return Column(
      children: routes
          .map(
            (shared) => _LibraryRouteCard(
          title: shared.route.title,
          summary: shared.route.summary,
          meta:
          '${shared.members.length}명 참여 · 버전 ${shared.version} · ${shared.route.stops.length}곳',
          icon: Icons.groups_2_outlined,
          onOpen: () => controller.openSharedRoute(shared),
        ),
      )
          .toList(),
    );
  }
}

class _CompletedRouteLibrary extends StatelessWidget {
  const _CompletedRouteLibrary({
    required this.trips,
    required this.controller,
    this.onReviewCourse,
  });

  final List<CompletedTrip> trips;
  final AppController controller;
  final ValueChanged<CompletedTrip>? onReviewCourse;

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const _RouteLibraryEmpty(
        icon: Icons.check_circle_outline,
        title: '완료한 코스가 아직 없어요',
      );
    }

    return Column(
      children: trips
          .map(
            (trip) => _LibraryRouteCard(
          title: trip.route.title,
          summary: trip.route.summary,
          meta:
          '${_dateLabel(trip.completedAt)} 완료 · ${trip.route.stops.length}곳 · ${_durationLabel(trip.route.totalMinutes)}',
          icon: Icons.check_circle,
          onOpen: () => _showCompletedRoute(
            context,
            trip,
            onReviewCourse,
          ),
          onDelete: () => _confirmDeleteCompletedTrip(
            context,
            controller,
            trip,
          ),
        ),
      )
          .toList(),
    );
  }

  static Future<void> _confirmDeleteCompletedTrip(
      BuildContext context,
      AppController controller,
      CompletedTrip trip,
      ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('완료 코스를 삭제할까요?'),
        content: Text(
          '「${trip.route.title}」 완료 기록을 삭제합니다.\n'
              '삭제한 기록은 다시 복구할 수 없어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.forest,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    await controller.removeCompletedTrip(trip.id);

    if (!context.mounted) return;
    showAppSnackBar(
      context,
      '완료 코스를 삭제했어요.',
    );
  }

  static Future<void> _showCompletedRoute(
      BuildContext context,
      CompletedTrip trip,
      ValueChanged<CompletedTrip>? onReviewCourse,
      ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            children: [
              Text(
                trip.route.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${_dateLabel(trip.completedAt)} 완료 · ${trip.route.stops.length}곳',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              ...trip.route.stops.map(
                    (stop) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.sage,
                    foregroundColor: AppColors.forest,
                    child: Text('${stop.order}'),
                  ),
                  title: Text(stop.place.name),
                  subtitle: Text(
                    '${stop.stayMinutes}분 체류 · 혼잡도 ${(100 - stop.place.quietScore).clamp(0, 100)}%',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onReviewCourse == null
                    ? null
                    : () {
                  Navigator.pop(sheetContext);
                  onReviewCourse(trip);
                },
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('코스 평가하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _LibraryRouteCard extends StatelessWidget {
  const _LibraryRouteCard({
    required this.title,
    required this.summary,
    required this.meta,
    required this.icon,
    required this.onOpen,
    this.onDelete,
  });

  final String title;
  final String summary;
  final String meta;
  final IconData icon;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE3D9CB),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EFE9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.forest,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'MaruBuri',
                          color: Color(0xFF3E3127),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        summary.trim().isEmpty ? meta : summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'WantedSans',
                          color: Color(0xFF74695F),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'WantedSans',
                          color: Color(0xFF9A8E82),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: '삭제',
                    onPressed: onDelete,
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFF8A5A45),
                      size: 20,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF8D7A66),
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


class _RouteLibraryEmpty extends StatelessWidget {
  const _RouteLibraryEmpty({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3D9CB)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFE9E1D1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: AppColors.forest,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'WantedSans',
                  color: Color(0xFF5A4D42),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _PlannerForm extends StatelessWidget {
  const _PlannerForm({
    required this.hours,
    required this.transport,
    required this.themes,
    required this.travelDate,
    required this.startTime,
    required this.avoidPaid,
    required this.weatherAware,
    required this.includeRest,
    required this.includeController,
    required this.excludeController,
    required this.memoController,
    required this.loading,
    required this.startLabel,
    required this.startAddress,
    required this.startLoading,
    required this.onTravelDateTap,
    required this.onStartTimeTap,
    required this.onHoursChanged,
    required this.onTransportChanged,
    required this.onThemeChanged,
    required this.onAvoidPaidChanged,
    required this.onWeatherChanged,
    required this.onRestChanged,
    required this.onLocate,
    required this.onSubmit,
    required this.onBack,
  });

  final double hours;
  final String transport;
  final Set<String> themes;
  final DateTime travelDate;
  final TimeOfDay startTime;

  final bool avoidPaid;
  final bool weatherAware;
  final bool includeRest;

  final TextEditingController includeController;
  final TextEditingController excludeController;
  final TextEditingController memoController;

  final bool loading;
  final String startLabel;
  final String startAddress;
  final bool startLoading;

  final VoidCallback onTravelDateTap;
  final VoidCallback onStartTimeTap;
  final ValueChanged<double> onHoursChanged;
  final ValueChanged<String> onTransportChanged;

  final void Function(
      String theme,
      bool selected,
      ) onThemeChanged;

  final ValueChanged<bool> onAvoidPaidChanged;
  final ValueChanged<bool> onWeatherChanged;
  final ValueChanged<bool> onRestChanged;

  final VoidCallback onLocate;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  static const _mainThemes = [
    '문화유산',
    '자연',
    '산책',
    '전통마을',
    '야경',
    '행사',
  ];

  static const _foodThemes = [
    '맛집',
    '카페',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E8D7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        leading: IconButton(
          tooltip: '내 코스로 돌아가기',
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF4B3A30),
          ),
        ),
        titleSpacing: 2,
        title: const Text(
          '코스 만들기',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: AppColors.forest,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 132),
        children: [
          const _PlannerVisualHero(),
          const SizedBox(height: 26),

          _SimplePlannerSection(
            number: '1',
            title: '어떤 여행을 원하세요?',
            subtitle: '원하는 테마를 하나 이상 골라주세요.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 0.95,
                  children: [
                    for (final theme in _mainThemes)
                      _ThemeChoiceChip(
                        label: theme,
                        selected: themes.contains(theme),
                        onTap: () => onThemeChanged(
                          theme,
                          !themes.contains(theme),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '먹거리 · 휴식',
                  style: TextStyle(
                    fontFamily: 'WantedSans',
                    color: Color(0xFF6F6256),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < _foodThemes.length; i++) ...[
                      if (i > 0) const SizedBox(width: 9),
                      Expanded(
                        child: _ThemeChoiceChip(
                          label: _foodThemes[i],
                          selected: themes.contains(_foodThemes[i]),
                          onTap: () => onThemeChanged(
                            _foodThemes[i],
                            !themes.contains(_foodThemes[i]),
                          ),
                          compact: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _DepartureLocationCard(
            label: startLabel,
            address: startAddress,
            loading: startLoading,
            onPick: onLocate,
          ),

          const SizedBox(height: 28),

          _SimplePlannerSection(
            number: '2',
            title: '언제, 얼마나 여행할까요?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _PlannerDateTimeChoice(
                        icon: Icons.calendar_month_outlined,
                        label: '${travelDate.month}월 ${travelDate.day}일',
                        onTap: onTravelDateTap,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: _PlannerDateTimeChoice(
                        icon: Icons.schedule_outlined,
                        label: startTime.format(context),
                        onTap: onStartTimeTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: 7),
                      Expanded(
                        child: _PresetChoiceChip(
                          label: '${const [2, 4, 6, 8][i]}시간',
                          selected: (hours - const [2, 4, 6, 8][i]).abs() < 0.01,
                          onTap: () => onHoursChanged(
                            const [2, 4, 6, 8][i].toDouble(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _SimplePlannerSection(
            number: '3',
            title: '어떻게 이동할까요?',
            child: Row(
              children: [
                Expanded(
                  child: _TransportChoice(
                    icon: Icons.directions_walk,
                    label: '도보',
                    selected: transport == 'walking',
                    onTap: () => onTransportChanged('walking'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _TransportChoice(
                    icon: Icons.directions_car_outlined,
                    label: '자동차',
                    selected: transport == 'driving',
                    onTap: () => onTransportChanged('driving'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _TransportChoice(
                    icon: Icons.directions_bus_outlined,
                    label: '대중교통',
                    selected: transport == 'public_transport',
                    onTap: () => onTransportChanged('public_transport'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _QuickOptionCard(
            avoidPaid: avoidPaid,
            weatherAware: weatherAware,
            includeRest: includeRest,
            onAvoidPaidChanged: onAvoidPaidChanged,
            onWeatherChanged: onWeatherChanged,
            onRestChanged: onRestChanged,
          ),

          const SizedBox(height: 14),

          _AdvancedPlannerSettings(
            includeController: includeController,
            excludeController: excludeController,
            memoController: memoController,
          ),

          const SizedBox(height: 22),

          GestureDetector(
            onTap: loading ? null : onSubmit,
            behavior: HitTestBehavior.opaque,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: loading ? 0.62 : 1,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.forest,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x24254B42),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: loading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFFF4D0),
                  ),
                )
                    : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Color(0xFFFFF4D0),
                    ),
                    SizedBox(width: 7),
                    Text(
                      '이 조건으로 코스 만들기',
                      style: TextStyle(
                        fontFamily: 'WantedSans',
                        color: Color(0xFFFFF4D0),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _PlannerVisualHero extends StatelessWidget {
  const _PlannerVisualHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDCFBD)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4EADB),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Image.asset(
              'assets/images/home/모래시계.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.schedule_rounded,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 13),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '나에게 맞는 경주 코스',
                  style: TextStyle(
                    fontFamily: 'MaruBuri',
                    color: Color(0xFF3E3127),
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '취향 · 시간 · 이동수단을 선택하면\n기존 추천 기능이 그대로 코스를 만들어줘요.',
                  style: TextStyle(
                    fontFamily: 'WantedSans',
                    color: AppColors.muted,
                    fontSize: 10.2,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _PlannerDateTimeChoice extends StatelessWidget {
  const _PlannerDateTimeChoice({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD8CABB)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7EEE8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppColors.forest),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'WantedSans',
                    color: Color(0xFF4C4036),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _DepartureLocationCard extends StatelessWidget {
  const _DepartureLocationCard({
    required this.label,
    required this.address,
    required this.loading,
    required this.onPick,
  });

  final String label;
  final String address;
  final bool loading;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text(
              '출발 위치',
              style: TextStyle(
                fontFamily: 'MaruBuri',
                color: Color(0xFF3E3127),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: 6),
            Text(
              '지도에서 변경 가능',
              style: TextStyle(
                fontFamily: 'WantedSans',
                color: AppColors.muted,
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD8CABB)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4EEE7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: loading
                        ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.forest,
                      ),
                    )
                        : const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.forest,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loading ? '위치 확인 중' : label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'WantedSans',
                            color: Color(0xFF3E3127),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!loading && address.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'WantedSans',
                              color: AppColors.muted,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4EADB),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.map_outlined,
                      color: AppColors.forest,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _RouteStartSelection {
  const _RouteStartSelection({
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.address,
    this.nearestPlace,
  });

  final double latitude;
  final double longitude;
  final String label;
  final String address;
  final Place? nearestPlace;
}

class _RouteStartMapPicker extends StatefulWidget {
  const _RouteStartMapPicker({
    required this.controller,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.initialLabel,
    required this.initialAddress,
    required this.resolveSelection,
  });

  final AppController controller;
  final double initialLatitude;
  final double initialLongitude;
  final String initialLabel;
  final String initialAddress;
  final Future<_RouteStartSelection> Function(
      double latitude,
      double longitude,
      ) resolveSelection;

  @override
  State<_RouteStartMapPicker> createState() =>
      _RouteStartMapPickerState();
}

class _RouteStartMapPickerState
    extends State<_RouteStartMapPicker> {
  late double _latitude;
  late double _longitude;
  late String _label;
  late String _address;

  WebViewController? _webController;
  Timer? _resolveDebounce;
  bool _resolving = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();

    _latitude = widget.initialLatitude;
    _longitude = widget.initialLongitude;
    _label = widget.initialLabel;
    _address = widget.initialAddress;

    if (
    AppEnv.kakaoJavaScriptKey.isNotEmpty &&
        !kIsWeb
    ) {
      _webController = WebViewController()
        ..setJavaScriptMode(
          JavaScriptMode.unrestricted,
        )
        ..setBackgroundColor(
          const Color(0xFFE7EFEA),
        )
        ..addJavaScriptChannel(
          'RouteStartChannel',
          onMessageReceived: (message) {
            try {
              final data = jsonDecode(
                message.message,
              );

              if (data is! Map) return;

              final latitude =
              (data['latitude'] as num?)
                  ?.toDouble();

              final longitude =
              (data['longitude'] as num?)
                  ?.toDouble();

              if (
              latitude == null ||
                  longitude == null
              ) {
                return;
              }

              _latitude = latitude;
              _longitude = longitude;
              _scheduleResolve();
            } catch (_) {
              // 잘못된 WebView 메시지는 무시합니다.
            }
          },
        )
        ..loadHtmlString(
          _pickerHtml(),
          baseUrl: AppEnv.kakaoMapBaseUrl,
        );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_resolveNow());
    });
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();

    // 출발지 선택 화면을 닫는 즉시 PlatformView 참조를 끊습니다.
    _webController = null;

    super.dispose();
  }

  void _scheduleResolve() {
    _resolveDebounce?.cancel();

    _resolveDebounce = Timer(
      const Duration(milliseconds: 650),
          () {
        if (mounted) {
          unawaited(_resolveNow());
        }
      },
    );
  }

  Future<void> _resolveNow() async {
    if (!mounted) return;

    setState(() {
      _resolving = true;
    });

    final resolved = await widget.resolveSelection(
      _latitude,
      _longitude,
    );

    if (!mounted) return;

    setState(() {
      _label = resolved.label;
      _address = resolved.address;
      _resolving = false;
    });
  }

  Future<void> _moveMapTo(
      double latitude,
      double longitude,
      ) async {
    final web = _webController;

    if (web == null) {
      return;
    }

    try {
      await web.runJavaScript(
        '''
        if (window.routeStartMap && window.kakao) {
          const next = new kakao.maps.LatLng(
            $latitude,
            $longitude
          );
          window.routeStartMap.panTo(next);
        }
        ''',
      );
    } catch (_) {
      // WebView가 로딩 중인 경우 다음 지도 idle 이벤트에서 동기화됩니다.
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;

    setState(() {
      _locating = true;
    });

    final message = await widget.controller
        .useCurrentLocation();

    if (!mounted) return;

    _latitude = widget.controller.latitude;
    _longitude = widget.controller.longitude;

    await _moveMapTo(
      _latitude,
      _longitude,
    );

    await _resolveNow();

    if (!mounted) return;

    setState(() {
      _locating = false;
    });

    showAppSnackBar(
      context,
      message,
    );
  }

  String _pickerHtml() {
    return '''
<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
<style>
html, body, #map {
  width: 100%;
  height: 100%;
  margin: 0;
  padding: 0;
  overflow: hidden;
  background: #E7EFEA;
}
</style>
<script src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=${AppEnv.kakaoJavaScriptKey}&autoload=false"></script>
</head>
<body>
<div id="map"></div>
<script>
kakao.maps.load(function() {
  const center = new kakao.maps.LatLng(
    ${widget.initialLatitude},
    ${widget.initialLongitude}
  );

  const map = new kakao.maps.Map(
    document.getElementById('map'),
    {
      center: center,
      level: 5
    }
  );

  window.routeStartMap = map;

  function sendCenter() {
    const center = map.getCenter();
    RouteStartChannel.postMessage(
      JSON.stringify({
        latitude: center.getLat(),
        longitude: center.getLng()
      })
    );
  }

  kakao.maps.event.addListener(
    map,
    'idle',
    sendCenter
  );

  sendCenter();
});
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E8D7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '닫기',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '출발 위치 선택',
              style: TextStyle(
                fontFamily: 'MaruBuri',
                color: AppColors.forest,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '핀을 출발 위치에 맞춰주세요.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_webController != null)
                  WebViewWidget(
                    key: const ValueKey(
                      'route-start-picker-webview',
                    ),
                    controller: _webController!,
                  )
                else
                  Container(
                    color: AppColors.sage,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(30),
                    child: const Text(
                      '카카오 지도 키를 확인해주세요.\n현재 위치를 그대로 출발점으로 사용할 수 있어요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.forest,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: 36,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 48,
                        color: AppColors.forest,
                        shadows: [
                          Shadow(
                            color: Color(0x55000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  right: 14,
                  top: 14,
                  child: FloatingActionButton.small(
                    heroTag: 'route-start-current-location',
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.forest,
                    onPressed:
                    _locating ? null : _useCurrentLocation,
                    child: _locating
                        ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(
                      Icons.my_location,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(
              18,
              14,
              18,
              16,
            ),
            decoration: const BoxDecoration(
              color: AppColors.paper,
              border: Border(
                top: BorderSide(
                  color: AppColors.line,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: AppColors.sage,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: AppColors.forest,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _resolving
                                ? '주변 관광지를 찾는 중...'
                                : _label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.forest,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _resolving
                                ? '출발 위치를 선택해주세요.'
                                : _address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _resolving
                        ? null
                        : () {
                      Navigator.of(context).pop(
                        _RouteStartSelection(
                          latitude: _latitude,
                          longitude: _longitude,
                          label: _label,
                          address: _address,
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.flag_outlined,
                    ),
                    label: const Text(
                      '이 위치에서 출발',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _SimplePlannerSection extends StatelessWidget {
  const _SimplePlannerSection({
    required this.number,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String number;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 25,
              height: 25,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontFamily: 'WantedSans',
                  color: Color(0xFFFFF4D0),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: 'MaruBuri',
                  color: Color(0xFF3E3127),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Padding(
            padding: const EdgeInsets.only(left: 33),
            child: Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: 'WantedSans',
                color: AppColors.muted,
                fontSize: 10.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 11),
        child,
      ],
    );
  }
}


class _PresetChoiceChip extends StatelessWidget {
  const _PresetChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : const Color(0xFFD8CABB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'WantedSans',
            color: selected
                ? const Color(0xFFFFF4D0)
                : const Color(0xFF5A4D42),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}


class _TransportChoice extends StatelessWidget {
  const _TransportChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  String get _assetPath {
    final state = selected ? 'on' : 'off';
    switch (label) {
      case '도보':
        return 'assets/images/course/course_transport_walk_$state.png';
      case '자동차':
        return 'assets/images/course/course_transport_car_$state.png';
      case '대중교통':
        return 'assets/images/course/course_transport_transit_$state.png';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 108,
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0F5EF)
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : const Color(0xFFD8CABB),
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? const [
            BoxShadow(
              color: Color(0x10254B42),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Image.asset(
                _assetPath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  icon,
                  size: 29,
                  color: AppColors.forest,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'WantedSans',
                color: selected
                    ? AppColors.forest
                    : const Color(0xFF5A4D42),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _ThemeChoiceChip extends StatelessWidget {
  const _ThemeChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  String get _assetPath {
    switch (label) {
      case '문화유산':
        return 'assets/images/course/course_travel_type_heritage.png';
      case '자연':
        return 'assets/images/course/course_travel_type_nature.png';
      case '산책':
        return 'assets/images/course/course_transport_walk_off.png';
      case '전통마을':
        return 'assets/images/course/course_travel_type_traditional_village.png';
      case '야경':
        return 'assets/images/course/course_travel_type_night_view.png';
      case '행사':
        return 'assets/images/course/course_travel_type_event.png';
      case '맛집':
        return 'assets/images/course/course_travel_type_food.png';
      case '카페':
        return 'assets/images/course/course_travel_type_cafe.png';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: BoxConstraints(
          minHeight: compact ? 84 : 102,
        ),
        padding: EdgeInsets.fromLTRB(
          compact ? 12 : 9,
          compact ? 8 : 9,
          compact ? 12 : 9,
          compact ? 8 : 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0F5EF)
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : const Color(0xFFD8CABB),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: compact ? 48 : 62,
                  child: Center(
                    child: _assetPath.isEmpty
                        ? const Icon(
                      Icons.local_offer_outlined,
                      color: AppColors.forest,
                    )
                        : Image.asset(
                      _assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.local_offer_outlined,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'WantedSans',
                      color: selected
                          ? AppColors.forest
                          : const Color(0xFF5A4D42),
                      fontSize: compact ? 10 : 10.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (selected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.forest,
                  size: 17,
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _QuickOptionCard extends StatelessWidget {
  const _QuickOptionCard({
    required this.avoidPaid,
    required this.weatherAware,
    required this.includeRest,
    required this.onAvoidPaidChanged,
    required this.onWeatherChanged,
    required this.onRestChanged,
  });

  final bool avoidPaid;
  final bool weatherAware;
  final bool includeRest;

  final ValueChanged<bool> onAvoidPaidChanged;
  final ValueChanged<bool> onWeatherChanged;
  final ValueChanged<bool> onRestChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '추가 옵션',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: Color(0xFF3E3127),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '필요한 조건만 가볍게 켜주세요.',
          style: TextStyle(
            fontFamily: 'WantedSans',
            color: AppColors.muted,
            fontSize: 10.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CompactOptionChip(
                icon: Icons.payments_outlined,
                label: '유료 피하기',
                selected: avoidPaid,
                onTap: () => onAvoidPaidChanged(!avoidPaid),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _CompactOptionChip(
                icon: Icons.cloud_outlined,
                label: '날씨 반영',
                selected: weatherAware,
                onTap: () => onWeatherChanged(!weatherAware),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _CompactOptionChip(
                icon: Icons.chair_outlined,
                label: '휴식 포함',
                selected: includeRest,
                onTap: () => onRestChanged(!includeRest),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


class _CompactOptionChip extends StatelessWidget {
  const _CompactOptionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFF0F5EF)
              : const Color(0xFFFFFCF8),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected
                ? AppColors.forest
                : const Color(0xFFD8CABB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFE1ECE4)
                    : const Color(0xFFF4EADB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: label == '유료 피하기'
                  ? Image.asset(
                'assets/images/home/엽전.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  icon,
                  color: AppColors.forest,
                  size: 18,
                ),
              )
                  : Icon(
                icon,
                size: 18,
                color: AppColors.forest,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'WantedSans',
                color: selected
                    ? AppColors.forest
                    : const Color(0xFF5A4D42),
                fontSize: 9.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _AdvancedPlannerSettings extends StatelessWidget {
  const _AdvancedPlannerSettings({
    required this.includeController,
    required this.excludeController,
    required this.memoController,
  });

  final TextEditingController includeController;
  final TextEditingController excludeController;
  final TextEditingController memoController;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFCFA455),
          width: 1.1,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 2,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          15,
          0,
          15,
          16,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(
          Icons.settings_outlined,
          color: AppColors.forest,
        ),
        title: const Text(
          '세부 설정',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          '꼭 포함/제외 장소·자유 요청 (선택)',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
          ),
        ),
        children: [
          const Divider(
            height: 1,
            color: AppColors.line,
          ),
          const SizedBox(height: 16),

          const _AdvancedLabel(
            title: '장소 지정',
          ),
          const SizedBox(height: 8),

          TextField(
            controller: includeController,
            decoration: const InputDecoration(
              labelText: '꼭 포함할 장소',
              hintText: '예: 교촌마을',
              prefixIcon: Icon(
                Icons.add_location_alt_outlined,
              ),
            ),
          ),

          const SizedBox(height: 9),

          TextField(
            controller: excludeController,
            decoration: const InputDecoration(
              labelText: '제외할 장소',
              hintText: '예: 동궁과 월지',
              prefixIcon: Icon(
                Icons.location_off_outlined,
              ),
            ),
          ),

          const SizedBox(height: 18),

          const _AdvancedLabel(
            title: '자유 요청',
          ),
          const SizedBox(height: 8),

          TextField(
            controller: memoController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '예: 첨성대는 꼭 가고 부모님과 걷기 편하게 짜줘',
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedLabel extends StatelessWidget {
  const _AdvancedLabel({
    required this.title,
    this.value,
  });

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppColors.forest,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (value != null)
          Text(
            value!,
            style: const TextStyle(
              color: AppColors.forestLight,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _SmallRadiusChip extends StatelessWidget {
  const _SmallRadiusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.forest,
      backgroundColor: AppColors.paper,
      side: BorderSide(
        color: selected
            ? AppColors.forest
            : AppColors.line,
      ),
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : AppColors.forest,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ============================================================
// 추천 코스 결과
// ============================================================

class _RouteResult extends StatelessWidget {
  const _RouteResult({
    required this.controller,
    required this.transport,
    required this.chatController,
    required this.onReset,
  });

  final AppController controller;
  final String transport;
  final TextEditingController chatController;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final route = controller.routePlan;

    if (route == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1E8D7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF1E8D7),
          surfaceTintColor: Colors.transparent,
          title: const Text(
            '추천 코스',
            style: TextStyle(
              fontFamily: 'MaruBuri',
              color: AppColors.forest,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: EmptyState(
          icon: Icons.route_outlined,
          title: '코스를 불러오지 못했어요',
          description: '조건을 다시 확인하고 코스를 만들어주세요.',
          actionLabel: '조건 다시 설정',
          onAction: onReset,
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E8D7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '추천 코스',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: AppColors.forest,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: controller.isRouteSaved(route.id)
                ? '코스 저장 해제'
                : '코스 저장',
            onPressed: controller.toggleSaveCurrentRoute,
            icon: Icon(
              controller.isRouteSaved(route.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: AppColors.forest,
            ),
          ),
          IconButton(
            tooltip: '다른 코스 보기',
            onPressed: controller.isUpdatingRoute
                ? null
                : () => controller.refreshRoute(
              reason: 'user_requested_new_route',
            ),
            icon: const Icon(
              Icons.refresh,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          126,
        ),
        children: [
          _StableRouteSummary(route: route),

          if (controller.routeMessage != null &&
              controller.routeMessage !=
                  '조건에 맞는 한적한 코스를 만들었어요.') ...[
            const SizedBox(height: 12),
            _MessageCard(
              message: controller.routeMessage!,
              onClose: controller.clearRouteMessage,
            ),
          ],

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: controller.isSharingRoute
                      ? null
                      : () => _showCompanionSheet(
                    context,
                    controller,
                  ),
                  icon: const Icon(Icons.group_outlined),
                  label: const Text('동행 관리'),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.tune),
                  label: const Text('조건 수정'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 25),

          const SectionHeader(
            title: '코스 일정',
          ),

          const SizedBox(height: 12),

          if (route.stops.isEmpty)
            const EmptyState(
              icon: Icons.location_off_outlined,
              title: '추천된 장소가 없어요',
              description: '테마나 여행 시간, 포함 장소를 바꿔 다시 만들어보세요.',
            )
          else
            ...route.stops.asMap().entries.map(
                  (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _StableRouteStopCard(
                  index: entry.key + 1,
                  stop: entry.value,
                  transport: transport,
                  onDetail: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlaceDetailScreen(
                        place: entry.value.place,
                      ),
                    ),
                  ),
                  onReplace: controller.isUpdatingRoute
                      ? null
                      : () => controller.replaceRouteStop(
                    entry.value,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 12),

          ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.only(bottom: 12),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: const Icon(
              Icons.auto_awesome,
              color: AppColors.forest,
            ),
            title: const Text(
              '코스를 조금 바꾸고 싶어요',
              style: TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: const Text(
              '예: 첨성대 가고 싶어 · 카페 하나 빼줘',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 10.5,
              ),
            ),
            children: [
              TextField(
                controller: chatController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '코스 수정 요청을 입력하세요',
                  suffixIcon: IconButton(
                    onPressed: controller.isUpdatingRoute
                        ? null
                        : () async {
                      final message = chatController.text.trim();
                      if (message.isEmpty) return;

                      FocusScope.of(context).unfocus();
                      await controller.modifyRoute(message);
                      chatController.clear();
                    },
                    icon: controller.isUpdatingRoute
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          OutlinedButton.icon(
            onPressed: controller.isUpdatingRoute
                ? null
                : () => controller.refreshRoute(
              reason: 'user_requested_new_route',
            ),
            icon: const Icon(Icons.shuffle),
            label: const Text('같은 조건으로 다른 코스 보기'),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: const BoxDecoration(
            color: Color(0xFFF1E8D7),
            border: Border(
              top: BorderSide(color: Color(0xFFD9CDBE)),
            ),
          ),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: route.stops.isEmpty
                  ? null
                  : controller.startTrip,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                '이 코스로 여행 시작',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StableRouteSummary extends StatelessWidget {
  const _StableRouteSummary({required this.route});

  final RoutePlan route;

  @override
  Widget build(BuildContext context) {
    final congestion =
    (100 - route.averageQuietScore).clamp(0, 100).toInt();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD9CDBE),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EFE8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: AppColors.forest,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  '추천된 여행 코스',
                  style: TextStyle(
                    fontFamily: 'WantedSans',
                    color: AppColors.forest,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            route.title.trim().isEmpty
                ? '한적한 경주 추천 코스'
                : route.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'MaruBuri',
              color: AppColors.forest,
              fontSize: 20,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (route.summary.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              route.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'WantedSans',
                color: AppColors.muted,
                fontSize: 10.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(
            height: 1,
            color: Color(0xFFE8DED0),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StableStat(
                  icon: Icons.place_outlined,
                  label: '장소',
                  value: '${route.stops.length}곳',
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _StableStat(
                  icon: Icons.schedule_outlined,
                  label: '예상 시간',
                  value: _safeDuration(route.totalMinutes),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _StableStat(
                  icon: Icons.groups_2_outlined,
                  label: '평균 혼잡도',
                  value: '$congestion%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StableStat extends StatelessWidget {
  const _StableStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5ECDC),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 17,
            color: AppColors.forest,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'WantedSans',
              color: Color(0xFF3E3127),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'WantedSans',
              color: AppColors.muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StableRouteStopCard extends StatelessWidget {
  const _StableRouteStopCard({
    required this.index,
    required this.stop,
    required this.transport,
    required this.onDetail,
    required this.onReplace,
  });

  final int index;
  final RouteStop stop;
  final String transport;
  final VoidCallback onDetail;
  final VoidCallback? onReplace;

  @override
  Widget build(BuildContext context) {
    final place = stop.place;
    final congestion =
    (100 - place.quietScore).clamp(0, 100).toInt();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onDetail,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.forest,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name.trim().isEmpty
                              ? '추천 장소'
                              : place.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${place.category} · 혼잡도 $congestion%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (place.isEvent) ...[
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  '행사',
                                  style: TextStyle(
                                    color: AppColors.gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (place.eventPeriodLabel.isNotEmpty)
                                Text(
                                  place.eventPeriodLabel,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (place.eventTimeLabel.isNotEmpty)
                                Text(
                                  place.eventTimeType == 'fixed'
                                      ? '고정 ${place.eventTimeLabel}'
                                      : place.eventTimeLabel,
                                  style: const TextStyle(
                                    color: AppColors.forest,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                          if (place.eventPlace.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              '행사 장소 · ${place.eventPlace.trim()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                        if (
                        place.category == '맛집' ||
                            place.category == '카페'
                        ) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (_arrivalLabel(
                                stop.arrivalTime,
                              ).isNotEmpty)
                                '도착 ${_arrivalLabel(stop.arrivalTime)}',
                              if (
                              place.breakTime
                                  .trim()
                                  .isNotEmpty
                              )
                                '브레이크 ${place.breakTime.trim()}',
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${stop.stayMinutes}분',
                        style: const TextStyle(
                          color: AppColors.forest,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      IconButton(
                        tooltip: '이 장소 바꾸기',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 34,
                          minHeight: 34,
                        ),
                        onPressed: onReplace,
                        icon: Icon(
                          onReplace == null
                              ? Icons.hourglass_top_rounded
                              : Icons.swap_horiz_rounded,
                          size: 22,
                          color: onReplace == null
                              ? AppColors.muted
                              : AppColors.forest,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (place.address.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        place.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _arrivalLabel(String value) {
  final text = value.trim();

  if (text.isEmpty) {
    return '';
  }

  final parsed = DateTime.tryParse(text);

  if (parsed != null) {
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // 백엔드가 HH:mm 형태를 보낸 경우에도 24시간제로 정규화.
  final match = RegExp(
    r'(^|\\s)([01]?\\d|2[0-3]):([0-5]\\d)',
  ).firstMatch(text);

  if (match == null) {
    return '';
  }

  final hour = int.parse(match.group(2)!).toString().padLeft(2, '0');
  final minute = match.group(3)!;

  return '$hour:$minute';
}


String _safeDuration(int minutes) {
  if (minutes <= 0) return '정보 없음';

  final hours = minutes ~/ 60;
  final remain = minutes % 60;

  if (hours == 0) return '$remain분';
  if (remain == 0) return '$hours시간';
  return '$hours시간 $remain분';
}

Future<void> _showCompanionSheet(
    BuildContext context,
    AppController controller,
    ) async {
  await controller.loadFriends(silent: true);
  if (!context.mounted) return;

  final codeController = TextEditingController();
  final selectedCodes = <String>{};

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(26),
      ),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final shared = controller.sharedRoute;
          final existingCodes = shared?.members
              .map(
                (member) =>
                member.memberCode.toUpperCase(),
          )
              .toSet() ??
              <String>{};

          final acceptedFriends = controller.friends
              .where((friendship) => friendship.isAccepted)
              .toList();

          Future<void> addCode(String code) async {
            final normalized = code.trim().toUpperCase();
            if (normalized.isEmpty) return;

            final added =
            await controller.addCompanionByCode(normalized);
            if (!context.mounted) return;

            setModalState(() {});
            showAppSnackBar(
              context,
              controller.sharedRouteMessage ??
                  controller.friendMessage ??
                  (added
                      ? '동행을 추가했어요.'
                      : '친구 요청을 확인해 주세요.'),
            );
          }

          Future<void> addSelectedFriends() async {
            if (selectedCodes.isEmpty) return;

            var addedCount = 0;

            for (final friendship in acceptedFriends) {
              final code =
              friendship.user.memberCode.toUpperCase();

              if (!selectedCodes.contains(code) ||
                  existingCodes.contains(code)) {
                continue;
              }

              final added =
              await controller.addCompanionFriend(friendship);

              if (added) {
                addedCount += 1;
              }
            }

            selectedCodes.clear();

            if (!context.mounted) return;
            setModalState(() {});

            showAppSnackBar(
              context,
              addedCount > 0
                  ? '$addedCount명의 친구를 동행으로 추가했어요.'
                  : '추가할 친구를 다시 확인해 주세요.',
            );
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                18,
                18,
                MediaQuery.of(context).viewInsets.bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '동행 추가',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    if (acceptedFriends.isNotEmpty) ...[
                      Text(
                        '함께할 친구를 선택해주세요.',
                        style:
                        Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),

                      ...acceptedFriends.map((friendship) {
                        final code = friendship
                            .user.memberCode
                            .toUpperCase();
                        final alreadyAdded =
                        existingCodes.contains(code);
                        final selected =
                        selectedCodes.contains(code);

                        return Padding(
                          padding:
                          const EdgeInsets.only(bottom: 9),
                          child: Material(
                            color: Colors.white,
                            borderRadius:
                            BorderRadius.circular(17),
                            child: InkWell(
                              onTap: alreadyAdded ||
                                  controller.isSharingRoute
                                  ? null
                                  : () {
                                setModalState(() {
                                  if (selected) {
                                    selectedCodes.remove(code);
                                  } else {
                                    selectedCodes.add(code);
                                  }
                                });
                              },
                              borderRadius:
                              BorderRadius.circular(17),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: AppColors.sage,
                                      foregroundColor: AppColors.forest,
                                      child: Text(
                                        friendship.user.nickname.isEmpty
                                            ? '?'
                                            : friendship.user.nickname
                                            .substring(0, 1),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            friendship.user.nickname,
                                            style: const TextStyle(
                                              fontWeight:
                                              FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            friendship.user.memberCode,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (alreadyAdded)
                                      const Chip(
                                        label: Text('추가됨'),
                                      )
                                    else
                                      Checkbox(
                                        value: selected,
                                        onChanged:
                                        controller.isSharingRoute
                                            ? null
                                            : (_) {
                                          setModalState(() {
                                            if (selected) {
                                              selectedCodes
                                                  .remove(code);
                                            } else {
                                              selectedCodes
                                                  .add(code);
                                            }
                                          });
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: selectedCodes.isEmpty ||
                              controller.isSharingRoute
                              ? null
                              : addSelectedFriends,
                          icon: const Icon(
                            Icons.group_add_outlined,
                          ),
                          label: Text(
                            selectedCodes.isEmpty
                                ? '친구를 선택해주세요'
                                : '선택한 친구 추가 (${selectedCodes.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '아직 추가된 친구가 없어요.',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '친구를 추가한 뒤 함께 코스를 이용할 수 있어요.',
                        style:
                        Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),

                      TextField(
                        controller: codeController,
                        textCapitalization:
                        TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: '회원코드로 친구 추가',
                          hintText: 'GJ-XXXXXX',
                          prefixIcon: const Icon(
                            Icons.person_add_alt_1,
                          ),
                          suffixIcon: IconButton(
                            onPressed: controller.isSharingRoute
                                ? null
                                : () => addCode(
                              codeController.text,
                            ),
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ),
                        onSubmitted: addCode,
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.isSharingRoute
                                  ? null
                                  : () async {
                                final code = await Navigator.of(
                                  context,
                                ).push<String>(
                                  MaterialPageRoute<String>(
                                    builder: (_) =>
                                    const QrScannerScreen(),
                                  ),
                                );

                                if (code != null &&
                                    context.mounted) {
                                  codeController.text = code;
                                  await addCode(code);
                                }
                              },
                              icon: const Icon(
                                Icons.qr_code_scanner,
                              ),
                              label: const Text('QR로 추가'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: controller.isSharingRoute
                                  ? null
                                  : () async {
                                final invite = await controller
                                    .createRouteCompanionInvite();

                                if (invite == null ||
                                    !context.mounted) {
                                  return;
                                }

                                final box = context
                                    .findRenderObject() as RenderBox?;
                                final origin = box == null
                                    ? null
                                    : box.localToGlobal(
                                  Offset.zero,
                                ) &
                                box.size;

                                await KakaoInviteService()
                                    .shareRouteInvite(
                                  invite: invite,
                                  inviterNickname: controller
                                      .currentUser?.nickname ??
                                      '경주한적 사용자',
                                  routeTitle:
                                  controller.routePlan?.title ??
                                      '경주 추천 코스',
                                  sharePositionOrigin: origin,
                                );
                              },
                              icon: const Icon(
                                Icons.chat_bubble_outline,
                              ),
                              label: const Text('카카오 초대'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  codeController.dispose();
}

class _RouteCompanionCard extends StatelessWidget {
  const _RouteCompanionCard({
    required this.controller,
    required this.onAdd,
  });

  final AppController controller;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final shared = controller.sharedRoute;
    final userId = controller.userId;
    final companions = shared?.members
        .where((member) => member.userId != userId)
        .toList() ??
        const <SharedRouteMember>[];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: AppColors.sage,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '동행',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      companions.isEmpty
                          ? '이 코스를 함께 볼 동행을 추가해보세요.'
                          : '${companions.length}명의 동행과 공유 중이에요.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: controller.isSharingRoute ? null : onAdd,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('추가'),
              ),
            ],
          ),

          if (companions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: companions
                  .map(
                    (member) => Chip(
                  avatar: CircleAvatar(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    child: Text(
                      member.nickname.isEmpty
                          ? '?'
                          : member.nickname.substring(0, 1),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  label: Text(member.nickname),
                ),
              )
                  .toList(),
            ),
          ],

          if (shared != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.sync,
                  size: 16,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '공유 버전 ${shared.version} · 동행이 코스를 수정했다면 최신 상태를 불러올 수 있어요.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: controller.isSharingRoute
                      ? null
                      : controller.reloadSharedRoute,
                  child: const Text('동기화'),
                ),
              ],
            ),
          ],

          if (controller.sharedRouteMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              controller.sharedRouteMessage!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.forest,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class _RouteHero
    extends StatelessWidget {
  const _RouteHero({
    required this.route,
  });

  final RoutePlan route;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.all(23),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(27),
        gradient:
        const LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment
              .bottomRight,
          colors: [
            Color(0xFF284D43),
            Color(0xFF4B7769),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color:
            Color(0x30233A31),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Text(
            '오늘의 추천 코스',
            style: TextStyle(
              color:
              Color(0xFFE7D5B2),
              fontSize: 11,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 9,
          ),

          Text(
            route.title,
            style:
            const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight:
              FontWeight.w900,
              letterSpacing:
              -0.8,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            route.summary,
            style:
            const TextStyle(
              color:
              Color(
                0xC8FFFFFF,
              ),
              fontSize: 12,
              height: 1.55,
            ),
          ),

          if (route
              .weatherSummary
              .isNotEmpty) ...[
            const SizedBox(
              height: 10,
            ),

            Row(
              children: [
                const Icon(
                  Icons
                      .cloud_outlined,
                  size: 16,
                  color:
                  Color(
                    0xFFE7D5B2,
                  ),
                ),

                const SizedBox(
                  width: 6,
                ),

                Expanded(
                  child: Text(
                    route
                        .weatherSummary,
                    style:
                    const TextStyle(
                      color:
                      Color(
                        0xFFE7D5B2,
                      ),
                      fontSize: 11,
                      fontWeight:
                      FontWeight
                          .w700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(
            height: 19,
          ),

          Row(
            children: [
              Expanded(
                child: _Stat(
                  value:
                  '${route.stops.length}곳',
                  label: '방문 장소',
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: _Stat(
                  value:
                  _durationLabel(
                    route
                        .totalMinutes,
                  ),
                  label: '예상 시간',
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child: _Stat(
                  value:
                  '${route.totalDistanceKm.toStringAsFixed(1)}km',
                  label: '총 이동',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _durationLabel(
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
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color:
        Colors.white.withValues(
          alpha: 0.10,
        ),
        borderRadius:
        BorderRadius.circular(15),
        border: Border.all(
          color:
          Colors.white.withValues(
            alpha: 0.08,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style:
            const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight:
              FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          Text(
            label,
            style:
            const TextStyle(
              color:
              Color(
                0xAFFFFFFF,
              ),
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 코스 개별 장소 카드
// ============================================================


String _formatArrivalTime(String raw) {
  final value = raw.trim();

  if (value.isEmpty) {
    return '';
  }

  final parsed = DateTime.tryParse(value);

  if (parsed != null) {
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute 도착';
  }

  final timeMatch = RegExp(
    r'(^|\\s)([01]?\\d|2[0-3]):([0-5]\\d)',
  ).firstMatch(value);

  if (timeMatch == null) {
    return value;
  }

  final hour = int.parse(timeMatch.group(2)!).toString().padLeft(2, '0');
  final minute = timeMatch.group(3)!;

  return '$hour:$minute 도착';
}


String _transportLabel(String transport) {
  switch (transport) {
    case 'walking':
      return '도보';
    case 'public_transport':
      return '대중교통';
    case 'driving':
    default:
      return '자동차';
  }
}

String _paidLabel(Place place) {
  return place.isPaid ? '유료 관광지' : '무료 관광지';
}

String _recommendationReason(RouteStop stop) {
  final congestion = _congestionPercent(stop.place);

  if (congestion <= 20) {
    return '현재 비교적 매우 한산한 편이라 여유롭게 둘러보기 좋은 장소예요.';
  }
  if (congestion <= 40) {
    return '현재 비교적 한산한 편이라 코스에 넣기 좋은 장소예요.';
  }
  if (congestion <= 60) {
    return '현재 혼잡도가 보통 수준이라 이동 동선과 함께 고려해 추천했어요.';
  }
  if (congestion <= 80) {
    return '조금 붐빌 수 있지만 코스 동선과 선호 조건을 고려해 포함했어요.';
  }

  return '현재 혼잡도가 높은 편이라 방문 전 블로그와 영상을 확인해보는 것을 권장해요.';
}

class _RouteStopCard extends StatelessWidget {
  const _RouteStopCard({
    required this.stop,
    required this.isLast,
    required this.transport,
    required this.onTap,
    required this.onNavigate,
    required this.onBlog,
    required this.onYouTube,
  });

  final RouteStop stop;
  final bool isLast;
  final String transport;
  final VoidCallback onTap;
  final VoidCallback onNavigate;
  final VoidCallback onBlog;
  final VoidCallback onYouTube;

  @override
  Widget build(BuildContext context) {
    final place = stop.place;
    final congestion = _congestionPercent(place);
    final arrival = _formatArrivalTime(stop.arrivalTime);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.goldLight,
                    ),
                  ),
                  child: Text(
                    '${stop.order}'.padLeft(2, '0'),
                    style: const TextStyle(
                      color: AppColors.forest,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.goldLight,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Ink(
                padding: const EdgeInsets.all(14),
                decoration: softCardDecoration(
                  radius: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: SizedBox(
                              width: 84,
                              height: 84,
                              child: PlaceImage(
                                place: place,
                                hero: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        place.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _CongestionBadge(
                                      score: congestion,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (place.category.trim().isNotEmpty)
                                  Text(
                                    place.category,
                                    style: const TextStyle(
                                      color: AppColors.forest,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                const SizedBox(height: 5),
                                Text(
                                  place.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _InfoPill(
                          icon: Icons.schedule_outlined,
                          text: '${stop.stayMinutes}분 체류',
                        ),
                        _InfoPill(
                          icon: Icons.confirmation_number_outlined,
                          text: _paidLabel(place),
                        ),
                        if (arrival.isNotEmpty)
                          _InfoPill(
                            icon: Icons.access_time_rounded,
                            text: arrival,
                          ),
                      ],
                    ),

                    if (place.address.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              place.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF4F0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            color: AppColors.forest,
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '추천 이유',
                                  style: TextStyle(
                                    color: AppColors.forest,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _recommendationReason(stop),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodySmall?.copyWith(
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Icon(
                          Icons.route_outlined,
                          color: AppColors.forest,
                          size: 17,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${_transportLabel(transport)} · ${stop.transportInstruction}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forestLight,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onBlog,
                            icon: const Icon(
                              Icons.article_outlined,
                              size: 17,
                            ),
                            label: const Text(
                              '블로그 보기',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onYouTube,
                            icon: const Icon(
                              Icons.play_circle_outline_rounded,
                              size: 17,
                            ),
                            label: const Text(
                              'YouTube',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onTap,
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          '관광지 상세정보 보기',
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton.icon(
                        onPressed: onNavigate,
                        icon: const Icon(
                          Icons.navigation_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          '카카오맵으로 길안내 시작',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.sage.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: AppColors.forest,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.forest,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CongestionBadge extends StatelessWidget {
  const _CongestionBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final color = _congestionColor(score);
    final textColor = score >= 41 && score <= 60
        ? const Color(0xFF3A3520)
        : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '혼잡 $score%',
        style: TextStyle(
          color: textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniPill
    extends StatelessWidget {
  const _MiniPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
        const Color(
          0xFFEEF4F0,
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
          AppColors
              .forestLight,
          fontSize: 9.5,
          fontWeight:
          FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageCard
    extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.onClose,
  });

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.fromLTRB(
        14,
        10,
        7,
        10,
      ),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius:
        BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons
                .check_circle_outline,
            color:
            AppColors.forest,
            size: 19,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Text(
              message,
              style:
              const TextStyle(
                fontSize: 11.5,
                color:
                AppColors
                    .forest,
                fontWeight:
                FontWeight
                    .w700,
              ),
            ),
          ),

          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 여행 완료 화면
// ============================================================

class _TripCompletedView
    extends StatelessWidget {
  const _TripCompletedView({
    required this.trip,
    required this.onCreateNewRoute,
    this.onReviewCourse,
  });

  final CompletedTrip trip;
  final VoidCallback onCreateNewRoute;
  final ValueChanged<CompletedTrip>? onReviewCourse;

  @override
  Widget build(
      BuildContext context,
      ) {
    final route =
        trip.route;

    final local =
    trip.completedAt.toLocal();

    final date =
        '${local.year}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.day.toString().padLeft(2, '0')}';

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFFF1E8D7),
          surfaceTintColor:
          Colors.transparent,
          title: const Text(
            '여행 완료',
            style: TextStyle(
              fontFamily: 'MaruBuri',
              color: AppColors.forest,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),

        SliverPadding(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            22,
            18,
            112,
          ),
          sliver:
          SliverList.list(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFCF8),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFFD9CDBE),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE4EFE8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.forest,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '오늘의 경주 여행 완료!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'MaruBuri',
                        color: AppColors.forest,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      route.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'WantedSans',
                        color: AppColors.muted,
                        fontSize: 11,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Row(
                      children: [
                        Expanded(
                          child: _CompletedStat(
                            value: '${route.stops.length}곳',
                            label: '방문 완료',
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _CompletedStat(
                            value: _completedDurationLabel(
                              route.totalMinutes,
                            ),
                            label: '여행 시간',
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: _CompletedStat(
                            value:
                            '${route.totalDistanceKm.toStringAsFixed(1)}km',
                            label: '총 이동',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$date 완료',
                      style: const TextStyle(
                        fontFamily: 'WantedSans',
                        color: AppColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              Container(
                padding:
                const EdgeInsets.all(
                  17,
                ),
                decoration:
                softCardDecoration(
                  radius: 20,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                      BoxDecoration(
                        color:
                        AppColors.sage,
                        borderRadius:
                        BorderRadius.circular(
                          15,
                        ),
                      ),
                      child:
                      const Icon(
                        Icons
                            .bookmark_added_outlined,
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
                          const Text(
                            '저장 완료',
                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight.w900,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),

                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              const SectionHeader(
                title:
                '오늘 다녀온 곳',
              ),

              const SizedBox(
                height: 12,
              ),

              ...route.stops.map(
                    (stop) =>
                    Container(
                      margin:
                      const EdgeInsets.only(
                        bottom: 9,
                      ),
                      padding:
                      const EdgeInsets.all(
                        13,
                      ),
                      decoration:
                      softCardDecoration(
                        radius: 17,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor:
                            AppColors.sage,
                            foregroundColor:
                            AppColors.forest,
                            child: Text(
                              '${stop.order}',
                              style:
                              const TextStyle(
                                fontWeight:
                                FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  stop.place.name,
                                  style:
                                  const TextStyle(
                                    fontWeight:
                                    FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  '${stop.place.category} · '
                                      '혼잡도 ${100 - stop.place.quietScore}%',
                                  style:
                                  Theme.of(
                                    context,
                                  ).textTheme
                                      .bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons
                                .check_circle,
                            color:
                            AppColors.forest,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
              ),

              const SizedBox(
                height: 15,
              ),

              OutlinedButton.icon(
                onPressed: onReviewCourse == null
                    ? null
                    : () => onReviewCourse!(trip),
                icon: const Icon(Icons.rate_review_outlined),
                label: const Text('코스 평가하기'),
              ),

              const SizedBox(height: 10),

              FilledButton.icon(
                onPressed:
                onCreateNewRoute,
                icon:
                const Icon(
                  Icons
                      .add_road_outlined,
                ),
                label:
                const Text(
                  '새 코스 만들기',
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Container(
                padding:
                const EdgeInsets.all(
                  13,
                ),
                decoration:
                BoxDecoration(
                  color:
                  AppColors.cream,
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                  border:
                  Border.all(
                    color:
                    AppColors.goldLight,
                  ),
                ),
                child: Text(
                  '완료한 코스 기록은 하단의 저장 탭 → 완료 코스에서 확인할 수 있어요.',
                  textAlign:
                  TextAlign.center,
                  style:
                  Theme.of(
                    context,
                  ).textTheme
                      .bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletedStat extends StatelessWidget {
  const _CompletedStat({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 66),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5ECDC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'WantedSans',
              color: Color(0xFF3E3127),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'WantedSans',
              color: AppColors.muted,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _completedDurationLabel(
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

// ============================================================
// 여행 진행 화면
// ============================================================

class _TripView
    extends StatelessWidget {
  const _TripView({
    required this.controller,
    required this.transport,
  });

  final AppController controller;

  final String transport;

  @override
  Widget build(BuildContext context) {
    final route =
    controller.routePlan!;

    final index =
    controller.currentStopIndex
        .clamp(
      0,
      route.stops.length - 1,
    )
        .toInt();

    final stop =
    route.stops[index];

    final place =
        stop.place;

    final progress =
        (index + 1) /
            route.stops.length;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFFF1E8D7),
          surfaceTintColor:
          Colors.transparent,
          title: const Text(
            '여행 진행',
            style: TextStyle(
              fontFamily: 'MaruBuri',
              color: AppColors.forest,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),

          leading: IconButton(
            onPressed: () =>
                _confirmStop(context),
            icon:
            const Icon(
              Icons.close,
            ),
          ),

          actions: [
            IconButton(
              tooltip:
              '혼잡도 다시 확인',
              onPressed:
              controller
                  .isUpdatingRoute
                  ? null
                  : controller
                  .recheckTripCongestion,
              icon: const Icon(
                Icons.sync,
                color:
                AppColors.forest,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),

        SliverPadding(
          padding:
          const EdgeInsets.fromLTRB(
            18,
            8,
            18,
            112,
          ),
          sliver: SliverList.list(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${index + 1} / ${route.stops.length}번째 장소',
                      style:
                      const TextStyle(
                        color:
                        AppColors
                            .forest,
                        fontWeight:
                        FontWeight
                            .w900,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  Text(
                    '${(progress * 100).round()}%',
                    style:
                    Theme.of(
                      context,
                    ).textTheme.bodySmall,
                  ),
                ],
              ),

              const SizedBox(
                height: 8,
              ),

              ClipRRect(
                borderRadius:
                BorderRadius.circular(
                  999,
                ),
                child:
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor:
                  AppColors.sage,
                  color:
                  AppColors.gold,
                ),
              ),

              if (controller
                  .routeMessage !=
                  null) ...[
                const SizedBox(
                  height: 14,
                ),

                _MessageCard(
                  message:
                  controller
                      .routeMessage!,
                  onClose:
                  controller
                      .clearRouteMessage,
                ),
              ],

              const SizedBox(
                height: 19,
              ),

              Container(
                decoration:
                softCardDecoration(
                  radius: 27,
                ),
                clipBehavior:
                Clip.antiAlias,
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    SizedBox(
                      height: 230,
                      child: Stack(
                        fit:
                        StackFit.expand,
                        children: [
                          PlaceImage(
                            place: place,
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
                                    0x80162922,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            left: 14,
                            top: 14,
                            child:
                            QuietBadge(
                              score:
                              place.quietScore,
                            ),
                          ),

                          Positioned(
                            left: 18,
                            right: 18,
                            bottom: 17,
                            child: Text(
                              place.name,
                              style:
                              const TextStyle(
                                fontFamily: 'MaruBuri',
                                color:
                                Colors.white,
                                fontSize:
                                25,
                                fontWeight:
                                FontWeight.w700,
                                letterSpacing:
                                -0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding:
                      const EdgeInsets.all(
                        18,
                      ),
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons
                                    .route_outlined,
                                color:
                                AppColors
                                    .forest,
                                size: 19,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child: Text(
                                  stop.transportInstruction,
                                  style:
                                  const TextStyle(
                                    fontWeight:
                                    FontWeight.w700,
                                    fontSize:
                                    12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 11,
                          ),

                          Text(
                            place.description,
                            maxLines: 3,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style:
                            Theme.of(
                              context,
                            ).textTheme.bodyMedium,
                          ),

                          const SizedBox(
                            height: 14,
                          ),

                          // --------------------------------
                          // 블로그 / YouTube로 먼저 탐색
                          // --------------------------------

                          Row(
                            children: [
                              Expanded(
                                child:
                                OutlinedButton.icon(
                                  onPressed:
                                      () async {
                                    await _openPlaceContents(
                                      context:
                                      context,
                                      controller:
                                      controller,
                                      place:
                                      place,
                                      kind:
                                      'blog',
                                    );
                                  },
                                  icon:
                                  const Icon(
                                    Icons
                                        .article_outlined,
                                  ),
                                  label:
                                  const Text(
                                    '블로그',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child:
                                OutlinedButton.icon(
                                  onPressed:
                                      () async {
                                    await _openPlaceContents(
                                      context:
                                      context,
                                      controller:
                                      controller,
                                      place:
                                      place,
                                      kind:
                                      'youtube',
                                    );
                                  },
                                  icon:
                                  const Icon(
                                    Icons
                                        .play_circle_outline_rounded,
                                  ),
                                  label:
                                  const Text(
                                    'YouTube',
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          // --------------------------------
                          // 카카오맵 길안내
                          // --------------------------------

                          SizedBox(
                            width:
                            double.infinity,
                            child:
                            FilledButton.icon(
                              onPressed:
                                  () async {
                                await _openKakaoMapRoute(
                                  context:
                                  context,
                                  startLatitude:
                                  controller
                                      .latitude,
                                  startLongitude:
                                  controller
                                      .longitude,
                                  destination:
                                  place,
                                  transport:
                                  transport,
                                );
                              },
                              icon:
                              const Icon(
                                Icons
                                    .navigation_rounded,
                              ),
                              label:
                              const Text(
                                '카카오맵으로 길안내 시작',
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          SizedBox(
                            width:
                            double.infinity,
                            child:
                            OutlinedButton.icon(
                              onPressed:
                                  () {
                                Navigator.of(
                                  context,
                                ).push(
                                  MaterialPageRoute<void>(
                                    builder:
                                        (_) =>
                                        PlaceDetailScreen(
                                          place:
                                          place,
                                        ),
                                  ),
                                );
                              },
                              icon:
                              const Icon(
                                Icons
                                    .info_outline,
                              ),
                              label:
                              const Text(
                                '장소 상세정보와 콘텐츠 보기',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (place
                  .etiquette
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 18,
                ),

                Container(
                  padding:
                  const EdgeInsets.all(
                    17,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    AppColors
                        .cream,
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                    border:
                    Border.all(
                      color:
                      AppColors
                          .goldLight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons
                                .notifications_active_outlined,
                            color:
                            AppColors
                                .gold,
                            size: 20,
                          ),

                          SizedBox(
                            width: 8,
                          ),

                          Text(
                            '이 장소에서 기억할 점',
                            style:
                            TextStyle(
                              fontWeight:
                              FontWeight
                                  .w900,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 10,
                      ),

                      ...place.etiquette.map(
                            (tip) =>
                            Padding(
                              padding:
                              const EdgeInsets.only(
                                bottom:
                                7,
                              ),
                              child: Text(
                                '• $tip',
                                style:
                                Theme.of(
                                  context,
                                ).textTheme.bodyMedium,
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(
                height: 18,
              ),

              Container(
                padding:
                const EdgeInsets.all(
                  15,
                ),
                decoration:
                BoxDecoration(
                  color:
                  const Color(
                    0xFFEEF4F0,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.update,
                      color:
                      AppColors
                          .forest,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Text(
                        '혼잡도 자동 확인',
                        style:
                        Theme.of(
                          context,
                        ).textTheme.bodySmall,
                      ),
                    ),

                    TextButton(
                      onPressed:
                      controller
                          .isUpdatingRoute
                          ? null
                          : controller
                          .recheckTripCongestion,
                      child:
                      const Text(
                        '지금 확인',
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              FilledButton.icon(
                onPressed:
                controller.isUpdatingRoute ||
                    controller.isCompletingStop
                    ? null
                    : () async {
                  final wasLast =
                      index ==
                          route.stops.length - 1;

                  await controller
                      .completeCurrentStop();

                  if (!context.mounted) {
                    return;
                  }

                  if (wasLast &&
                      controller.tripJustCompleted) {
                    showAppSnackBar(
                      context,
                      '여행 완료! 이 코스를 저장 탭에 보관했어요.',
                    );
                  }
                },
                icon: controller.isCompletingStop
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  index ==
                      route
                          .stops
                          .length -
                          1
                      ? Icons.flag_outlined
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  index ==
                      route
                          .stops
                          .length -
                          1
                      ? '마지막 장소 방문 완료'
                      : '이 장소 방문 완료',
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              OutlinedButton.icon(
                onPressed:
                controller
                    .isUpdatingRoute
                    ? null
                    : () =>
                    controller
                        .refreshRoute(
                      reason:
                      'user_requested_alternative_during_trip',
                    ),
                icon: const Icon(
                  Icons.alt_route,
                ),
                label: const Text(
                  '혼잡해서 다른 코스로 바꾸기',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmStop(
      BuildContext context,
      ) async {
    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title:
            const Text(
              '여행 안내를 종료할까요?',
            ),
            content:
            const Text(
              '현재 코스는 남아 있으므로 나중에 다시 시작할 수 있어요.',
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      false,
                    ),
                child:
                const Text(
                  '계속하기',
                ),
              ),

              FilledButton(
                onPressed: () =>
                    Navigator.pop(
                      context,
                      true,
                    ),
                child:
                const Text(
                  '종료',
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      controller.stopTrip();
    }
  }
}