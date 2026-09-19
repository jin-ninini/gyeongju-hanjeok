import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_env.dart';
import '../core/app_theme.dart';
import '../models/place.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'place_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Place? _selected;
  List<Place>? _mapPlaces;
  Timer? _mapMoveDebounce;
  Timer? _searchDebounce;
  final TextEditingController _mapSearchController = TextEditingController();
  final GlobalKey<_KakaoWebMapState> _kakaoMapKey =
  GlobalKey<_KakaoWebMapState>();
  bool _isLoadingMovedArea = false;

  // 사용자의 실제 현재 위치와 "지도가 보고 있는 위치"는 다를 수 있습니다.
  // 검색 결과로 이동해도 AppController의 현재 위치는 바꾸지 않습니다.
  double? _mapFocusLatitude;
  double? _mapFocusLongitude;
  int _mapFocusRevision = 0;
  bool _userDraggingMap = false;
  int _mapAreaRequestVersion = 0;
  bool _locationUseAcceptedForSession = false;

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    _searchDebounce?.cancel();
    _mapSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final places = _mapPlaces ?? controller.places;
    final mapLatitude =
        _mapFocusLatitude ?? controller.latitude;
    final mapLongitude =
        _mapFocusLongitude ?? controller.longitude;

    if (places.isEmpty) {
      _selected = null;
    } else if (_selected != null) {
      final selectedId = _selected!.id;
      final matches =
      places.where((place) => place.id == selectedId).toList();

      _selected = matches.isEmpty ? null : matches.first;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: AppEnv.kakaoJavaScriptKey.isNotEmpty && !kIsWeb
                    ? _KakaoWebMap(
                  key: _kakaoMapKey,
                  places: places,
                  latitude: mapLatitude,
                  longitude: mapLongitude,
                  focusRevision: _mapFocusRevision,
                  width: width,
                  height: height,
                  onMarkerTap: (placeId) {
                    final matches = places.where(
                          (place) => place.id == placeId,
                    );

                    if (matches.isNotEmpty) {
                      setState(
                            () => _selected = matches.first,
                      );
                    }
                  },
                  onPlaceSearchResult: (result) async {
                    await _applyKakaoPlaceSearchResult(
                      controller,
                      result,
                    );
                  },
                  onMapDragStart: () {
                    _mapMoveDebounce?.cancel();
                    _userDraggingMap = true;
                  },
                  onMapIdle: (latitude, longitude) {
                    // 검색 결과/현재 위치로 코드가 panTo()한 경우에는
                    // 주변 장소를 다시 불러오지 않습니다.
                    // 사용자가 직접 지도를 드래그한 경우에만 갱신합니다.
                    if (!_userDraggingMap) {
                      return;
                    }

                    _userDraggingMap = false;

                    _scheduleMovedAreaLoad(
                      controller,
                      latitude,
                      longitude,
                    );
                  },
                )
                    : _PreviewMap(
                  places: places,
                  selectedId: _selected?.id,
                  onSelected: (place) {
                    setState(
                          () => _selected = place,
                    );
                  },
                ),
              ),

              // --------------------------------------------------
              // 상단 검색 영역
              // --------------------------------------------------
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFDF8)
                                  .withValues(alpha: 0.98),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD8B66A),
                                width: 1.1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x18000000),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _mapSearchController,
                              textInputAction: TextInputAction.search,
                              textAlignVertical: TextAlignVertical.center,
                              style: const TextStyle(
                                color: Color(0xFF4A382C),
                                fontSize: 14.0,
                                fontWeight: FontWeight.w700,
                              ),
                              onChanged: (_) {
                                // 입력 중에는 검색하지 않습니다.
                                // 검색 버튼/키보드 검색에서만 Kakao Places 검색을 실행합니다.
                                _searchDebounce?.cancel();
                              },
                              onSubmitted: (value) async {
                                _searchDebounce?.cancel();
                                await _searchAndFocusPlace(
                                  controller,
                                  value,
                                );
                              },
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '가고 싶은 관광지',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF8E8176),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                prefixIcon: const SizedBox(
                                  width: 50,
                                  height: 56,
                                  child: Center(
                                    child: Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF765844),
                                      size: 23,
                                    ),
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 50,
                                  maxWidth: 50,
                                  minHeight: 56,
                                  maxHeight: 56,
                                ),
                                suffixIcon: Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: TextButton(
                                    onPressed: () async {
                                      _searchDebounce?.cancel();
                                      FocusScope.of(context).unfocus();
                                      await _searchAndFocusPlace(
                                        controller,
                                        _mapSearchController.text,
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                      const Color(0xFF315E4F),
                                      backgroundColor: Colors.transparent,
                                      minimumSize: const Size(46, 36),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      '검색',
                                      style: TextStyle(
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                                suffixIconConstraints:
                                const BoxConstraints(minHeight: 56),
                                filled: false,
                                fillColor: Colors.transparent,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                disabledBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        IconButton.filled(
                          tooltip: '현재 위치',
                          onPressed: () async {
                            final allowed =
                            await _confirmCurrentLocationUse();

                            if (!allowed || !context.mounted) return;

                            final message =
                            await controller.useCurrentLocation();

                            if (!context.mounted) return;

                            setState(() {
                              // useCurrentLocation()이 새 위치 기준 장소를 이미
                              // controller.places에 다시 받아온 상태입니다.
                              _mapPlaces = controller.places;
                              _selected = null;
                              _mapFocusLatitude = controller.latitude;
                              _mapFocusLongitude = controller.longitude;
                              _mapFocusRevision += 1;
                            });

                            showAppSnackBar(
                              context,
                              message,
                            );
                          },
                          style: IconButton.styleFrom(
                            minimumSize: const Size(54, 54),
                            maximumSize: const Size(54, 54),
                            backgroundColor:
                            const Color(0xFFFDF9F0).withValues(alpha: 0.96),
                            foregroundColor: const Color(0xFF315E4F),
                            side: const BorderSide(
                              color: Color(0xFFD6B166),
                              width: 1.2,
                            ),
                            shadowColor: const Color(0x26000000),
                            elevation: 6,
                          ),
                          icon: const Icon(
                            Icons.my_location_rounded,
                            size: 21,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --------------------------------------------------
              // 혼잡도 색상 범례
              // 파랑 → 청록 → 노랑 → 주황 → 빨강
              // --------------------------------------------------
              Positioned(
                top: MediaQuery.paddingOf(context).top + 82,
                left: 22,
                right: 22,
                child: const _CongestionLegendBar(),
              ),

              if (AppEnv.kakaoJavaScriptKey.isEmpty)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 138,
                  left: 18,
                  right: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(
                        alpha: 0.95,
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.goldLight,
                      ),
                    ),
                    child: const Text(
                      'KAKAO_JAVASCRIPT_KEY를 입력하면 이 화면이 실제 카카오맵으로 전환됩니다.',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.muted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              if (_isLoadingMovedArea)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 137,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.forest,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '이 지역의 혼잡도를 불러오는 중',
                              style: TextStyle(
                                color: AppColors.forest,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // --------------------------------------------------
              // 선택된 장소 카드
              // --------------------------------------------------
              if (_selected != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 124,
                  child: _MapPlaceCard(
                    place: _selected!,
                    isSaved: controller.isSaved(
                      _selected!.id,
                    ),
                    onSaved: () {
                      controller.toggleSaved(
                        _selected!,
                      );
                    },
                    onDetail: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PlaceDetailScreen(
                            place: _selected!,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _confirmCurrentLocationUse() async {
    if (_locationUseAcceptedForSession) return true;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('현재 위치 사용'),
        content: const Text(
          '현재 위치를 사용하면 지도에서 내 위치를 확인하고 '
              '관광지까지의 거리를 계산할 수 있어요.\n\n'
              '현재 위치는 경주한적 서버로 전송하거나 저장하지 않으며, '
              '이 기능은 선택 사항이에요. 허용하지 않아도 다른 기능은 이용할 수 있어요.',
          style: TextStyle(height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('현재 위치 사용하기'),
          ),
        ],
      ),
    ) ??
        false;

    if (!mounted) return false;

    if (accepted) {
      setState(() {
        _locationUseAcceptedForSession = true;
      });
    }

    return accepted;
  }

  Future<void> _searchAndFocusPlace(
      AppController controller,
      String rawQuery,
      ) async {
    _mapMoveDebounce?.cancel();
    _mapAreaRequestVersion += 1;
    _userDraggingMap = false;

    final query = rawQuery.trim();

    if (query.isEmpty) {
      showAppSnackBar(
        context,
        '검색할 관광지 이름을 입력해주세요.',
      );
      return;
    }

    final kakaoMapState = _kakaoMapKey.currentState;

    if (kakaoMapState == null) {
      showAppSnackBar(
        context,
        '지도가 준비되는 중이에요. 잠시 후 다시 검색해주세요.',
      );
      return;
    }

    setState(() {
      _isLoadingMovedArea = true;
    });

    // 1단계: Kakao Places에서 관광지의 실제 위치를 찾습니다.
    await kakaoMapState.searchPlace(query);
  }

  Future<void> _applyKakaoPlaceSearchResult(
      AppController controller,
      Map<String, dynamic> result,
      ) async {
    if (!mounted) return;

    final status = (result['status'] ?? '').toString();

    if (status != 'ok') {
      setState(() {
        _isLoadingMovedArea = false;
      });

      final query = (result['query'] ?? _mapSearchController.text).toString();

      showAppSnackBar(
        context,
        '"$query" 카카오맵 검색 결과가 없어요.',
      );
      return;
    }

    final kakaoName = (result['name'] ?? '').toString().trim();
    final originalQuery = (result['query'] ?? '').toString().trim();
    final latitude = (result['latitude'] as num?)?.toDouble();
    final longitude = (result['longitude'] as num?)?.toDouble();

    if (kakaoName.isEmpty || latitude == null || longitude == null) {
      setState(() {
        _isLoadingMovedArea = false;
      });

      showAppSnackBar(
        context,
        '카카오맵 장소 정보를 읽지 못했어요.',
      );
      return;
    }

    // 검색 전에 예약돼 있던 지도 이동 조회가 검색 결과를 덮어쓰지 못하게 합니다.
    _mapMoveDebounce?.cancel();
    _mapAreaRequestVersion += 1;
    _userDraggingMap = false;

    // 지도 위치는 Kakao Places가 반환한 실제 좌표를 사용합니다.
    setState(() {
      _mapFocusLatitude = latitude;
      _mapFocusLongitude = longitude;
      _mapFocusRevision += 1;
    });

    String normalize(String value) {
      var result = value
          .toLowerCase()
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .replaceAll(RegExp(r'\[[^\]]*\]'), '')
          .replaceAll(RegExp(r'\s+'), '')
          .replaceAll(RegExp(r'[^0-9a-z가-힣]'), '');

      // 앱/TourAPI에서는 "경주 첨성대", Kakao에서는 "첨성대"처럼
      // 지역명이 붙는 차이가 있을 수 있으므로 비교용으로만 제거합니다.
      if (result.startsWith('경주시') && result.length > 3) {
        result = result.substring(3);
      } else if (result.startsWith('경주') && result.length > 2) {
        result = result.substring(2);
      }

      return result;
    }

    Place? matchByName(Iterable<Place> source) {
      final targets = <String>{
        normalize(kakaoName),
        if (originalQuery.isNotEmpty) normalize(originalQuery),
      }..removeWhere((value) => value.isEmpty);

      // 1순위: 완전 일치
      for (final place in source) {
        final name = normalize(place.name);
        if (targets.contains(name)) {
          return place;
        }
      }

      // 2순위: "경주첨성대 / 첨성대", 괄호·지점명 차이 같은 경우
      for (final place in source) {
        final name = normalize(place.name);
        if (name.isEmpty) continue;

        for (final target in targets) {
          if (target.length < 2) continue;

          if (name.contains(target) || target.contains(name)) {
            return place;
          }
        }
      }

      return null;
    }

    try {
      Place? matched;

      // 1단계:
      // 이미 지도에 표시된 장소카드 중 같은 이름이 있으면 즉시 선택합니다.
      final currentPool = <String, Place>{
        for (final place in _mapPlaces ?? const <Place>[]) place.id: place,
        for (final place in controller.places) place.id: place,
      }.values;

      matched = matchByName(currentPool);

      List<Place>? searchedAreaPlaces;

      // 2단계:
      // 현재 지도 목록에 없으면 Kakao가 찾은 좌표 주변의 관광지 카드를 불러옵니다.
      // 이 조회는 사용자 현재 GPS가 아니라 "검색된 관광지의 공개 좌표"를 기준으로
      // 단말에서 거리만 계산합니다.
      if (matched == null) {
        try {
          searchedAreaPlaces = await controller.fetchPlacesAt(
            latitude: latitude,
            longitude: longitude,
            radiusKm: 4,
          );

          matched = matchByName(searchedAreaPlaces);
        } catch (_) {
          searchedAreaPlaces = null;
        }
      }

      // 3단계:
      // 그래도 없으면 기존 백엔드 장소명 검색을 마지막 fallback으로 사용합니다.
      matched ??= await controller.findPlaceCardByName(
        kakaoName,
        originalQuery: originalQuery,
      );

      if (!mounted) return;

      if (matched == null) {
        setState(() {
          _isLoadingMovedArea = false;
        });

        showAppSnackBar(
          context,
          '카카오맵에서 "$kakaoName" 위치는 찾았지만 '
              '앱 관광지 목록에서 같은 이름의 장소카드를 찾지 못했어요.',
        );
        return;
      }

      // 검색된 위치 주변 목록을 가져온 경우에는 해당 지역 마커로 갱신하고,
      // 없으면 기존 지도 마커에 검색 장소만 추가합니다.
      final nextMapPlaces = searchedAreaPlaces != null &&
          searchedAreaPlaces.isNotEmpty
          ? <String, Place>{
        for (final place in searchedAreaPlaces) place.id: place,
        matched.id: matched,
      }.values.toList()
          : <String, Place>{
        for (final place in _mapPlaces ?? const <Place>[]) place.id: place,
        matched.id: matched,
      }.values.toList();

      setState(() {
        _mapPlaces = nextMapPlaces;
        _selected = matched;

        // 장소카드의 좌표가 조금 달라도 지도 중심은 Kakao 검색 좌표를 유지합니다.
        _mapFocusLatitude = latitude;
        _mapFocusLongitude = longitude;
        _mapFocusRevision += 1;
        _isLoadingMovedArea = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingMovedArea = false;
      });

      showAppSnackBar(
        context,
        '카카오맵 위치는 찾았지만 장소카드를 불러오지 못했어요.',
      );
    }
  }


  void _scheduleMovedAreaLoad(
      AppController controller,
      double latitude,
      double longitude,
      ) {
    _mapMoveDebounce?.cancel();

    final requestVersion = ++_mapAreaRequestVersion;

    _mapMoveDebounce = Timer(
      const Duration(milliseconds: 700),
          () async {
        if (!mounted || requestVersion != _mapAreaRequestVersion) return;

        setState(() {
          _isLoadingMovedArea = true;
        });

        try {
          final movedPlaces = await controller.fetchPlacesAt(
            latitude: latitude,
            longitude: longitude,
          );

          // 검색이 시작됐거나 더 최신 지도 이동 요청이 생겼다면
          // 오래된 응답으로 장소카드/마커를 덮어쓰지 않습니다.
          if (!mounted || requestVersion != _mapAreaRequestVersion) return;

          setState(() {
            _mapPlaces = movedPlaces;

            final selectedId = _selected?.id;
            final matches = selectedId == null
                ? const <Place>[]
                : movedPlaces
                .where((place) => place.id == selectedId)
                .toList();

            if (matches.isNotEmpty) {
              _selected = matches.first;
            } else if (movedPlaces.isNotEmpty) {
              _selected = movedPlaces.first;
            } else {
              _selected = null;
            }
          });
        } catch (_) {
          if (!mounted) return;
          showAppSnackBar(
            context,
            '이 지역의 관광지 정보를 불러오지 못했어요.',
          );
        } finally {
          if (mounted && requestVersion == _mapAreaRequestVersion) {
            setState(() {
              _isLoadingMovedArea = false;
            });
          }
        }
      },
    );
  }
}

// ============================================================
// 혼잡도 범례
// ============================================================

class _CongestionLegendBar extends StatelessWidget {
  const _CongestionLegendBar();

  @override
  Widget build(BuildContext context) {
    const items = <({
    Color color,
    String range,
    String label,
    })>[
      (
      color: Color(0xFF2F80ED),
      range: '0~20%',
      label: '한산',
      ),
      (
      color: Color(0xFF27AE60),
      range: '20~40%',
      label: '여유',
      ),
      (
      color: Color(0xFFF2C94C),
      range: '40~60%',
      label: '보통',
      ),
      (
      color: Color(0xFFF2994A),
      range: '60~80%',
      label: '붐빔',
      ),
      (
      color: Color(0xFFEB5757),
      range: '80~100%',
      label: '혼잡',
      ),
    ];

    return IgnorePointer(
      child: Container(
        height: 72,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1E8D7).withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0x66D6B166),
            width: 1.1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 9,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            const Row(
              children: [
                Text(
                  '혼잡도 안내',
                  style: TextStyle(
                    color: Color(0xFF4D3A2F),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Spacer(),
                Text(
                  '한산',
                  style: TextStyle(
                    color: Color(0xFF6E6259),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: Color(0xFF8E7B68),
                  ),
                ),
                Text(
                  '혼잡',
                  style: TextStyle(
                    color: Color(0xFF6E6259),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final item in items)
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: item.color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                item.range,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                style: const TextStyle(
                                  color: Color(0xFF5E5147),
                                  fontSize: 8.8,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: const TextStyle(
                            color: Color(0xFF77695E),
                            fontSize: 8.8,
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// 카카오맵 WebView
// ============================================================

class _KakaoWebMap extends StatefulWidget {
  const _KakaoWebMap({
    super.key,
    required this.places,
    required this.latitude,
    required this.longitude,
    required this.focusRevision,
    required this.width,
    required this.height,
    required this.onMarkerTap,
    required this.onPlaceSearchResult,
    required this.onMapDragStart,
    required this.onMapIdle,
  });

  final List<Place> places;
  final double latitude;
  final double longitude;
  final int focusRevision;
  final double width;
  final double height;
  final ValueChanged<String> onMarkerTap;
  final Future<void> Function(Map<String, dynamic> result)
  onPlaceSearchResult;
  final VoidCallback onMapDragStart;
  final void Function(double latitude, double longitude) onMapIdle;

  @override
  State<_KakaoWebMap> createState() => _KakaoWebMapState();
}

class _KakaoWebMapState extends State<_KakaoWebMap> {
  late final WebViewController _controller;
  late double _visibleCenterLatitude;
  late double _visibleCenterLongitude;
  double? _visibleSouthLatitude;
  double? _visibleWestLongitude;
  double? _visibleNorthLatitude;
  double? _visibleEastLongitude;

  @override
  void initState() {
    super.initState();

    _visibleCenterLatitude = widget.latitude;
    _visibleCenterLongitude = widget.longitude;

    _controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        const Color(0xFFE4EEE8),
      )
      ..addJavaScriptChannel(
        'MarkerChannel',
        onMessageReceived: (message) {
          widget.onMarkerTap(message.message);
        },
      )
      ..addJavaScriptChannel(
        'PlaceSearchChannel',
        onMessageReceived: (message) async {
          try {
            final data = jsonDecode(message.message);
            if (data is! Map) return;

            await widget.onPlaceSearchResult(
              Map<String, dynamic>.from(data),
            );
          } catch (_) {
            await widget.onPlaceSearchResult(
              {
                'status': 'error',
                'query': '',
              },
            );
          }
        },
      )
      ..addJavaScriptChannel(
        'MapDragChannel',
        onMessageReceived: (_) {
          widget.onMapDragStart();
        },
      )
      ..addJavaScriptChannel(
        'MapMoveChannel',
        onMessageReceived: (message) {
          try {
            final data = jsonDecode(message.message);
            if (data is! Map) return;

            final latitude = (data['latitude'] as num?)?.toDouble();
            final longitude = (data['longitude'] as num?)?.toDouble();

            if (latitude == null || longitude == null) return;

            _visibleCenterLatitude = latitude;
            _visibleCenterLongitude = longitude;

            _visibleSouthLatitude =
                (data['south'] as num?)?.toDouble();
            _visibleWestLongitude =
                (data['west'] as num?)?.toDouble();
            _visibleNorthLatitude =
                (data['north'] as num?)?.toDouble();
            _visibleEastLongitude =
                (data['east'] as num?)?.toDouble();

            // 현재 화면 안에 실제로 보이는 장소를 기준으로
            // 서로 너무 가까운 마커를 피해서 최대 8개를 다시 고릅니다.
            unawaited(_updateMarkersInPlace());

            widget.onMapIdle(latitude, longitude);
          } catch (_) {
            // 잘못된 메시지는 무시합니다.
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            await _controller.runJavaScript(
              '''
              if (window.kakaoMapInstance) {
                window.kakaoMapInstance.relayout();
              }
              ''',
            );
          },
        ),
      )
      ..loadHtmlString(
        _html(),
        baseUrl: AppEnv.kakaoMapBaseUrl,
      );
  }

  @override
  void didUpdateWidget(
      covariant _KakaoWebMap oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    // 현재 위치 버튼 등으로 Flutter 쪽 중심 좌표가 바뀌면
    // WebView를 다시 만들지 않고 기존 Kakao Map을 새 위치로 이동합니다.
    //
    // 이렇게 해야:
    // 현재 위치 재요청
    // → 지도 중심 이동
    // → 새 위치 기준 장소/마커 갱신
    // 흐름이 끊기지 않습니다.
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.focusRevision != widget.focusRevision) {
      _visibleCenterLatitude = widget.latitude;
      _visibleCenterLongitude = widget.longitude;

      _moveMapTo(
        widget.latitude,
        widget.longitude,
      );

      unawaited(_updateMarkersInPlace());
    }

    // 장소 목록이 바뀌어도 WebView 전체를 다시 로드하지 않습니다.
    // 전체 HTML을 다시 로드하면 Kakao Map 인스턴스가 새로 만들어져
    // 사용자가 이동한 지도 중심/줌이 초기 위치로 돌아갑니다.
    if (oldWidget.places != widget.places) {
      _updateMarkersInPlace();
    }

    // 실제 레이아웃 크기가 바뀐 경우에만 relayout 합니다.
    if (oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _controller.runJavaScript(
        '''
        if (window.kakaoMapInstance) {
          window.kakaoMapInstance.relayout();
        }
        ''',
      );
    }
  }

  Future<void> searchPlace(String query) async {
    final encodedQuery = jsonEncode(query.trim());

    try {
      await _controller.runJavaScript(
        '''
        if (window.searchKakaoPlace) {
          window.searchKakaoPlace($encodedQuery);
        } else {
          PlaceSearchChannel.postMessage(JSON.stringify({
            status: 'error',
            query: $encodedQuery
          }));
        }
        ''',
      );
    } catch (_) {
      await widget.onPlaceSearchResult(
        {
          'status': 'error',
          'query': query,
        },
      );
    }
  }

  Future<void> _moveMapTo(
      double latitude,
      double longitude,
      ) async {
    try {
      await _controller.runJavaScript(
        '''
        if (
          window.kakaoMapInstance &&
          window.kakao &&
          window.kakao.maps
        ) {
          const nextCenter = new kakao.maps.LatLng(
            $latitude,
            $longitude
          );

          window.kakaoMapInstance.panTo(nextCenter);
        }
        ''',
      );
    } catch (_) {
      // WebView가 아직 준비 중이면 다음 marker update에서
      // 새 좌표 상태를 다시 반영할 수 있으므로 앱을 중단하지 않습니다.
    }
  }

  List<Place> _markerPlaces() {
    final allPlaces = widget.places.where((place) {
      return place.latitude.isFinite &&
          place.longitude.isFinite &&
          place.latitude.abs() > 0.000001 &&
          place.longitude.abs() > 0.000001;
    }).toList();

    if (allPlaces.length <= 8) {
      return allPlaces;
    }

    double distanceToCenterSquared(Place place) {
      final dx = place.latitude - _visibleCenterLatitude;
      final dy = place.longitude - _visibleCenterLongitude;
      return (dx * dx) + (dy * dy);
    }

    // 1) 카카오맵이 보내준 현재 화면 영역 안의 장소만 우선 사용
    var candidates = allPlaces.where((place) {
      final south = _visibleSouthLatitude;
      final west = _visibleWestLongitude;
      final north = _visibleNorthLatitude;
      final east = _visibleEastLongitude;

      if (south == null ||
          west == null ||
          north == null ||
          east == null) {
        return true;
      }

      return place.latitude >= south &&
          place.latitude <= north &&
          place.longitude >= west &&
          place.longitude <= east;
    }).toList();

    // 첫 로딩 등 bounds가 아직 없거나 화면 안 후보가 너무 적으면
    // 현재 중심에서 가까운 장소를 넉넉하게 후보군으로 사용합니다.
    if (candidates.length < 8) {
      final nearest = List<Place>.from(allPlaces)
        ..sort(
              (a, b) => distanceToCenterSquared(a)
              .compareTo(distanceToCenterSquared(b)),
        );

      candidates = nearest.take(32).toList();
    }

    if (candidates.length <= 8) {
      return candidates;
    }

    // 2) 후보군 안에서 좌표 분포를 0~1로 정규화
    var minLat = candidates.first.latitude;
    var maxLat = candidates.first.latitude;
    var minLng = candidates.first.longitude;
    var maxLng = candidates.first.longitude;

    for (final place in candidates.skip(1)) {
      if (place.latitude < minLat) minLat = place.latitude;
      if (place.latitude > maxLat) maxLat = place.latitude;
      if (place.longitude < minLng) minLng = place.longitude;
      if (place.longitude > maxLng) maxLng = place.longitude;
    }

    final latRange = (maxLat - minLat).abs() < 0.000001
        ? 1.0
        : (maxLat - minLat);
    final lngRange = (maxLng - minLng).abs() < 0.000001
        ? 1.0
        : (maxLng - minLng);

    double nx(Place place) => (place.latitude - minLat) / latRange;
    double ny(Place place) => (place.longitude - minLng) / lngRange;

    double normalizedDistanceSquared(Place a, Place b) {
      final dx = nx(a) - nx(b);
      final dy = ny(a) - ny(b);
      return (dx * dx) + (dy * dy);
    }

    // 3) 첫 마커는 지도 중심에 가장 가까운 장소
    final sortedByCenter = List<Place>.from(candidates)
      ..sort(
            (a, b) => distanceToCenterSquared(a)
            .compareTo(distanceToCenterSquared(b)),
      );

    final selected = <Place>[sortedByCenter.first];
    final remaining = List<Place>.from(candidates)
      ..remove(sortedByCenter.first);

    // 4) 이후에는 이미 선택된 마커들과 가장 멀리 떨어진 장소를 고릅니다.
    //    그래서 한 군데 몰리지 않고 화면 여러 곳으로 퍼져 보입니다.
    while (selected.length < 8 && remaining.isNotEmpty) {
      Place? bestPlace;
      double bestScore = -1;

      for (final candidate in remaining) {
        var minDistanceToSelected = double.infinity;

        for (final chosen in selected) {
          final distance =
          normalizedDistanceSquared(candidate, chosen);

          if (distance < minDistanceToSelected) {
            minDistanceToSelected = distance;
          }
        }

        if (minDistanceToSelected > bestScore) {
          bestScore = minDistanceToSelected;
          bestPlace = candidate;
        }
      }

      if (bestPlace == null) {
        break;
      }

      selected.add(bestPlace);
      remaining.remove(bestPlace);
    }

    return selected;
  }

  Future<void> _updateMarkersInPlace() async {
    final markerData = _markerPlaces()
        .map(
          (place) => {
        'id': place.id,
        'name': place.name,
        'lat': place.latitude,
        'lng': place.longitude,
        'quiet': place.quietScore,
      },
    )
        .toList();

    final markersJson = jsonEncode(markerData);
    final encoded = jsonEncode(markersJson);

    await _controller.runJavaScript(
      '''
      if (window.updatePlaces) {
        window.updatePlaces(JSON.parse($encoded));
      }
      ''',
    );
  }

  String _html() {
    const blueMarkerData =
        'data:image/png;base64,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';
    const greenMarkerData =
        'data:image/png;base64,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';
    const yellowMarkerData =
        'data:image/png;base64,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';
    const orangeMarkerData =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFcAAACACAYAAAB+8/X7AABI1UlEQVR42u29d7he11Xn/1l7n3PecnuRrq6aVW1Z7t1x4paJQwohkCCFEsJMCMkwtGEoMwMZZFEGGMgMAWZCGRJqYKRAAgkJwUlspzmO4x4Vq9er28vbzzl77/X747xXkoE0ktjmeX5Hz6vn0Xt13/fs71l77bW/67vWFl6Al+7CwC5k9+6w/F7rV8fXRwPlVU4pRU5C8GG29OiJM/JnNM//3p4dVnbu9S+UccgLDtiLANLf2XBL6O/ZoZX+u7QysJm42ieKxTk077RIG5PSbjxGs/HXcw8e++DYXhqqxZhE0P8f3H8G2OzXN9xixkZ+wYxteLlsvhmqm9AcfGtKSRcUV8fkTWN8C3wdmkv4mfnjzM7/cvSTx/9w2fplN+H/B/diYH/rsp+242O/bDZdH7v+azyop3bc0JoUspqozxH1CKpBBcEGDEQhi2ktkp+d+ZvW/sl/N/iupYXnG2B5IQHb/vVNv16+fONP+YGNTk1VSWet5nUQgxgLCngPPkedQ8Kye1UQGxAJUegk+amJp7KpiVf0/vfWuecTYHn+gcXKTnx916r/1Ltt3Tt8/5qOehcROkJUEpIyJo4wmkOW4XNX3LgxhNyBy4EAQelCmEehXWoen3x4/onTd38Osh17CcJz74OfV3B1F4bd6PxPDl3Ru3rk0Wj1KgnWGhVEbKJEsRg8tWOTTD59msXZFhoMgysqDKwZYHDTCkp9VYILiAIawDvwPo9cszR3ZObXRn91+r8sP8DnenzmeTXbKxABjSrltye95cRnXnEqeBANaL3Gvv/3MA+9bx8LdhVh05Us2kEe/tQcT3/kGIc++CQLR88VgwgBXK6EoKoaOWJf7i3/yJkfGlonO/FFePfcXtE3xAJ1j4UdYXkmiMhX9HG7dmFkJ/7E91bHJYpelatV0WBwXkWKjznx8QOcOJNx209/LyNXvQiak+DbnPjoA3zyTx6lczzFZcdISjHVlUMErwgKYiSYxPX0V3qa8803AL/RNaTwpcegAntNMY69BnaGrzec+7qfpgiI7PQioiISRCTorl3my7kC3XVndC/bI1UkLnFVKZI+4sgBor6YvdnUvD79xBzXvuZyRkZyssf+mvyZz5CeOsSG69ew5doRTs4q87M5UwcnVYOCidAoEWyMxIlQKivW3qU7sID5UtarqlLc//I4dvpvRJwcfX0Wu8uI7A6Lj/7xj/as3PimEPxcY/LobrnlLQ/t2bPH7ty50//zu64HCwvaDae/344ZFwhBVaxQGK1iklhabXAnz+KGDNI/iIhgWov4JowNx2Bgvg5D020hipByLIKiISCKaJaJGLtB9uKh8Lm6Z4dl315djiCWgW0++n9Xxys2/3dT7rm8PX36H86deuCXtj48nHPvbv2XAv0vBlf37LEiO/25B3/nlwbWb/w5KmsgEnry9p0T9//27avv3vkF3bPHys6dXndgZTcedtP5Pi43q0ZfYSrDt6VL6erpcwvjtaYP1dxZEyWAEjJHaWyU677tBj5132FeuQFGhg2+3UHEkC41kFaHOLEsLHiSgX7iVWvJW+0iLHMOCU5cpxOyVDee+/6RPx4elk+HM7Mfk517jwPoDix7NLB3rzn04V09Ul35sXjt5stpOXpX+5t7Zi69VHb/6Bv03l0Gdj934O7Zs8Oyc2c4tPft1/X0D/7XrBVyIy2IyqE0tKrc127+6YEP/PTNvJbWF956Qyy//2hee+vItsrakZ+XdVe+3q7akLA0RfXwIbITNVq1LCSNjthSRTFGRFSzWpMrXryWdTdvoqxtfLvejbg86cwC56ZTJqY8V15aYfPrXkEo9UKICgP1HnWZqFmi03KVwUrvm5JrrnqTv5JGfu3xv3JHzvyCvGfpmH7kt0qy88fTpcf+/L9X1qy93C+128Hnsa+3/cjo6M5D7/9vfyay+4PLRvKcgLuDHQh79WRv70/19PWZXNUBEVHJOp9nvas3bBvPst8W2flvwfj0P63fYccG/6/dcmW/i1YFf+ZY5ieOSGdqSWbmOlJRkXLfElIuSam/D8UIXjWbnqI3MnhEsBFooHZ2ljC1yBePNbj2pev5tp//EYxp4BsLSKkXfA7iQAyu3qY5l2nuQ943OY29ZFtPdHn/9wvh2zo/M/IWedWP/3Xtod97fWV01Q+7LMo1KZUk5ICoRiW1UelngA+xb99zY7m7du0ysnOnf/S337zaRPY1rY7TqEetBocgkPRELvX5wNoN37904O8eT3/81ZNJb/yXlCvqjh7KqH8uCj5EIQeX5wjK4RMZIwOGNJ+mb32gPNBb7MhEcAEwBtfJaJybJT07x5P761y1fZjbfvYN+BhCK0VKlSLONRaxAV1coj29wNRUh7Wj1SidnqTUmAk+qfqkFA8tnDn2FxO/uuMXSmu2/KSpDKpPeo3YGE0DqmrTTDWKk1sf/d8/sE1+ePcB3bXLXMzSfVPAvQvMbgjlocHb+3p7+4KSawgWnxeDi8qg3vpMfc+A/KZ7/VuZ/OTeUJpYDOX+SiRJQlCLzx1ZFuitGtIp5dP7OtxxFdRzT7OvRtJXEjGWoOBSR7bYQpcaHDqVsdAI3HnrOEEGCN4hpT4IDjQgJQiLk2RHDnPy4DzTs44NY0qn4wgg+cS5aHFiySfX3x2v/85/+0u+MkSIe7zEVVHv0JCjqogY19fXmyxWKy8BDjxwF4avcRv9tbuFu4pVXoy5wVqrPqCqigaPuBSiCiS9Rdyowfd/5w/JwvgWnXj3r5vhdp3KYA8IuNTTyXPUCCM9wsPHHFMLDa69NGN8oEGcGFQEH5Q09SzWPJ856Th0Gn72tX34eoPWIx+ltOVK6BlC4jKhU8NNn8YfO8jCoXM8+VSDFVWDc4GsldJaqLO4aBh9w0/K2KteF3xcDUFKRpJ+UQy4dsFbaBFxIAbFXv6chWJ3zVxR+J8QLvFBRQmiIaDeoXkbicoQFy8NXugsMXLb3RJEOP3O3axwLaJSRJ46avNNZqZz5tvCuq2jdKpVDvrAQqOD9VkRlpmIPK6QDvaxdeMIl7qcL57cz+VM0je1RHzkKLZaBWPRdpv2bJ35xYyPP9yk6qB3pEQ7V/xsm6WGsPknfo5Vt99DnqmoqVhJelDpApu3UF/MAFUIIeB9tupZ4/7mLmh70R3YfS4MeOcR5wjeEbwH18akFgmuu7sAogTXXGLwiis5c+VNnP38A5SrCc1Gih8cZ+jl17Llmu30j6+gHINznlbHkecOFUtcqlDu6aFSrWKNEIAzR44z+bkHmT55gNLEAiZMEUIg9ZZW0k9ncDPjt5coT08zd/YkIc8JLrDiNd/J6HXXkTVamN4RsBGEgIQU8iYh7xRjcQ7vM/F5jmZaLWL0vd88y1VF2LvDyBv+yqPw9GvsjLqMkKdq8owQJUh38CY4xFgE0OBREUKW0XPpZp76q/tZe+1qNr32LlZccy3loREQQ/CgYkisoWIjxJhiNy2CYi6QXqpsvGGcS667iaXJczSmz5HV5gneI0mJnuFRBob7iaySdnJmDjzDsb+/nxP7j7L92ssJqUOqBtSDS4EU9TnqOgSXEXKHdxk+62jIM0IUn5bdBL1/e6R7sOz86hm2rwpc3YEVwcNef/J71g9V65N3zJ4+fllz5YgmpmxMXEaiBBFTkAshIGIKyw2ekHXw7QZePOOvfjE3f98bqAyMEoLig0GiCEmi4oGIoGJR6e7ORRBjMAJIsXt1ISDGMrRuCyMbthY3GRwEj88zXJoRvCOOctbdOsLItq2E970f7zr4PMO6HPIOmBwNigaH+hyf5/g8xWcpLs+k3W6qHNu/eebl3CB373704t3mV8MRf1lwFYRdiOzGN7+L1cnK/p+Q/vi7somhtcf2H4Bt24KxFWPjCiaK8cZipfBV5y+X45pLdObPUJ85y7aX3kZ1aBXOg0kSTBQjJupyPloA2A3DCqcrYKT4qXaNuYhE8RrwTrs+UgGLmDJSirEhR4MnZBmVgTFWb1lPa3YC15gFUypIBrHnF6/gHD5PcVmHvNMma9ft0uKi6qHDr7SrVr4y/U/Jw7QX/+Bv3tX4I9lNsevc++VpzOjLAqsgQnD/fuAtsn7tL5sr7lhJCu35j+W1A2ekNDdnkriMiUuItYCgPkGMQUQKS2o3yRqTzB5+itpck6u2XI1GZWwSI0kVcW3AoxIhcRWMAZ+CMaiJixmAXgAfinhaA6Khu2Ho/r+shfoUEQtJL6IOEYuN+xnaeBWHP/Y+BsbHKWtM5IeRKClcUvAEl+OzDnmnRbuxSLtVo3X6LO7MlIvu2CTJ1Vfdgm/e8rrRfW9tnZ38j/LuzkNfCeDoSwK7A4MQOj+24vft1g0/GDa8BJf5LHzxk1aa86acNWT+iQNU7x6gtdj9Pe8wtjtQ9YS8Td6cpX7mEMcf/SKXv+I1lAdH8RIXhjn1BPhWAWieC17R0a3K0CUFMMYWltx1B3LRAoCGwhXEFbQxiyweBd9BXKc7ghgGt0LPKCFPWb39ak489hBHP/0pNr9EsK012OogEpVQFbx3+KxD2qrRWZojz5rMPvwk62NntLlEPnHMyYarQ3Rlz81J8sQD9TdPvlneXfvzLwewfEkfuxdff+vwH/Reuvotvm99RxcmIxamTMiEVi1n4uQST0wKm970GkbWrUajKqWePmwUF0R33sY1Z5k+fJhT+49zxctfyaV3vAyvSTElDnwAMa4IfTq1wgMkFXA5YcUNyNY7i/dsDGIvuAgNBTEe8sLqJvYhZz+HVHuhdg7t1IpdWrkPspSw/qXI+HYka5K3ajz8Z39IWJpg/XVXUVqxBlsdBlvCB8izDu36EurbnHxkP42PfoJbruhneKxKuS/ClCwMjHkpR1YmTpulY9PfNvwX7Q9+KYDtlwJ24U29b+m/ZPheb6tpmDkTS7shSiIY1azjJU0DS3MtDh2cZGTDMIn1pPUF0tos2fw5Fk4c5cQXnmLy9DRXvvo1bH/pa3DBIqUy+eN/g51+vAiB5k9D3iZ0GtBeQiKLnnocb4ewK7d07zIqADb2orkl+JnjyNN/gUksYeIAoT6DuAztNAiNRcibdI59EVlzDRKXsdVBVm+7jFP7D3D8kcfQZg3Nm2TNBdLmEnlziZDVOfXkYU598FNsGhWGhkuUKrZwY2KQds1opx2icgJZ/oo3r2r/5dD7WboXzO4Hnx1F2H/iDvajb/1WRntH+94f95ZLodkSUS8qFnVBlqabMjfdZLGWE8TQnGvw+KOnyCUQ2k2ak9McfeoI8xOTjKwf5bbXvYL1m9aSzR7HlPtxzpM+vBcbmihCkIisnRIlhYVqJ0VdRj59Erv5NiQpg4kLYJfDMw0El5F/9o+Is0k0a+Jzh4kT8laHoIWVq3N0zp4hrNhK0j+MLhwjap9h0zWbKPX1MnXsDIeeeIbm7CKdWo256Xm++JkDHL3vMdb1eiplg0sdeccRxUK5Wiy8EnJClvtSLL2+rf09O/K/vXclZvf+Z4P7bJ97J1YexE1We95Y6Y1GfZql6jQuBqUsTNaZPFnn3FzOfBNaAdQKpWaTD/75I9x810ZGBsusWVPlple+it6+hLC0KNnxs2riGNOaIW0Jpw+eZeN6Q9TTjxXl1ONnILZc/uJNpM0cYyLyyRNw5gDV7bejKl2rVRBFbEQ+eRZ/dh860oNPc+JSxOSJeY48cpybXrkNTII2U6aPLxDt+xwD8Tw+bRAa8wR1bN04ytbNd3PiwBGe+NwxzpyZ5+jxeWafmuSqcWGxA812TiKwoj8jbecYgf7RCqBIUBOchsia7zxyT8/Pyt7mdDGfLgD8bHBXFj8QkZehqDo1CCoi0qmlTJ6qc/hcjl2zgq0vWUlrcoaHn5hjpuV56csu4+ZvvZHB9Bzrtq3FL52kc/QUYkSDh2AiqPTRW0pIM8/jnzjBJVc0qfaWOHJglvL6Ma6wUoRFInQW6vi5c/QY083uKqCoKsYYstoC6fwipf4SamMiAxMzHQ4drnHVFdO0O57pw9McqcfcMwRh5ghubqJIxRtDe/I4GMOGdRtYXV3PyVY/N97Tw/v+1/uZmlpkzaqEbdeP40s9nPzCCfKJFpVKg2pvRJQYgseIiO/tsQOLZfcS4K8fuBPLg7h/Aq6CyF78LjCqYYMqUuRVwESiWTuXk1M5PdvGeOV/+FbIHfmxL1KWlA88mXP397+KXuvpO3uQdCLgO20kKaN5RpREBJvg6ovQibnmldfz+fsHefip0+BbZKNruOPlm8iaHcRYXKtNu5FjbILxGcFlSjdrSVBMZPEuo7nUobeTEfcltJspV169kqnJnL+/b5K4FDG0cRN3vf4y+qMW7XPT2FIFW6kQOm0CAhhaZ05iQ86QD0TXvojbdtb5xLv+ile9bIxVV19CvGYL1999GX/3mx9lbj5jjQfUCAQwRiMrSvCXLXNaXzYU2w/iAjb4gCQGtYJJIgLCfA47XrYRf+4YzdlF8k5KbJQdb7yDkU2X0nz442RLNZJyBUxEe6HGU/cfReOIy69ZSe/YED4EwuI0t929hvpLNpMTM5h08Itz5F5BoDExR1N6GB5ZhW/OFxFFNxmKgjeWZGCYtDxCa2KW3i3VgspVz6u/Yyuz7asQEzFY9YTFadpNjyRl8lqDk0emOXJgjlVreth+2xZ8gOADnbPHiDYtcOPL7iTs/yLN1iK1uRp2/nEG165g0/WrOfrJI9xcTXBIoZMIAZeppJ4E4IEvlf0VUN2F2QvepeGUpg4iqxLH4m0sA1vXUOqJmPzicbKlOhJFuHZKXhlh/e23Y0hIOx1a8w1CXkQltlJh8zVrOXyywXv/9ji1I2fxeXdazi+QNCbobZ4inZ3GByWEQP3MLPNn5zCX30h1cBjfqqFZG8076tMOIUtx7SaVnl649Hrmzi3RODVJCAEVQ3thif50Svs6Z0mnJ3AB1Ea0zs7w9EPH+fOPTpBUy6y7ahNBi8mZtzo0F1sELJWePjbe+WJabYcBbBxTP3qa+YOnGd24ArNyBKxF4ghFyTsel+q5r5haf+ABjCrSTsN9Wd0RQlDKFUK1n3jjRl72w99OQ8bIc8FGhvZSm4GrrqY8tBJjLGF4nPmZNvVT06SNDuoDvX2Gy8cMA5s2cqRW5uzjx1g6OUnezsgdZDl4H2gt1pk/dIapIxPU1l7J+IvugRAIIagGj/oAISjBqwavweWsuv4OFldfxdlnJpg/cIrmzCJ57sm9kubg8kB7ZpGZp49w7JkZpoe3cMnmMdaPGsolyDs5nVqTuUNnqccDJEMr0CAMXrodVx0uZma5xFKnTN81N/GSf/863NAqpK8fSjF5x0XTNZfn8BmAu+56Nt8Q/TM6BP11snfteI35mZG5xmhlbDwwMiZOI1aMlVnxLdtJZ6fJa/O08oTh7VcjYjE2YWjbjRw98gzN/V+gcnIGY4TF+Qbpmm1863e/kdriHGcf+gxLJ45ROTpNnFjEGLz3pKmjZSrEl9/GhrteTXVwDB9CsTlTAfHFaquyvLBpdWBUNr7qDRz/RA+nn3mM6rnjlEoRURJJCJCmObka6uUhem65lduuv5nJA/s4+w/vp/WZ/ZRKEVknp1EaYPSuu6j0DhJyR2VomJ6Nl9NZeIq+lbDq8nWsHVmFzzK0dxARi54+5v1iK16su7+57oF837I065+Nc3UHduOH8Se+hfHb7h78Pycm8qt9Ozc9JRU7NICUy4QsxTeWEAKLp6ZZjMZYeesdGBMjcYlSTx/lNRuomYiGM3SqQ0Tbruey17+Jkc3X0Ds0xtCWy5HVm2hEZeohppX0kQ+uQjZdydCt/4ZLbrmbvsGVqDFacAjd+z1Pzizzn8VV6RtkeNMWCSOrqJsybVOmQZlGMkA+tonS1S9i7NaXsvGG2+kdXsPw+s3I2Dg1B64yiF+/lRW3fwtrtt+AjcrFdBYhzR2LX3yckdWDGGvRLEVMhBhBF6ZJj5ySg4dr6owd+c1X9VTe+Bvpp3dC0F0XNhNyMYU2/297rurdsOID8catm575xDPhmcdOs3l1wtoNfcTjK6GvFx8Ut1DnwCMn6Xn5t7P1ZS9HSTClKiaOMTYmeEfabgBCuXcAE5dwzlOuViCKyJcWCkrQBpqNJlmaUe7pwdqYELSLnqBhWY+hen6nLhf+KqBXBEFQcXmHTrvQLvQPDiBRBSOC7e2HXGm3WtgoKqiMtIXLU6y1RFGJ4H3BPXtHyDo05qd46v+8k8vXBYY3r8XGJXAe5udoHJ9k/+EGC0s5L3nNdjNy7TqyAwc+0txX/+7h9y0saSiY02gZ2IW3DGzs2bTivviml4/5VNK1Y4fj+ZESnzucMjazwJqROtVqRFBhcTHl8FLEnZs2oQGIultTE6FikLhMtdTTJboV7z3lvh6OP3OMP333X/Lo41+kHFm2XraFH/jBN7Bx6xba9TqIqkjo5t+KuLaADwFFRPQCQaZol29QBBWDSXoZ6F+By1L+5I/38vBnH6PlAldt38z3vGkH6zdtoNNJAUNU6iUu9XI+/0ex+9PCz1Pu64HBVRx95BEaZ2vEBnzmmFvIOT7jcS5w4/Y+ekci78eucsnwmlcSPvah43cs3MO9ZArYe+9C7l2JYe3QB0o3vGi7L61Kw777Yu8c5UQoqefMnOfQpOfkdM7BSc/HjzrqK8d52evuBlvBlsoFG2YiRCxijCLFrPZBKff18oXPfJ63/tuf4OCBI2y76gZe+podfPKBz/Bnf/T/uPmWaxhft7pItYuh2JJpF9uuNRUvCSEURK8s4y0FHywiUVLWTqsl/+Ft/4Unn5nmnu/4bk4cP8nDn36YD33wH7j51usYX7cGl2d02feufymoeTSgweOdI7GBg8fP8WfvP8jUQs6ZcynHJh0TtcBgj+GaLVVWbxsh7o1FWnNWN96exn1hU8XNDMe/0vq7e/fssIXVjgy9obxu7HanpSwc+EQcfEBLMeXBCmNrerhiQ4nLxiw9iRALDBnYvnEUG0UE7WYIujH+8piXN4JRFNNcqvEru/8XWZazanyc//o/3smbfvyn+IXf+t9kaYdf/cXfJEszjLGiaFdq6/FpE5d2iu+wCZgYVYpsQ6eNhoCqiKpKUCHpqcjv/ta72ffkQd7xh3/Em3/yv/Dj/203gwN9pK0O7/y13ykeoDGA0fNMm5gLBSpScNHOBUbH+ukrQ4KSRMJon+XqdQnbLykzsq6fZLBScMKdFhz8eOwHNufJmrH/MPvGyi2yc6+PAMp95R+k3Kc6c1q03SRgEKtkmWNhtsW5s22mlqDloFwWBhLoHek/n4Psbpm7U7QwCBCCBkrVCg/edz8njp9iaGSA2uI8n/rY3/Mtff088NEP09fXw5Ejx3ns849z250volVrEHyOzzJs30qSvlGinhGwBVWpIce3a7j6DL4+iziHScqUy2UmT01w38c/Q19/lc/dfx9DK1by0Cfuo15bpK+3pI8/vk8OPL2fq268XjuNFkYKT4RqV0Jqzvv1EAKDwwOsGYwZtDkuU5p5YKrj0CzHli2lwQpRTwUVC0vTQs9JldGVJEPnfgza3xud2ZFcpsbe7FMPacuEbh4lXWxz+sAsJ6dzVl6/lQ2XrMQvLbD/8yd5bKLJFZX4IjJYzwMsXJSPUcAaTp44Q9Cgznl88Pzer90re/7wXcxOTWoSiTRbHY4fO8ltL7uLoA1AKY+sobR6CxCTp3mxZHUDnNLASkojq3DTx+jMT6IKUaXKyVNPUavV6O2p8H/f8Uvsffe7mJuZxlrRNHdkWc7U1DxXRXF3zSzCOkFUMYA/v2qGAHEpITUxM62cG25Yybor15N7w6lHD1M/sEBkIekvk1S6W8eFKas2wiTxnY/fyWBkyqVbS7GtqsucZp1iBRJk9sQiJ6dzXvyD9zB+4/Uwdwbq01y+FpYahxAbd31UKNKyywt6FHUNwKCu0Mx20rzYyQvkISCaMTVxUo0x5E40MSKlShmMIbgUEUMcR+z/5Mco9/azYcMqvC/WMivK1MwSZ06f5eqrLkUA5zKwtvg5SvABvGduekLFWLxXYmukHJvuFtqLGFEiI4KgAcErEsxFYV/AB08L+I57Rrn+1VdDzwroGeT6V97AF/74oxzdf5z+sUVKG1aANUjWJqj1GLt6dFXPtREi64yAT1MlIAUCORNnm2y4YS3j63tof+FBtLWI8yA+8LLrepkOS3Q6HWypB9WAGoMELQSzziNJgvQWodeWrZsYKEdUkpjgHEFRI4JBSayVUIrYtHUzeIeNYupTJ3HtJX78+3+YulPu+8RfYBHyLKN3oI9dP/V2/u7vH+FjH34nQ72WqHcUgjK+bj2lchnVUDxoY0ADiTXSV07oiyM2bNoA6hENwmILzVyRAK2U8JFFM9Cg4HNatRov2hyx7dJBGmemMTqJiSzxytVc+9INfPCZsyxMthjeiKqIaJ5BMCGxWIS1ER4NuUO9L4yvGz6FAKsGDNnJ4+AViRNIU81zL0k5xs9Nk7bqVOOBwtgXG5izS5DnxQpsYjFRRJircdsrXsn6P/gTkUZdN4yuZnaxRuo9pVIii7MzXH3DdVx14/WkrTZJ/zBmboLFMwf5wR/4DmZmF1k4eQCxEcEHGtPCS190OddsHUfrp0ijVQysH6PT6XDJpvVcc8M1PPGZz7Jm1Zg2s0wSa1k1PMD87Bybb30Rm6+7nuzgQWRiHnFZ4Wl8QIwRHe3Dj1Tx3uF8hl9a4JJBIc2UyGQqpQQbx5JOnqVUtowOl+lkYGMree6REMAFQubIvbf2xy9PtpRK5rVUE8VYCapEJStTpxvMz7YYGzTMnlokbaSUqhEuz0lrqUwveAa2bSXpG8SkSnJiAXEebNeLmSKw99OLVFYMsu7aK9n3yKNSUi+9pZJUIpHa0iIr127g5379FxgZHiRKYny7gS0V6ppLt67iisvW0m7MQWhD6JCnDS7duo4bbrycSv8oPcPjmFKVcrkMBrZffQVPfeFJ2nMzsnZkgNHeCqGTMrR+Mz/yi/+VnnqdsO+oGvHdcEyXS63ELtQJwZHFDtdeZOqpL5LMnqV/uIJJIkGQuaPT2OBJF1s8/fQcW68YoX+orCHLEBFCO5XGXFPa9ex3onZDP1dbzDq9PWnJ9kVBA2hi2XrDOH/7N8dJF04yvahc+eI19I8G8XnQ1mKHU0fnGTh5Gk3KjDCKcREaWyUYREXBCVGkNkkkO3yMG198Ayt+8x189H3vZ/r0GRThtiuu4BXf+e2sGOnBd9o8+plHCKVhygPDHHvkNGcfe4jhsRHKZYM1XSNTQ6fjWZhepGfNBq586T34iTlaU0e56aYrWL91M7/6h+/iA+/dy9ThI4ixXHLFdl79htcxNFgm/dwT2GWZRAjdhKeiQUCUaG6JVpbSmj3DicNnWTXdZN3GQXxsiSN4an8d2zpHK4P+sUFWXzZG3ukU6f7ca2h1bNp0U51z6RMCcOL1vR9ZPV59RT7an0sptkGFuBzRymKePtymvz9i82qhNb3I4sQSrbhHso1XsurSVeo7S0SNIcaTLWhPokQxEnWztdaCN8JQP+GytSRxDJUefCfDWgulGL+0iK2W2fuO/8P/e8/f838PHpHBnrLu+o5v5wsf+Bv6+qoQguYoQRFUiUW02Upl5batvOvpQ5Qj+OE772Ss2ubn/vg3kaCYnl5CGlRRsaWI0KjhNCD7T8JiDbHFBxZlga4g4b2XWm2GmdIJSqbNuck2evgI/Z15Bkaq9K3oJbVVDhx3DI/0sH1ridBY0hC8GBFCvZWbxXrp1On272/+q+bbIoC07e9dXEzviaibZKRPpRRL2sooxcptV1XIWh0akw1qc036X3Qrm//NPWoHVgvNGmR1WkcfZ+mJJxhcfT1UbEHURxESQFFYNYQIZGmKdlKMETwQap6oVKY+Nc1H3vthwuwM7/2pH9HhteuZfvhTrB0fwalSNkIk5nzu2nlPb38vZnqCP/+pH6UyNEDzwJM81mhy8OHHuOIlt9GeW1BrI0A1bzoxxhQPfcUgMr9UrC0hgFfUKzYEaZw+het9ho3X3UxUXsF660Fg6eATTP/9JwgTiwyuE+64aRCCks7PICJirJDX25rP1OPmYmepXnO/qiDR/XcSXfbh9sP7v1V+YaWG3c2Oz+OhHhv1JGSZpzXbwPvA/Nklhm6/ibGX3YWbPkJ2/CHFp0jUR3V0kFb/Y5w9W5E1m6+EvCvVqZbRNaNobxky1/XDUqzGUiyeUWyZPTuNbbRZMzrIE3/xZ7jMU+7v49L+fjb0DbKiXJKS7erIEBbTVE7VlzhcW+Lhd/+BGhEZGR7EpCmTx89yxZ2RSldnhoIxpthKZw4d6oNNq7FnpoUsRzqp4r0sNpdYWHyIzTduxjWXyM88hXqPxCUGxtdSfv3LOfbHf4udrOMzT5wYbGRR50nn2uRLbXWNzM4suB+69r70uO7ARnd1k5KlQcbnahl+ydHTSIkqJTQqYsSFqQaMDjF2wybyU08irk2SlCCz5J0lgm9RKQVOZsdIRrZTTqrYSi+mrw9JDLSaiL1YaCfnA3hcTrm3Simy9NqI1WNjdPKc61aO85Ktl1Lp6cGUy6gpQn1BCZ2UvNXm8OQk/3D8iHgUYyMaUqPS2ws+E1VfPMSuOkeDFjyFc2h/mXzTCqjX8Y2GeE05duAUK/ua0G5B7RDGWmzJ4vMW+cl9lEZXMnTdFk5+9HHWblRK1Rj1ntDOcJ2cWt2pek9vn44ryAPbkUj24g+8jNWrL1/5/QtzTvd96oxJFmKqpRxTMFRMzeZcefsV0JqDdoqJIiafOEzezlm9fTW+5UhrLU4emIS1B1m1YQOGFJozXSLHgrUYG2NLVaJyLzZOEBvR9oHxjeu56RV38cyev4PBfq5ZuZJvufpqzNAApqcK5SrLyUlBIUsxjSZX9fWAKPft34/v1Ni0dSNX3H4LebOFaCDkrqARQ8B1muStOj5rE7xDu3+ctGnMT3Hs8YP0D9XJlmpIuUx9YpaZE7Osv2Y1UbWCm51leO0A+7XEyQOz9PUlqCpprtRagSxz8qJ71pPY7K0PcO637rqXglsYuyy+p3z5xspox+Rbp6bsqbOes4uOTg7tVFlwllv6LdQb4IXQqPOhP3uSF9+xrghLZpc4/tQ5tJbReviTHDhyhJVbNtK/fhu9qzYSlXsRMeRpk05tlnzmFOXeQcr9K7BxmQ6BnT/3o3xqbJzjn/kCV69di1k5ggwPw0A/VKuQxAWFmefQaWNqdfxijXVphxW1Gr1bN3H3D7+R3r4qnVqtANVlZO0G7cUZVBVbriJxGTWOtD5P7exR5k+foXn0KPHsDCcmM8ZW9xOtGMZkbT7+4WPcgXDFizbQ6XjKEcxLwolDNVYMFcnZUqQM9Rm2byub/mu2BD83s3Xbd5zbJsIXI4CkP7mVFevU1Js6tm2IUn+HhZmUWs1Tb3oGMsE6h0vzwvkbJakknH76HNLuUDu3SMeUue22VZx94gRm4y1sfNmbqK5YiyRFJhgKcZ7mbdozp5g79Hk6S7P0rlhL3q4QV6r8mx/7HrK3fTd0MtQapJSgke1up/UiuYWAV2zu6U9TvstaKkP9uMY8zdlp1Bdy0Ob8BO3GEkOXbKdv7TbinsGCEQuekLXJa7Mc+eynMfufZNO2EodPJzzy8WOsWTeL7+RkGfQOVgmpR3NP2knpMznrRmB0EColS/+AZWRlmeG1ZbSvz8WxJOVxcyOEAlzTU72M6qhosyHRSB+DSYnyQIeBxZTGUs7UVE59colKXxnF4K3w2jffyqc+coynj9XZtHktl62NmT4yzciOn2Ljt30vQWKCmoJMR4o0WAAkprpqE+X+UU499EFmjz9N74q1RM0e0toCNkmQKMbYCMm6DSy0y+12mTfpKoBY3ubmSv3EObzPUZ/h8w71mdOkqWPDi15Fz8pLcLaXIAmEFEITsTHJwAques3rqF99NSfe/ctsWHeG6dY4B4/Ok3vLy77nJtZs7KFTbyFGaC7UibKMDeOW4dES1YGYnsES5cEStrcrueobRJLKdmgSHdpCSUrltRgL6oRSmUgNVSvE1Yi4ktFJG0wfnWFgJEFKVbw1lMsJr3jdJtJmm9DOOfb5I/Tf81Y2vua7yNttSASJSsva0gv9EFB8nmOimHU3vJTH9vwuzdlpBsZXY+MKJqkQxSVsUsaYiG4wVwTpXa5VKbIHBTdYMG0hz/B5G5e2WZo8S6PW5qY3/BDloVXkLiCmIIzQriBGDEEV32xTHVvNhre8naP/++1cMrzItu2bKQ30E0dCZ6lWpJ6ylMmj84jLWLmhQv+KMuXBhLiaYKJYSSJRDUJUIq7G6wGigesYMlE0hHcFuFGMxopoIAZKThkciTl9vMGppyZZtWkAWyrTWQSf54SgTD5zDt3wEta/6vVkjRqm1Hce1OVAXZdpXhRRj89zklKZ4Uu28/j738vQ6iniJCHuqRAlMVGcYKzpSp4vEj8vq8FVMSKEbubA5w7X6dCut1mcnOam7/oBygNDZFmKxAay+nlCv9iV+UKhbiN82qTUP8TYa97M4Xf9POty6Kk3ECtFcjLNWJpucOqZecaGLX0jJSrDZaJqjEmKDEwwBlFfGEAUDQNEMpD0A5Xgs/OUoSxPRQ9xVekZKjO8lHPmyDyNes7IWJk4NqiHViNnbla59Hu/BXV5V4KvBbBezwuXu2J78FkxMPW4PGd47SUcffws0Wf3MzJgsQZiC6Wou/XvMrmqoKpdIUdXdCHFs/Pnu7AI07OOeO0ljF96GXm7jYmTogxKioiF5RkUQrEGqEeMwbWb9FyyiWjd1UwfepihdStIYnC5Z3Ghw7lTTYZ6YHRVlWSghK0kmCSCKEJtJGJN8ZneAdIHEPmgiYhYde3CNowF8YWqJImwKJXBwPB4wZpNTNSZnWiSVCIyD1OzKXb1Rm5Zvx6XptiSgeCK3c+yfL+bny1W+zbNs4cpj6wpvs+lbF0Z09f02jsoUoqlCAxQDIoxhXRIu3yuWSaGpevHi1wYaRZIU2XUe0qbhgkhIHmKq82Tt5boXb8ddf6CKl1DkeRczvgGJTIG1l/KQx/6NOsX5khsAW7IPSuHI8bXlOkZLpP0lbDlCKKun7WmoDcFcB1CUAsQJQbV4IrKweVcmDHFUw4BEytRD/SOgYkM5Z4Oi7MpS7WMEAz9FnpHqgR1hRrR5t0MRVdz0JXei7Fo8BhjmT15lOrSPH1jG6jPnKXfNlmzJpJqb0SlYonLCbanjO0tY0pxoa4wRWsWggMfCJknNDM0DwTnyds5nY7SmzjapkV7aZZSOWX6yD4qg6P0U7gOlqsj1RebC5GCbvUel3WIEqEaQdbMiGIY6BGGVycMjFToGy1TGS5jS3GBjxGwBV4aRYgRwaWF+KzrBHL1IYjP0GVxcfEUlMgW6UYgqijVUSFKLEnFMtB05JmymLRpG0fWaSPSAhGMKiZKWDp5kKhcpWfVBkKeohqQOMGHmDNPPsQlL4o589mHiJsNRreN0HPJKPH4IKYvQWIwxquGFHW5yvk6iK5IyKnggqhXtOMJ7UDPYodqj+XggcNMPvkFRi7bwsSBx9n+8h34NCW4HETI201qZw4xdMl2JCoIfJ91SDsNpN1g7TCsGi9RqQiV3ohKX0J5sEzSmxCVYyS2F8TYYgqy3ZqixChPCbm2AaKlLGuuyH3H+LwalmvHOK8N0MLqBBtLkS0fNGJLhqyR0WkU1Yaufo7GuZPIakuMYnyFqGxI220mDzzO5juGuz4TXKtBuzbL1OGTLBx5Lxz8PDe9fCX9V4wjvbES2kHdktLMJTgfWQkiy78ctPDjqvhcwYjDECQWicqRiYYqUlrTy9byHAf/9i+Z3Hod7U4Ln7VIa4tFGshGzB3dT2P2HKObryZrt/FZh059gXZrnvqhAwz0C4MjCT19EUlPRNyTEFUTbKlbL2ejIixcnukXrytpB5/5JYCodpKlkU2ujusMazd0kuC1K+K/iFAuKiIjK8VDW26ZohVaJ2rMfPp+4m8dJGs1ict9mCjGJgmzZ08wcvoZkt4RXN4hSM7Jzz/K/AMPsXWjctlNVQbXmhDas0FTiaNYii9qO/Kmcy6EefFh0QdSQsiMIcHrgArDSWx6qXSpzSzDB3IVw9i2sk3iRZ7+/EeZmU+YuPY6xi6/HIIliiMm9j/C4NpNdBbnSFtNsrRFnjeZffox3LEDjK+t0NMfUxlIiKoxUTnCxBHE0UUWK93teDfDKabgQ9M23vsJgOjKB2m27tBZ0tYlYssXRMbL7iF0xehWC1WKjbDnZQrFMxhaWeHc459mIk5k5NZbtNOqYOOE5uw0J7/wDIMrRukdX0PW6rC0fz+Vww9x07XCyvFSqPYaNVkWG2txNZ+5zD2K00/6dvoZmtmRTp3JgXdRjzmv2Jaz30qltJHhpBptikrmFhubF0kpuiWumNU2iXAt9X2jpXDDi40d2d/mzAfeS7p0D9WxVUSRcvyRfYzO1ulfMUSn1cFnLRaeeYaFj93HigHoHypR7k+Ie2NsEneBtSBFGkCXSw3VF1njEC6Eiq02eRZOLasc1Wf5OfJ2kVoVc14oUXyML1bDELqfahC1SqwSVwub7ssVlwemP3ufnj5yELt6HdiI6f1HKJ2eYP97ztA3OshAJSXpzLPlkkh7B0thcNDESQXypfSZMK1/mtVb7+9/B/u/XCcoVXTNh2gBLXBngE8CLHw/g6Wx+OW2N/p3tmJfYctifVncmk0lemfmzblP7uFUNsjSkkNrS8wfPcT+ydNU+qp0JqfwEycZ6RdGVvVSHSyR9BVuwEQWIot0s8uKFjIiS1f4EsAX2h+yTFhq4tvh6HkJafDhBGkLIagum/xyzZfybD+MUZUiljeCxAEYKqSz1gqLM6dpnztNnsNABPGoIFHKyMAUff1CqacSosTY4T5sJw0Hm3PhN+bvT9+7/nO0zwsY78VyBco+lHuLFVU4L3IUBe7dhdy7H2E7whWo7GQR8j2Q76n9WPSSaND+dKUSfVs8HGETk/cOeVtfWmRWAu1IcJqS738KF0GlBP1jJfqHSvQOlyj1l7DlGImKqElM115N4SNVEAl6IU4UKd5sNW1zoRPqNT14HtysowdotiAvykIxRrqbCL1QdMuFERopuNkAtnTBp9tISMoRWceTOyVr5PSt6WPN5WV8p4PmwVdLxFnHdep19yvHHsvece19RXNh3UUEBCkK388XbbD7n9YgSvG+7v7HZV57MOxDZbf7NLhP1/6Tfnup376jb9BuapckrwzFdnxbzMJZx/ThNnElwsZCUraUqhHl3phkIMEmFhMVLhBrijEr0G3P1QUF0aBqutItY9Q2Gzbt5GcPn8kvWG7a6DwRFtroWMvqciloCEDoakQuaHrPL4wqiLFKImLPS66EKDFkbYdrpVSvWc/AhgitLWHj2EXGJ+lM+kR7KX/z0P/MHwe4fxfRXbvxsvsiQP9lTSmVbr/GPTuwO3aA7Mw+cOrlfHLFTaV3VkajNzo1jkhk5ZU90reqRONYiilbopIlqkTYSly4grgb54tcZFVdYg+QoEooVG0iRtUYEZFAu2ldGvZ/26O0dFdRYEbadPs69WzWtttWjGi3rF9ZLqxYdni2UIKzXGsnRUU5scUmxU2WBspUew3DN13GwLVjeJ+ipdhFVUmyufR9S19s3j70P/PHdReRgty9G/eN7hC6cy9eduLv30W0/h+Yr/xy+n3tqfxnIxsik6DBhVBeX2Xomj6qfRHloRJxb0JUitWWClYOis4sF8ItLoSDF00XDRTlsMEp9RY+DZ9cLokwuguzeS9LrpM9LZ0mIAFjCylnCKgxosbKsqJblzXTyxzI+U2HqI0jjWJPeesG4q0rCPVpjDUuSnySTTTfVfpvzR1je2l0m7i5b3bb1bt341QR3YOt/mr2K53Z/G3ifSSxqKZe7aoKpfVlotgQxVbF2mLHZi5SGBZarQvgLuuGl0NU7UZTrZZtzbVpNsMnumVRapaLTtJOeJBmE1GvReOcrnw7qJ6fBsvzY9kHF5WESlAtHojDDI8iW9bB0kkQnJUsSU/U3116e/M/6B6s7sJ8pT4F39AetoLKTrz+HnHlF9PfT6c6/956F4vgteVUVvYgfRasESl0H4U42CyTV4FnjTko53eLy+8H1LSatr6Ynmke6DzZ7VYTDN161bzhPuEXWpB2rFpzYW1WheC7Dvy86Z63ufMyUgloFAmXbITGKfDBR7gkO1X/aPnnmm/RPVh2EJ63LsxvI9ffI678Qvp7rYnGb1jyBO89WQ7DEUQB4gLg8+PTi1oQcNErhC4VF7qNNoKXZlPzjv/ktU/R1B1YATXsLQa7cLzzeKuRTdhOy2JMEVctZ2gv/hLtxkJhWVLfnSIhF1avBeag1QhGgs0namfSg/XvUwX2oc97B/y34XQXUc+96U9nU437osQnmruC2O0pxnReX6wXWVBX8cQ/MmKKmmTRtC1usS2tlvsQwAPT3aBVQHUP9soHaaTN/GM062pC8EVmIlw0HbqgKhdS1ss1C3kO1T4YKEN9tphYSy2Tna6/tf89zLD3+e98f9GaH0SgNd16m5tPl0TVkIZAGZBOESWFAOIRE/RZAOsFgAnn8VdpNOPZ2c5svpR/FOCuBwu3Z7r+oSCaGtlenW8I7aZBzEX5qy6IFzv0AunifoOHoX5IZyEEZyWN8qnmX/S+w39EdxE9Hy2tvyTAuwnh54mG3sHxbK798zY4i3cBpxA7NOSCKuJBnQgXaR+WSaPllxQ8jLeNNmkjfOjKf2Be9xQu4WJwA8BcI3ugNtc5YzqtSIQg3aBWpeAk/skLCiqwpyJUAtJuqKCRm222dKrx9u73B15o1+6izfbxL7Z/N5ttP2MkxLjgiQUku5CtWH6FZWAv+neXq9ZOxzTm2rRa2XsvNtTz4HbrfqMr99LIGtkHpNWE4INGkYAgvqhXuvDB4bwvVlToL0PWQL33VlPjZ9p/XPlNjr1Q3MGXcA/myr1krpH+plEneF/Mf5OD61Zrno8GLnKPF8W6Iqqm3ozmZ9NDX3zGP9it/A//tPa3GzU0F9x7O5NNaLXs+du42MlfbLldzRclLSoMVSM3386zqdbvKAj7nv8jXL6s9YK0Z9vvzRc654zVmEJAq+rS84v3Bf+qz+ZYIhHyNLDYot3w79m5n+yBO7EXxRgXVa3vxasif7TXPVxfyr5g200rIh5rLooULgI1dJ9oLIBDfPBWvAlL2Wf7f5v93X5k4YWKrYCyBzP629Rcx/2NSUJRfiQKJpdur4DuJkEvKqQ5b2sh1Fvx9Gy62JjJ/hjggQefPd5nN0i/F7sbQt7Of5fFZrdrXFeauAzo8sJWSJGFMuAyCEWpuKun7/9GNZt/Li4Fkab7AE0HBIMVwfoLwKIX9rnn3xM0z0PcaEuz7vbe+CnO6Y4Cuy8NbneqnN6X7l2Yak9Iqx11RQPPivmkSJ0LGiAG8hzRELml3IVa9rGL9o0v7GtH0ZcxP5M+li3mi8ZrRFAVE4oOqudB7c7S5chBQFsdOzOV+vq8/p9i4n+FfgsCyi7srZ+n1mn6PzKNpshyzGuWMxQBRAvZC8XiJl6DFTUhy0+f+xBHug9KX+jYihRZwv73MKOqR4wFjAlEpmulFzZL512jQQzeR7WWrc1nH77uvvwJ3YXs/Ge29P/c1A2AzM+0f68x1WpIpxUVTqe7uKlAWC5wXta+BkUCuHDk0iOkuqvYnPxrcAvs7WIQ9Mh5eY8RJCxv1y4CVorsg290zOJ0qu2G/lo3GJCv2ClkOcjWPZgrP8SpZj3/U1NvGAnO/9P/qkLU9UcuKC6guT/xr8nfArCvS414fxoJ5xevoF4uRAy63LdTxTsf1VrR3KL/xFUfcZ/5ckSU+RJfqApSn+r8z9pkO5W0Yy/wAheTF13H71XJAz4P8/wrvQRduMCknt8wFHWqIRBQwSLa7sjiVIelJbf7y1ntlwRXdhPYgdn6QY40F/P3mlbbgvfnC3CX+QXvIb+wqlor7X+t4GKlA6bLm4Sip47TixXBqPM+WuhEc3P5h278qPvUnq/QhfRLT9/thfXmS51frp9rtqWdWcQo3bSPWZbinG9oK2gQ868V2yBSOi+yDlrULT8rQkJpdmRmsuNbi/mur+YzzZcjONiBueQDHK0vZO8xjZYV1CHmwn4iLGPbpR0j6fvXCm5csgNdNPQf06yigHPeLHaiufn8L675BI/t2YHd+RVI/y9vaduLUGVyIvvlpcn2gu20o67IqXiYvqhCLEAWbGxWAXDFv5JI4aJ7DVG0fllVpF6Xj0nqbvGDhlpqz53uNJfm3c8ryI7tX3mM5ivRc+zE3PAxJuoL7jdYalnREKSbTcYVfle0e0BcZDcvB+f/asDd0WVISsllhGIOBtflaRUwKuR5kIWOXVj0v3PrpzjOjq+OkPrKPnJv0c5p7unOO2fPtY/ZThpjunGvL/RSarAhgFp7af3fs3I5OH/Bb30LnYw2dzGmcbI1BBBEtOMVLFhECEGX0mjiXHZ6dsL/qu7ifPbm6wZXQNmPXPsUzcaC+7kw1xTJMy1arhrIA1iRgORxNRqMxuz1CnI+OH8BXw/ci1WQaOXITXFv3B+Cz8UgIVMhkiIB3sq1M9Mx9QX3X+5+kkX2P7uN69dnucuM2Q7sxvflfzk10bnfNtuxiHqxFu2E5X1doBoR9VZeIaDLwfkL+brrih0qoKZc2oGAeA2qKqENNrGoc97Md+KJSXf/lR8L793zVXTY/5rBXV7cANpz2Y83zrUzSVORyCop3doHrGLRSvm1p3ZQ4d7uuy9gl8DOvUHfwbDprb7St7wqYn3bQS7YSDQsZjJ9Lk9bTfejAF/NIvYvAld2E3QHdvNHeHpuzv2GWWxFEDzOoh0HVoz3mscrKhvGbu55rUhBAr1wfcKdVkDzkTXfZ3vjUc3TTESNrzmsjVDnvCyk0fyC/43r7mff/XcSfa389NfmF/cS9uzATpzKf2n6bHrQ1juxGBu0ll9Ih0ikpq/nJxQM974wowYF4a67wqmfoGJ6B340tHItqhc9YckTlY1nPk1OTebP1Jb8L+suzHJG95sGroDuAG77HO36kvvhznRHjKrSNtDJAbGu41000nNz9hs9bxAh3L/rG3P87Tf0uv9OK7I7rLxu04/ZvmSzbzWdGGy+kKKZQXxg/mwW5ubd2277HO29X8Mi9o/w+hc8+a5jP7Uz+v11Wyo/6MulLCRZJOM9oCZEPSXjO+7M4udPXTXyW7sasPv5F4Rc8LVGjITO/+rdajdf+pg05yva7iDBSePpBuU4cnHbJfsPZ79z1Uf9j95/J9HdD/7LFJj/snBpOfadcj+zcDY9ZSVEukTQWhsRjGtn3g5V1g9cu+odIrsDv39D9IJxBw/caVRVzMZtvx/ZrDe0W0GMSjrRgo4J1oX45Kn80NIJ/7N7dmD/Je7g6wJ3Ofa97kEWF+b8j7iZjrHGqD+bdw9rw/paJ4/Gh9/i/mD8LfK2R3P9vRvi5x3dL9wQyd0POvfX1/9K3B/f5WZnMzHGhmaHzulcSxXRpalM5mfdW17yDPXzY30uwV2Ofe+/k2jzh/wHp8+l77HqY+Os91MtRDyae+ObqZPxFf+7/burXvF8A6xfuCGWGx/Nsz3XvC0a6vnPbupMThAr6mkc6hCbyMcdF5+bCe+48bN86v47iXZ+nWpM+bqn2S7kiQfoX39J8vjw2solnWbuzYbY2BX9BK9q+ypCqZKGc3Ovjt9y9n79vRti3vaoe67SQKoID+yycvdul/71jW9O+vv+0M0ed9rJxIqXxqE67qz6gT6JT5zIHn/sqLuVK/A79n5Vh8pdOOrqG2m5/8Q9zPu3pIuZJL2J+lO5+loLY5BQbwfSdsmsXf0h95fbv1fe9miOKrrnmx8D654dVkRU7t7t3N/d8TPJ8OAf+tnjLjQ7Yk2Q1qkGzaO5VvusTE+6bHbe/bud+8m+Bneg3xS38I/dw5YP+Y/PzGS/bpyL4zjy2YEmodFGjJjQaAdtLFTsiqE/8x+8aTciRnbi9f47oy91uPzXBeoujOoeKzv3et2l/f4Tr/gD22d/zU0840KzLVGEtM80qO3L6R0s+VDPo6lp959v/QxP6lfB0z4nbuFZ7mEH5oG9yFVvTD47sja5KcslT9Pclrf3YPoqBI9KJdZoxWjk2/JQWJz7yeR7jz60bGGwl6/lfMd/9h727DDs2IFIcXR3/le33GNGxn7L6MI2d/JwRsAaCdI+02TxqYy+kZKrep8cPpH+7fb7wmu/nrDrmwbusrXIbsIzr+Ly8ZXJ5/vGy+U8RdrNTJKtZcrjPbhgEIOzg/1JoORR+X2zNPtb8r0nDy7fzv333xHdNbNS2bdXufdLC6a79WrCXXca7vphFXmDX34u+lc3X+NGxn/K+tYbpXaWfH4mExtHJuTUnmnQOOrpHymFmGCnz6SnT511N97+Wubu3Q27v4Film8osbL85I9/m/l3l6xN3h164yykRM3FFLs2obq5B6IY1eCJIhuNDhifx20R/irk6bujX9z3aXmU/B/fourPG/buL+51x3aFe1XOlzF1wb6B2P3CS+8yPf0/ANl3mHw2cROnHd5jImtCM2X+6Sb5jNA/mqjFa20q4+yc3n3jg+7Te76B7uCbAi6A3kkkD+LOvi76w9Vrkjf7cpSBRK2ZjNATKG8uEw2XUSyqwUsURdFwv2CqeEkOqHK/+PxB6zpPMjsxIW+Zq/+z3/Mn9KT9N18i5f5rTal8J2LuiEJ7G9kcbupcUJd7YyNrg6NxtsPcF1MSjRgYS1AXXFjIkqPn8h+97sHwO99od/DNAxdk7w7MpmOU1m+OHlqxunS1T6IcweZ1R9p2yIihvK5E1BeDGA0BjzEm6qlE9FUhKuHyJEfiGTFmKoiZM9Y0gxjBS0VEB1FdRQjjUZJH5C1YWsA1605dUGusQbxkcxlLh1I6M0rfYEKlL8LlwZl6lhyfyN9z1Sf8m79ZwH5TwL3Y/z51J9vWr4k/PzCaVH1kFStGvZIuZXTygBkUymsTkqESEkegGtSHoKhgYxvFsSGJi1L85V4QAmQZpCl55lS8c4CKiBEjRlNHZy6jdjIjmw1USjG9QwkmEvIseJp5fGYye+TEcX974zrcVxnPvnDAvZjcOfqt9vWrV0Tvs71xjjW2WyaLz6Fd96RtBz2QrIhIhi1xj8WULMYaDSJFJWdxWgHni+2KE0TEAMGrhMyTNRytcxntSY9rCuVKRN9oTBQZghe8CyG0czM7lS2cXXA33fl5jn+1hyO/4MC92P8efbX9xU1rkrfnpTgToWj/FBnEFh1Js7qnXc/JfSFJNT1CVDXYqmBLgkSCsRcpOh34TiBvKVnNk9cDIRMiY6j2RpR7i4JpVUG94l3QkPqwOJPZkzP5q+58hI/q15iyeeGBC7J8ruXpb4/+du148prMRpmxJioOG0PFFiaoviifzVMlazmytsflAR+0y8N36xCsKVSsAtYaopKhVLEkZYNNus0mvBQVTwWwhNy5fDFPjkz4H7rtkfC730w/e/EVfZOfnO56sKAnH/2Q+75I9FNjK7kqlzgXFVt0MunmtxVMYrRUEin32wJMX1S+qofzxZvLpbdGur5Blgu2VD34XIXlB+ICLnWORp4cn3LvvO0R/d3l2fRc8Brf9PT3clB+46Mszcz4b5+dzefIQhQ8IWSIZsXh1BQnxqAuqPeqiqgWlq0mMWrLVqOy1ahkNCpbNbHR7g5j+eyi7lE2xUkGwQXyzDvTdMnJaf/+Wz6n//H+O4l48LmriXtOtAXLyc2rP82xudn8OxsLaYYPBC+qaooyi1ykqKWRbvmB4r0QnBBccUB1AaAhqBAwqDEaVAhqlkXZBFf0P8oz72m75NSse+TIYniT7sI88OA3LzJ4zn3ul1rgDr7MfN/aseRPTE8pE2utmO4BFabbqrGoboMghccIWpiogFjR5VPQWD7ZKwBepbt44VLnQ8vFU/PuxOlJf9srD3JuuUL5uRzvc6qKkQdxeifRto+FPz03637OtvMkOO+DUwleiyjAQfCC5iLLfTbP13p4CBmiTlj2ryFDQq7ineK9kmUhZC0fzc25uclp/+pXHuTcnqKK/DnPRD8voo3zIdor4t/dsCp5WycppRiJi+5QywXLXbM03TrN5Rv2IrLclndZAO6Lh+NdCK7pZGEucxNz7uX/5mk++VxFBi8ccLsUpezFn3xV/L41K8qvb8VJZkw3RDNd1+CDYLnQ90GKQ4rkogoxvBKcindBXctpbT6z5+r67Xd9wf/t8wnsc+4WnpXB6GaQj+3L33h6qvOJpJMm3gWnDkKuoq5QphKWK0VNt8ZOChccIDjF5youD+o6PrQWs+jcnHvLCwHY581yL7JgIxA+vIX+K7bGnxgbrdzQieIMkWi5IwECWFUNF8W5XdPVPOBzT972Ia/n8ekF/2N3PBp++7mMZV9wlnvRkw26C/OqI9Qm5vNXT811no6yPAkBF/x5f1qEYqHof6B5IfEMuSdPHWnLhXQpi0/O+P/8QgL2eQd3OQbeswP7ooeZOn0ue8XsbPuQ7WSJy9UFVwCrOVJED9o9tBpcquSt4H3NxWcXwtvvejL8j/tfQMA+727h4ms5E3DfDazfOBx/fHigvMUncSZGovM9SYJ2T9hTdW0XfC2Lz9b8z9/+aPjFF4KPfcGCezFN+eDVbBwfjf5hZLC0JU9KmRiJlkOv4H3IWpnmtSw+txh+9s6nwq90gfW8wEpiX3Di5GWAP3o1G9cN2n9YOVja0oniDGuNhhBcmiWdxYxzS+E/vvTp8M4XosW+oK89OwrByJ6trHn8NvPxIy9N9Og9ZT360kQfvTWa/+iV5o1QJERfyON4wcrq94DdWVSD2QeuNW9LrNzhfTg71dI/+M5DHHwuyO6v9/r/AEb1TptB4Z85AAAAAElFTkSuQmCC';
    const redMarkerData =
        'data:image/png;base64,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';

    final markerData = _markerPlaces()
        .map(
          (place) => {
        'id': place.id,
        'name': place.name,
        'lat': place.latitude,
        'lng': place.longitude,

        // 백엔드의 quietScore는 그대로 전달한다.
        // JavaScript에서 100 - quietScore로
        // 혼잡도를 계산한다.
        'quiet': place.quietScore,
      },
    )
        .toList();

    final markersJson = jsonEncode(markerData);

    final mapWidth =
    widget.width.isFinite && widget.width > 0 ? widget.width : 400.0;

    final mapHeight =
    widget.height.isFinite && widget.height > 0 ? widget.height : 700.0;

    return '''
<!DOCTYPE html>
<html lang="ko">

<head>
<meta charset="utf-8" />

<meta
  name="viewport"
  content="width=device-width,
  initial-scale=1.0,
  maximum-scale=1.0,
  minimum-scale=1.0,
  user-scalable=no"
/>

<style>

* {
  box-sizing: border-box;
}

html {
  margin: 0;
  padding: 0;

  width: ${mapWidth}px;
  height: ${mapHeight}px;

  min-height: ${mapHeight}px;

  overflow: hidden;
}

body {
  margin: 0;
  padding: 0;

  width: ${mapWidth}px;
  height: ${mapHeight}px;

  min-height: ${mapHeight}px;

  overflow: hidden;

  background: #e4eee8;
}

#map {
  position: absolute;

  left: 0;
  top: 0;

  width: ${mapWidth}px;
  height: ${mapHeight}px;

  min-width: ${mapWidth}px;
  min-height: ${mapHeight}px;

  background: #e4eee8;
}

/* --------------------------------------------------
   경주한적 귀면와 혼잡도 마커
-------------------------------------------------- */

.place-marker-wrap {
  --marker-color: #D6B166;
  position: relative;
  width: 46px;
  height: 68px;
  cursor: pointer;
  transform: translateY(1px);
  -webkit-tap-highlight-color: transparent;
}

.marker-face {
  position: absolute;
  left: 50%;
  top: 0;
  width: 40px;
  height: 40px;
  transform: translateX(-50%);
  overflow: hidden;
  border-radius: 999px;
  background: #FFFDF8;
  border: 2px solid var(--marker-color);
  box-shadow: 0 3px 7px rgba(0,0,0,0.16);
  pointer-events: none;
}

.marker-art {
  position: absolute;
  left: 50%;
  top: -2px;
  width: 44px;
  height: 62px;
  object-fit: contain;
  transform: translateX(-50%);
  user-select: none;
  pointer-events: none;
}

.marker-score {
  position: absolute;
  left: 50%;
  top: 35px;
  width: 31px;
  height: 31px;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 999px;
  background: rgba(255,253,248,0.98);
  border: 2px solid var(--marker-color);
  color: #4E3C30;
  font-family: sans-serif;
  font-size: 10.5px;
  font-weight: 900;
  letter-spacing: -0.4px;
  box-shadow: 0 2px 5px rgba(0,0,0,0.14);
  pointer-events: none;
}

.marker-tip {
  position: absolute;
  left: 50%;
  bottom: 0;
  width: 0;
  height: 0;
  transform: translateX(-50%);
  border-left: 6px solid transparent;
  border-right: 6px solid transparent;
  border-top: 9px solid var(--marker-color);
  pointer-events: none;
}

/* --------------------------------------------------
   현재 위치
-------------------------------------------------- */

.current-location-marker {
  width: 22px;
  height: 22px;

  border-radius: 50%;

  background: #2f80ed;

  border: 4px solid white;

  box-shadow:
    0 2px 10px rgba(0,0,0,0.35);
}

.current-location-ring {
  width: 42px;
  height: 42px;

  border-radius: 50%;

  background:
    rgba(47,128,237,0.20);

  position: absolute;

  left: -10px;
  top: -10px;
}

</style>

<script
  src="https://dapi.kakao.com/v2/maps/sdk.js?appkey=${AppEnv.kakaoJavaScriptKey}&autoload=false&libraries=services">
</script>

</head>

<body>

<div id="map"></div>

<script>

const places = $markersJson;

const currentLatitude =
  ${widget.latitude};

const currentLongitude =
  ${widget.longitude};

// ------------------------------------------------------------
// quietScore → congestionScore
//
// 예:
// quietScore 87 → congestionScore 13
// quietScore 30 → congestionScore 70
// ------------------------------------------------------------

function congestionScore(quietScore) {

  const quiet =
    Number(quietScore);

  const congestion =
    100 - quiet;

  return Math.max(
    0,
    Math.min(
      100,
      congestion
    )
  );
}

// ------------------------------------------------------------
// 혼잡도 → 색상
//
// 0~20   매우 한산 → 파랑
// 21~40  한산      → 청록
// 41~60  보통      → 노랑
// 61~80  혼잡      → 주황
// 81~100 매우 혼잡 → 빨강
// ------------------------------------------------------------

function congestionColor(score) {

  const value = Number(score);

  if (value <= 20) {
    return '#1E88E5';
  }

  if (value <= 40) {
    return '#26A69A';
  }

  if (value <= 60) {
    return '#FBC02D';
  }

  if (value <= 80) {
    return '#F57C00';
  }

  return '#E53935';
}

// 노란색은 흰 글씨보다 진한 글씨가 잘 보인다.

function congestionTextColor(score) {

  const value = Number(score);

  if (value >= 41 && value <= 60) {
    return '#3A3520';
  }

  return '#FFFFFF';
}

const markerBlueData = '$blueMarkerData';
const markerGreenData = '$greenMarkerData';
const markerYellowData = '$yellowMarkerData';
const markerOrangeData = '$orangeMarkerData';
const markerRedData = '$redMarkerData';

function congestionMarkerImage(score) {
  const value = Number(score);

  if (value <= 20) return markerBlueData;
  if (value <= 40) return markerGreenData;
  if (value <= 60) return markerYellowData;
  if (value <= 80) return markerOrangeData;
  return markerRedData;
}

kakao.maps.load(function() {

  const container =
    document.getElementById('map');

  const center =
    new kakao.maps.LatLng(
      currentLatitude,
      currentLongitude
    );

  const options = {
    center: center,
    level: 7
  };

  const map =
    new kakao.maps.Map(
      container,
      options
    );

  window.kakaoMapInstance = map;

  // --------------------------------------------------
  // 현재 위치 표시
  // --------------------------------------------------

  const currentContent =
    document.createElement('div');

  currentContent.innerHTML = `
    <div style="position:relative;">
      <div class="current-location-ring"></div>
      <div class="current-location-marker"></div>
    </div>
  `;

  const currentOverlay =
    new kakao.maps.CustomOverlay({
      position: center,
      content: currentContent,
      xAnchor: 0.5,
      yAnchor: 0.5,
      zIndex: 10
    });

  currentOverlay.setMap(map);

  // --------------------------------------------------
  // 관광지 마커
  //
  // 중요:
  // 장소 목록이 갱신되어도 Kakao Map 자체는 새로 만들지 않습니다.
  // 마커/혼잡도 오버레이만 지우고 다시 그려 현재 중심과 줌을 유지합니다.
  // --------------------------------------------------

  let placeMarkers = [];
  let placeOverlays = [];

  function clearPlaceObjects() {
    placeMarkers.forEach(function(marker) {
      marker.setMap(null);
    });

    placeOverlays.forEach(function(overlay) {
      overlay.setMap(null);
    });

    placeMarkers = [];
    placeOverlays = [];
  }

  function drawPlaces(nextPlaces) {
    clearPlaceObjects();

    nextPlaces.forEach(function(place) {

      const position =
        new kakao.maps.LatLng(
          place.lat,
          place.lng
        );

      const congestion =
        congestionScore(
          place.quiet
        );

      // 최종 디자인의 귀면와 캐릭터 마커를 사용합니다.
      // 가운데 원에는 현재 혼잡도 수치를 표시합니다.
      const markerWrap =
        document.createElement('div');

      markerWrap.className =
        'place-marker-wrap';

      markerWrap.style.setProperty(
        '--marker-color',
        congestionColor(congestion)
      );

      const markerFace =
        document.createElement('div');

      markerFace.className =
        'marker-face';

      const markerArt =
        document.createElement('img');

      markerArt.className =
        'marker-art';

      markerArt.src =
        congestionMarkerImage(
          congestion
        );

      markerArt.alt =
        place.name || '';

      markerFace.appendChild(
        markerArt
      );

      const markerScore =
        document.createElement('div');

      markerScore.className =
        'marker-score';

      markerScore.innerText =
        String(
          Math.round(congestion)
        ) + '%';

      const markerTip =
        document.createElement('div');

      markerTip.className =
        'marker-tip';

      markerWrap.appendChild(
        markerFace
      );

      markerWrap.appendChild(
        markerScore
      );

      markerWrap.appendChild(
        markerTip
      );

      markerWrap.addEventListener(
        'click',
        function() {
          MarkerChannel.postMessage(
            String(place.id)
          );

          map.panTo(
            position
          );
        }
      );

      const overlay =
        new kakao.maps.CustomOverlay({
          position: position,
          content: markerWrap,

          // 핀의 맨 아래 꼭짓점이 실제 관광지 좌표에 닿도록 고정
          xAnchor: 0.5,
          yAnchor: 1,
          zIndex: 5
        });

      overlay.setMap(
        map
      );

      placeOverlays.push(
        overlay
      );
    });
  }

  window.updatePlaces = function(nextPlaces) {
    drawPlaces(nextPlaces || []);
  };

  drawPlaces(places);

  /*
  places.forEach(function(place) {

    const position =
      new kakao.maps.LatLng(
        place.lat,
        place.lng
      );

    const marker =
      new kakao.maps.Marker({
        position: position,
        map: map
      });

    const congestion =
      congestionScore(
        place.quiet
      );

    const label =
      document.createElement('div');

    label.className =
      'congestion-label';

    // 이제 지도에 표시되는 숫자는
    // 한적도가 아니라 혼잡도
    label.innerText =
      String(
        Math.round(congestion)
      ) + '%';

    label.style.backgroundColor =
      congestionColor(
        congestion
      );

    label.style.color =
      congestionTextColor(
        congestion
      );

    label.addEventListener(
      'click',
      function() {

        MarkerChannel.postMessage(
          String(place.id)
        );
      }
    );

    const overlay =
      new kakao.maps.CustomOverlay({
        position: position,
        content: label,
        yAnchor: 1,
        zIndex: 5
      });

    overlay.setMap(map);

    kakao.maps.event.addListener(
      marker,
      'click',
      function() {

        MarkerChannel.postMessage(
          String(place.id)
        );

        map.panTo(position);
      }
    );
  });
  */

  // --------------------------------------------------
  // 지도 이동이 끝났을 때 현재 중심 좌표를 Flutter로 전달
  // --------------------------------------------------


  window.searchKakaoPlace = function(rawQuery) {
    const query = String(rawQuery || '').trim();

    if (!query) {
      PlaceSearchChannel.postMessage(JSON.stringify({
        status: 'zero_result',
        query: query
      }));
      return;
    }

    if (!kakao.maps.services) {
      PlaceSearchChannel.postMessage(JSON.stringify({
        status: 'error',
        query: query
      }));
      return;
    }

    const placesService = new kakao.maps.services.Places();

    placesService.keywordSearch(
      query,
      function(data, status) {
        if (
          status !== kakao.maps.services.Status.OK ||
          !data ||
          data.length === 0
        ) {
          PlaceSearchChannel.postMessage(JSON.stringify({
            status: 'zero_result',
            query: query
          }));
          return;
        }

        const normalize = function(value) {
          return String(value || '')
            .toLowerCase()
            .replace(/\s+/g, '')
            .replace(/[^0-9a-z가-힣]/g, '');
        };

        const normalizedQuery = normalize(query);
        let selected = data[0];

        for (const item of data) {
          if (normalize(item.place_name) === normalizedQuery) {
            selected = item;
            break;
          }
        }

        const latitude = Number(selected.y);
        const longitude = Number(selected.x);

        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
          PlaceSearchChannel.postMessage(JSON.stringify({
            status: 'error',
            query: query
          }));
          return;
        }

        const position = new kakao.maps.LatLng(
          latitude,
          longitude
        );

        map.panTo(position);

        if (map.getLevel() > 5) {
          map.setLevel(4, {
            anchor: position
          });
        }

        PlaceSearchChannel.postMessage(JSON.stringify({
          status: 'ok',
          query: query,
          name: selected.place_name || query,
          latitude: latitude,
          longitude: longitude,
          kakao_place_id: selected.id || '',
          address: selected.road_address_name ||
                   selected.address_name ||
                   '',
          category_name: selected.category_name || '',
          place_url: selected.place_url || ''
        }));
      },
      {
        location: map.getCenter()
      }
    );
  };

  kakao.maps.event.addListener(
    map,
    'dragstart',
    function() {
      MapDragChannel.postMessage('dragstart');
    }
  );

  kakao.maps.event.addListener(
    map,
    'idle',
    function() {
      const movedCenter = map.getCenter();
      const bounds = map.getBounds();
      const southWest = bounds.getSouthWest();
      const northEast = bounds.getNorthEast();

      MapMoveChannel.postMessage(
        JSON.stringify({
          latitude: movedCenter.getLat(),
          longitude: movedCenter.getLng(),
          south: southWest.getLat(),
          west: southWest.getLng(),
          north: northEast.getLat(),
          east: northEast.getLng()
        })
      );
    }
  );

  // --------------------------------------------------
  // Android WebView 지도 크기 재계산
  // --------------------------------------------------

  setTimeout(function() {

    map.relayout();

    map.setCenter(center);

  }, 100);

  setTimeout(function() {

    map.relayout();

  }, 500);

  window.addEventListener(
    'resize',
    function() {

      map.relayout();

    }
  );
});

</script>

</body>

</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: WebViewWidget(
        controller: _controller,
      ),
    );
  }
}

// ============================================================
// 프리뷰 지도
// ============================================================

class _PreviewMap extends StatelessWidget {
  const _PreviewMap({
    required this.places,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Place> places;
  final String? selectedId;
  final ValueChanged<Place> onSelected;

  @override
  Widget build(BuildContext context) {
    final visible = places.take(6).toList();

    const positions = [
      Alignment(-0.72, -0.48),
      Alignment(0.55, -0.27),
      Alignment(-0.2, 0.02),
      Alignment(0.65, 0.25),
      Alignment(-0.55, 0.46),
      Alignment(0.05, 0.58),
    ];

    return Container(
      color: const Color(0xFFDCE9E2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _MapPainter(),
          ),
          for (var i = 0; i < visible.length; i++)
            Align(
              alignment: positions[i],
              child: GestureDetector(
                onTap: () => onSelected(
                  visible[i],
                ),
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 200,
                  ),
                  width: selectedId == visible[i].id ? 56 : 48,
                  height: selectedId == visible[i].id ? 56 : 48,
                  decoration: BoxDecoration(
                    color: _congestionColor(
                      _congestionScore(
                        visible[i].quietScore,
                      ),
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(
                          0x35254B42,
                        ),
                        blurRadius: 18,
                        offset: Offset(
                          0,
                          8,
                        ),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${_congestionScore(visible[i].quietScore)}',
                      style: TextStyle(
                        color: _congestionTextColor(
                          _congestionScore(
                            visible[i].quietScore,
                          ),
                        ),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// 혼잡도 계산
// ============================================================

int _congestionScore(int quietScore) {
  return (100 - quietScore).clamp(0, 100);
}

// ============================================================
// 혼잡도 색상
// ============================================================

Color _congestionColor(int score) {
  if (score <= 20) {
    return const Color(
      0xFF1E88E5,
    );
  }

  if (score <= 40) {
    return const Color(
      0xFF26A69A,
    );
  }

  if (score <= 60) {
    return const Color(
      0xFFFBC02D,
    );
  }

  if (score <= 80) {
    return const Color(
      0xFFF57C00,
    );
  }

  return const Color(
    0xFFE53935,
  );
}

Color _congestionTextColor(int score) {
  if (score >= 41 && score <= 60) {
    return const Color(
      0xFF3A3520,
    );
  }

  return Colors.white;
}

// ============================================================
// 프리뷰 지도 배경
// ============================================================

class _MapPainter extends CustomPainter {
  @override
  void paint(
      Canvas canvas,
      Size size,
      ) {
    final park = Paint()
      ..color = const Color(
        0xFFC1D9C6,
      );

    final water = Paint()
      ..color = const Color(
        0xFFB4D1D3,
      );

    final road = Paint()
      ..color = const Color(
        0xFFFDFBF5,
      )
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final minorRoad = Paint()
      ..color = const Color(
        0xE8FFFFFF,
      )
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    canvas.drawOval(
      Rect.fromLTWH(
        size.width * .68,
        size.height * .12,
        180,
        130,
      ),
      park,
    );

    canvas.drawOval(
      Rect.fromLTWH(
        -50,
        size.height * .62,
        190,
        140,
      ),
      park,
    );

    canvas.save();

    canvas.translate(
      size.width * .45,
      size.height * .45,
    );

    canvas.rotate(-.24);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: size.width * 1.4,
        height: 86,
      ),
      water,
    );

    canvas.restore();

    canvas.drawLine(
      Offset(
        20,
        size.height * .25,
      ),
      Offset(
        size.width - 15,
        size.height * .42,
      ),
      road,
    );

    canvas.drawLine(
      Offset(
        40,
        size.height * .73,
      ),
      Offset(
        size.width - 20,
        size.height * .59,
      ),
      road,
    );

    canvas.drawLine(
      Offset(
        size.width * .62,
        30,
      ),
      Offset(
        size.width * .48,
        size.height - 30,
      ),
      road,
    );

    canvas.drawLine(
      Offset(
        0,
        size.height * .52,
      ),
      Offset(
        size.width,
        size.height * .19,
      ),
      minorRoad,
    );

    canvas.drawLine(
      Offset(
        size.width * .12,
        0,
      ),
      Offset(
        size.width * .82,
        size.height,
      ),
      minorRoad,
    );
  }

  @override
  bool shouldRepaint(
      covariant CustomPainter oldDelegate,
      ) =>
      false;
}

// ============================================================
// 선택 장소 카드
// ============================================================

class _MapPlaceCard extends StatelessWidget {
  const _MapPlaceCard({
    required this.place,
    required this.isSaved,
    required this.onSaved,
    required this.onDetail,
  });

  final Place place;
  final bool isSaved;
  final VoidCallback onSaved;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final congestion =
    _congestionScore(
      place.quietScore,
    );

    final congestionColor =
    _congestionColor(
      congestion,
    );

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F0).withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD6B166),
          width: 1.1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: SizedBox(
              width: 82,
              height: 82,
              child: PlaceImage(
                place: place,
                hero: false,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4A382C),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      height: 32,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: onSaved,
                        icon: Icon(
                          isSaved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: const Color(0xFFB44932),
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: congestionColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        place.hasLocalDistance
                            ? '혼잡도 $congestion% · ${place.distanceKm.toStringAsFixed(1)}km'
                            : '혼잡도 $congestion%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF786B61),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: onDetail,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF315E4F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(112, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '장소 자세히 보기',
                      style: TextStyle(
                        fontSize: 11,
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