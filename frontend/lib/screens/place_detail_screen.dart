import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/place.dart';
import '../models/community.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'community_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({
    required this.place,
    super.key,
  });

  final Place place;

  @override
  State<PlaceDetailScreen> createState() =>
      _PlaceDetailScreenState();
}

class _PlaceDetailScreenState
    extends State<PlaceDetailScreen> {
  Place? _detailPlace;

  bool _startedLoading = false;
  bool _isLoadingCore = true;
  bool _isLoadingMore = false;

  Object? _loadError;
  Map<String, dynamic> _liveSummary = const <String, dynamic>{};
  bool _isLoadingLiveSummary = false;

  bool _showAllContent = false;
  _ContentFilter _contentFilter =
      _ContentFilter.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_startedLoading) {
      return;
    }

    _startedLoading = true;

    final controller = AppScope.of(
      context,
      listen: false,
    );

    _loadDetails(
      controller,
    );
  }

  Future<void> _loadDetails(
      AppController controller,
      ) async {
    try {
      final core =
      await controller.fetchPlaceDetail(
        widget.place,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detailPlace = core;
        _isLoadingCore = false;
        _isLoadingMore = true;
      });

      _loadLiveSummary(controller, core.id);

      try {
        final full = await controller
            .fetchPlaceDetailExtras(
          core,
        );

        if (!mounted) {
          return;
        }

        setState(() {
          _detailPlace = full;
          _isLoadingMore = false;
        });
      } catch (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isLoadingMore = false;
          _loadError = error;
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCore = false;
        _isLoadingMore = false;
        _loadError = error;
      });
    }
  }

  Future<void> _loadLiveSummary(
      AppController controller,
      String placeId,
      ) async {
    if (placeId.trim().isEmpty) return;

    setState(() {
      _isLoadingLiveSummary = true;
    });

    final summary = await controller.getCommunityLiveSummary(placeId);
    if (!mounted) return;

    setState(() {
      _liveSummary = summary;
      _isLoadingLiveSummary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    final rawPlace =
        _detailPlace ?? widget.place;

    final place =
    _normalizePlace(rawPlace);

    final congestion =
    (100 - place.quietScore)
        .clamp(0, 100)
        .toInt();

    final isCheckingDetails =
        _isLoadingCore ||
            _isLoadingMore;

    final isFood =
    _isFoodOrCafe(place);

    final hasMenu =
        place.menuItems.isNotEmpty ||
            place.representativeMenu
                .trim()
                .isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(
            context,
            controller,
            place,
            congestion,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              18,
              20,
              18,
              132,
            ),
            sliver: SliverList.list(
              children: [
                _PlaceIdentity(
                  category:
                  _displayCategory(place),
                  place: place,
                ),

                const SizedBox(height: 18),

                _QuickActions(
                  isSaved:
                  controller.isSaved(
                    place.id,
                  ),
                  onDirections: () =>
                      _openKakaoDirections(
                        place,
                        context,
                      ),
                  onSave: () async {
                    await controller
                        .toggleSaved(
                      place,
                    );

                    if (!context.mounted) {
                      return;
                    }

                    showAppSnackBar(
                      context,
                      controller.isSaved(
                        place.id,
                      )
                          ? '저장한 장소에 추가했어요.'
                          : '저장을 해제했어요.',
                    );
                  },
                  onCopyAddress: () =>
                      _copyAddress(
                        place,
                        context,
                      ),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => CommunityWriteScreen(
                          initialType: CommunityPostType.live,
                          initialPlace: place,
                        ),
                      ),
                    );
                    if (!mounted) return;
                    await _loadLiveSummary(controller, place.id);
                  },
                  icon: const Icon(Icons.campaign_outlined),
                  label: const Text('이 장소 현장 혼잡 제보'),
                ),

                const SizedBox(height: 8),

                _SummaryGrid(
                  place: place,
                  congestion: congestion,
                ),

                if (_isLoadingLiveSummary ||
                    ((_liveSummary['report_count'] as num?)?.toInt() ?? place.communityReportCount) > 0) ...[
                  const SizedBox(height: 14),
                  _CommunityCrowdSummaryCard(
                    systemCongestion: congestion,
                    summary: _liveSummary,
                    fallbackPlace: place,
                  ),
                ],

                if (isCheckingDetails) ...[
                  const SizedBox(height: 16),
                  _DetailLoadingBanner(
                    text: _isLoadingCore
                        ? '방문 정보를 불러오고 있어요.'
                        : '최신 방문 정보를 확인하고 있어요.',
                  ),
                ],

                if (isFood) ...[
                  if (hasMenu) ...[
                    const SizedBox(
                      height: 28,
                    ),
                    _MenuSection(
                      place: place,
                    ),
                  ] else if (_isLoadingMore) ...[
                    const SizedBox(
                      height: 28,
                    ),
                    const _SectionTitle(
                      title: '대표 메뉴',
                      icon:
                      Icons.restaurant_menu,
                    ),
                    const SizedBox(
                      height: 12,
                    ),
                    const _InlineLoadingCard(
                      text:
                      '대표 메뉴를 확인하고 있어요.',
                    ),
                  ],
                ],

                const SizedBox(height: 28),

                _PracticalInfoCard(
                  place: place,
                  isLoading:
                  isCheckingDetails,
                  onOpenDaumSearch: () =>
                      _launch(
                        _daumSearchUri(place),
                        context,
                      ),
                  onOpenNaverBlog: () =>
                      _launch(
                        _naverBlogSearchUri(place),
                        context,
                      ),
                  onOpenYoutube: () =>
                      _launch(
                        _youtubeSearchUri(place),
                        context,
                      ),
                  onOpenHomepage:
                  place.homepage
                      .trim()
                      .isEmpty
                      ? null
                      : () => _launch(
                    Uri.tryParse(
                      place.homepage,
                    ),
                    context,
                  ),
                  onOpenKakao: () =>
                      _launch(
                        _kakaoInfoUri(place),
                        context,
                      ),
                  onOpenContent: (link) =>
                      _launch(
                        Uri.tryParse(link.url),
                        context,
                      ),
                ),

                if (
                place.contentLinks
                    .isNotEmpty
                ) ...[
                  const SizedBox(height: 28),

                  const _SectionTitle(
                    title: '관련 콘텐츠',
                    icon: Icons
                        .collections_bookmark_outlined,
                  ),

                  const SizedBox(height: 12),

                  _ContentFilterRow(
                    selected:
                    _contentFilter,
                    onChanged: (filter) {
                      setState(() {
                        _contentFilter =
                            filter;
                        _showAllContent =
                        false;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  _ContentList(
                    links: _filteredLinks(
                      place.contentLinks,
                    ),
                    showAll:
                    _showAllContent,
                    onOpen: (link) =>
                        _launch(
                          Uri.tryParse(
                            link.url,
                          ),
                          context,
                        ),
                  ),

                  if (_filteredLinks(
                    place.contentLinks,
                  ).length >
                      3)
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showAllContent =
                            !_showAllContent;
                          });
                        },
                        icon: Icon(
                          _showAllContent
                              ? Icons.expand_less
                              : Icons.expand_more,
                        ),
                        label: Text(
                          _showAllContent
                              ? '간단히 보기'
                              : '관련 콘텐츠 더보기',
                        ),
                      ),
                    ),
                ] else if (_isLoadingMore) ...[
                  const SizedBox(height: 28),
                  const _SectionTitle(
                    title: '관련 콘텐츠',
                    icon: Icons
                        .collections_bookmark_outlined,
                  ),
                  const SizedBox(height: 12),
                  const _InlineLoadingCard(
                    text:
                    '관련 콘텐츠를 확인하고 있어요.',
                  ),
                ],

                if (
                _loadError != null &&
                    !isCheckingDetails
                ) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding:
                    const EdgeInsets.all(
                      14,
                    ),
                    decoration:
                    BoxDecoration(
                      color: const Color(
                        0xFFFFF6E7,
                      ),
                      borderRadius:
                      BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color:
                          AppColors.gold,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 9,
                        ),
                        Expanded(
                          child: Text(
                            '일부 정보를 확인하지 못했어요. 현재 확인된 정보만 보여드려요.',
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar:
      _BottomActionBar(
        onDirections: () =>
            _openKakaoDirections(
              place,
              context,
            ),
      ),
    );
  }

  SliverAppBar _buildAppBar(
      BuildContext context,
      AppController controller,
      Place place,
      int congestion,
      ) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.paper,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.only(
          left: 8,
        ),
        child: IconButton.filled(
          onPressed: () =>
              Navigator.of(context).pop(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black
                .withValues(alpha: 0.30),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(
            Icons.arrow_back,
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            PlaceImage(
              place: place,
              hero: false,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x52000000),
                    Colors.transparent,
                    Color(0x8F12251F),
                  ],
                ),
              ),
            ),

            Positioned(
              left: 18,
              bottom: 20,
              child: _CongestionBadge(
                congestion: congestion,
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton.filled(
          tooltip: '주소 복사',
          onPressed: () => _copyAddress(
            place,
            context,
          ),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black
                .withValues(alpha: 0.30),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(
            Icons.ios_share_outlined,
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding:
          const EdgeInsets.only(right: 10),
          child: IconButton.filled(
            tooltip: '저장',
            onPressed: () async {
              await controller.toggleSaved(
                place,
              );

              if (!context.mounted) {
                return;
              }

              showAppSnackBar(
                context,
                controller.isSaved(place.id)
                    ? '저장한 장소에 추가했어요.'
                    : '저장을 해제했어요.',
              );
            },
            style: IconButton.styleFrom(
              backgroundColor:
              controller.isSaved(place.id)
                  ? AppColors.gold
                  : Colors.black
                  .withValues(
                alpha: 0.30,
              ),
              foregroundColor: Colors.white,
            ),
            icon: Icon(
              controller.isSaved(place.id)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
            ),
          ),
        ),
      ],
    );
  }

  Place _normalizePlace(Place place) {
    final detailName = place.name.trim();
    final seedName =
    widget.place.name.trim();

    final detailLooksLikeId =
    RegExp(r'^\d+$')
        .hasMatch(detailName);

    final usableSeedName =
        seedName.isNotEmpty &&
            !RegExp(r'^\d+$')
                .hasMatch(seedName);

    if (detailLooksLikeId &&
        usableSeedName) {
      return Place(
        id: place.id,
        name: seedName,
        address: place.address,
        latitude: place.latitude,
        longitude: place.longitude,
        quietScore: place.quietScore,
        category: place.category,
        description: place.description,
        imageUrl: place.imageUrl,
        imageAsset: place.imageAsset,
        distanceKm: place.distanceKm,
        hasLocalDistance: place.hasLocalDistance,
        recommendedTime:
        place.recommendedTime,
        stayMinutes:
        place.stayMinutes,
        isPaid: place.isPaid,
        contentTypeId:
        place.contentTypeId,
        etiquette: place.etiquette,
        contentLinks:
        place.contentLinks,
        blogCount: place.blogCount,
        videoCount: place.videoCount,
        operatingHours:
        place.operatingHours,
        operatingHoursLabel:
        place.operatingHoursLabel,
        breakTime: place.breakTime,
        restDate: place.restDate,
        feeText: place.feeText,
        parking: place.parking,
        phone: place.phone,
        homepage: place.homepage,
        kakaoPlaceUrl:
        place.kakaoPlaceUrl,
        representativeMenu:
        place.representativeMenu,
        menuItems: place.menuItems,
        isRestPoint:
        place.isRestPoint,
        communityCongestionScore:
        place.communityCongestionScore,
        communityReportCount:
        place.communityReportCount,
        communityLatestObservedAt:
        place.communityLatestObservedAt,
        routingCongestionScore:
        place.routingCongestionScore,
      );
    }

    return place;
  }

  bool _isFoodOrCafe(Place place) {
    return place.category == '맛집' ||
        place.category == '카페' ||
        place.contentTypeId == '39';
  }

  String _displayCategory(
      Place place,
      ) {
    final category = place.category.trim();

    if (category == '맛집' ||
        category == '카페' ||
        category == '음식점' ||
        place.contentTypeId == '39') {
      return category.isEmpty ? '맛집' : category;
    }

    return place.tourismCategory;
  }

  List<ContentLink> _filteredLinks(
      List<ContentLink> links,
      ) {
    switch (_contentFilter) {
      case _ContentFilter.blog:
        return links.where(_isBlog).toList();

      case _ContentFilter.video:
        return links.where(_isVideo).toList();

      case _ContentFilter.web:
        return links.where((link) => !_isVideo(link) && !_isBlog(link)).toList();

      case _ContentFilter.all:
        return links;
    }
  }

  bool _isBlog(ContentLink link) {
    final type = link.type.toLowerCase();
    final url = link.url.toLowerCase();
    return type.contains('blog') || url.contains('blog.naver.com');
  }

  bool _isVideo(ContentLink link) {
    final type =
    link.type.toLowerCase();
    final url =
    link.url.toLowerCase();

    return type.contains('youtube') ||
        type.contains('video') ||
        url.contains('youtube.com') ||
        url.contains('youtu.be');
  }

  String _placeSearchQuery(Place place) {
    final name = place.name.trim();
    if (name.contains('경주')) {
      return name;
    }
    return '경주 $name';
  }

  Uri _daumSearchUri(Place place) {
    return Uri.https(
      'search.daum.net',
      '/search',
      <String, String>{
        'q': _placeSearchQuery(place),
      },
    );
  }

  Uri _naverBlogSearchUri(Place place) {
    return Uri.https(
      'search.naver.com',
      '/search.naver',
      <String, String>{
        'where': 'blog',
        'query': _placeSearchQuery(place),
      },
    );
  }

  Uri _youtubeSearchUri(Place place) {
    return Uri.https(
      'www.youtube.com',
      '/results',
      <String, String>{
        'search_query': _placeSearchQuery(place),
      },
    );
  }

  Uri _kakaoInfoUri(Place place) {
    final direct = place.kakaoPlaceUrl.trim();
    if (direct.isNotEmpty) {
      final uri = Uri.tryParse(direct);
      if (uri != null) {
        return uri;
      }
    }

    final encodedName =
    Uri.encodeComponent(place.name);
    return Uri.parse(
      'https://map.kakao.com/link/map/$encodedName,${place.latitude},${place.longitude}',
    );
  }

  Future<void> _copyAddress(
      Place place,
      BuildContext context,
      ) async {
    final text = [
      place.name,
      if (place.address.trim().isNotEmpty)
        place.address.trim(),
      'https://map.kakao.com/link/map/${Uri.encodeComponent(place.name)},${place.latitude},${place.longitude}',
    ].join('\n');

    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!context.mounted) {
      return;
    }

    showAppSnackBar(
      context,
      '장소 정보와 주소를 복사했어요.',
    );
  }

  Future<void> _openKakaoDirections(
      Place place,
      BuildContext context,
      ) async {
    final encodedName =
    Uri.encodeComponent(
      place.name,
    );

    final uri = Uri.parse(
      'https://map.kakao.com/link/to/$encodedName,${place.latitude},${place.longitude}',
    );

    await _launch(
      uri,
      context,
    );
  }

  Future<void> _launch(
      Uri? uri,
      BuildContext context,
      ) async {
    if (uri == null ||
        !await launchUrl(
          uri,
          mode:
          LaunchMode.externalApplication,
        )) {
      if (!context.mounted) {
        return;
      }

      showAppSnackBar(
        context,
        '연결할 앱 또는 주소를 열 수 없어요.',
      );
    }
  }
}

class _DetailLoadingBanner extends StatelessWidget {
  const _DetailLoadingBanner({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.sage
            .withValues(
          alpha: 0.48,
        ),
        borderRadius:
        BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.forest,
                fontSize: 11.5,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLoadingCard
    extends StatelessWidget {
  const _InlineLoadingCard({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration:
      softCardDecoration(),
      child: Row(
        children: [
          const SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}


class _PlaceIdentity
    extends StatelessWidget {
  const _PlaceIdentity({
    required this.category,
    required this.place,
  });

  final String category;
  final Place place;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(
              0xFFFFF4DF,
            ),
            borderRadius:
            BorderRadius.circular(999),
          ),
          child: Text(
            category,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          place.name,
          style: Theme.of(context)
              .textTheme
              .displaySmall
              ?.copyWith(
            fontSize: 29,
            height: 1.15,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_outlined,
              size: 18,
              color: AppColors.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                place.address,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium,
              ),
            ),
          ],
        ),

        if (place.hasLocalDistance) ...[
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.near_me_outlined,
                size: 17,
                color: AppColors.muted,
              ),
              const SizedBox(width: 7),
              Text(
                place.distanceKm < 1
                    ? '현재 위치에서 ${(place.distanceKm * 1000).round()}m'
                    : '현재 위치에서 ${place.distanceKm.toStringAsFixed(1)}km',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CongestionBadge
    extends StatelessWidget {
  const _CongestionBadge({
    required this.congestion,
  });

  final int congestion;

  @override
  Widget build(BuildContext context) {
    final color = congestion <= 30
        ? const Color(0xFF48A77C)
        : congestion <= 60
        ? const Color(0xFFE5A52D)
        : const Color(0xFFD85B4F);

    final label = congestion <= 30
        ? '여유'
        : congestion <= 60
        ? '보통'
        : '혼잡';

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.94),
        borderRadius:
        BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '혼잡도 $congestion% · $label',
            style: const TextStyle(
              color: AppColors.forest,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions
    extends StatelessWidget {
  const _QuickActions({
    required this.isSaved,
    required this.onDirections,
    required this.onSave,
    required this.onCopyAddress,
  });

  final bool isSaved;
  final VoidCallback onDirections;
  final VoidCallback onSave;
  final VoidCallback onCopyAddress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon:
            Icons.navigation_outlined,
            label: '길찾기',
            emphasized: true,
            onTap: onDirections,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ActionButton(
            icon: isSaved
                ? Icons.bookmark
                : Icons.bookmark_border,
            label:
            isSaved ? '저장됨' : '저장',
            onTap: onSave,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ActionButton(
            icon: Icons.copy_outlined,
            label: '주소 복사',
            onTap: onCopyAddress,
          ),
        ),
      ],
    );
  }
}

class _ActionButton
    extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: emphasized
          ? AppColors.forest
          : const Color(0xFFF0F4F1),
      borderRadius:
      BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(16),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 8,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 21,
                color: emphasized
                    ? Colors.white
                    : AppColors.forest,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: emphasized
                      ? Colors.white
                      : AppColors.forest,
                  fontSize: 11,
                  fontWeight:
                  FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryGrid
    extends StatelessWidget {
  const _SummaryGrid({
    required this.place,
    required this.congestion,
  });

  final Place place;
  final int congestion;

  @override
  Widget build(BuildContext context) {
    final congestionLabel =
    congestion <= 30
        ? '여유로워요'
        : congestion <= 60
        ? '보통이에요'
        : '붐비는 편';

    final fourthTile =
    (
        place.category == '맛집' ||
            place.category == '카페' ||
            place.contentTypeId == '39'
    )
        ? _SummaryTile(
      icon: Icons.restaurant_menu,
      title: '대표 메뉴',
      value: place.representativeMenu.trim().isNotEmpty
          ? place.representativeMenu.trim()
          : place.menuItems.isNotEmpty
          ? place.menuItems.first.name
          : '메뉴 확인',
      detail:
      place.menuItems.isNotEmpty &&
          place.menuItems.first.price.trim().isNotEmpty
          ? place.menuItems.first.price
          : '가격 정보 확인 필요',
    )
        : _SummaryTile(
      icon: place.isPaid
          ? Icons.confirmation_number_outlined
          : Icons.check_circle_outline,
      title: '입장',
      value: place.feeText.trim().isNotEmpty
          ? place.feeText.trim()
          : place.isPaid
          ? '유료'
          : '무료',
      detail: '상세 정보 기준',
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.bar_chart_rounded,
                  title: '혼잡도',
                  value: '$congestion%',
                  detail: congestionLabel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  icon: Icons.schedule_outlined,
                  title: '추천 시간',
                  value: place.recommendedTime,
                  detail: '방문 추천',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SummaryTile(
                  icon: Icons.timer_outlined,
                  title: '추천 체류',
                  value: '약 ${place.stayMinutes}분',
                  detail: '예상 관람 시간',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: fourthTile,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryTile
    extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 19,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.muted,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.forest,
                    fontWeight:
                    FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    color: AppColors.muted,
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

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.place,
  });

  final Place place;

  @override
  Widget build(BuildContext context) {
    final items = place.menuItems.isNotEmpty
        ? place.menuItems.take(6).toList()
        : [
      MenuItem(
        name: place.representativeMenu,
        price: '',
        source: 'tour_api',
        representative: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: '대표 메뉴',
          icon: Icons.restaurant_menu,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: softCardDecoration(),
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              for (var i = 0;
              i < items.length;
              i++) ...[
                Row(
                  children: [
                    if (items[i].representative)
                      Container(
                        margin: const EdgeInsets.only(
                          right: 8,
                        ),
                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFFF4DF,
                          ),
                          borderRadius:
                          BorderRadius.circular(
                            999,
                          ),
                        ),
                        child: const Text(
                          '대표',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 9.5,
                            fontWeight:
                            FontWeight.w900,
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        items[i].name,
                        style: const TextStyle(
                          fontWeight:
                          FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      items[i].price.trim().isEmpty
                          ? '가격 정보 없음'
                          : items[i].price,
                      style: TextStyle(
                        color: items[i]
                            .price
                            .trim()
                            .isEmpty
                            ? AppColors.muted
                            : AppColors.forest,
                        fontSize: 11,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (i != items.length - 1)
                  const Divider(
                    height: 22,
                    color: AppColors.line,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}


class _PracticalInfoCard
    extends StatelessWidget {
  const _PracticalInfoCard({
    required this.place,
    required this.isLoading,
    required this.onOpenDaumSearch,
    required this.onOpenNaverBlog,
    required this.onOpenYoutube,
    required this.onOpenKakao,
    required this.onOpenContent,
    this.onOpenHomepage,
  });

  final Place place;
  final bool isLoading;
  final VoidCallback onOpenDaumSearch;
  final VoidCallback onOpenNaverBlog;
  final VoidCallback onOpenYoutube;
  final VoidCallback onOpenKakao;
  final ValueChanged<ContentLink> onOpenContent;
  final VoidCallback? onOpenHomepage;

  @override
  Widget build(BuildContext context) {
    final isFood = (
        place.category == '맛집' ||
            place.category == '카페' ||
            place.contentTypeId == '39'
    );

    String valueOrStatus(
        String value, {
          bool parking = false,
        }) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }

      if (isLoading) {
        return '확인 중...';
      }

      return parking
          ? '확인 필요'
          : '정보 없음';
    }

    final items = <_PracticalItem>[
      _PracticalItem(
        icon: Icons.access_time_outlined,
        label: isFood ? '영업시간' : '운영시간',
        value: valueOrStatus(
          place.operatingHours,
        ),
      ),
      if (isFood)
        _PracticalItem(
          icon: Icons.free_breakfast_outlined,
          label: '브레이크',
          value: valueOrStatus(
            place.breakTime,
          ),
        ),
      _PracticalItem(
        icon: Icons.event_busy_outlined,
        label: '휴무일',
        value: valueOrStatus(
          place.restDate,
        ),
      ),
      if (!isFood)
        _PracticalItem(
          icon: Icons.payments_outlined,
          label: '입장료',
          value: valueOrStatus(
            place.feeText,
          ),
        ),
      _PracticalItem(
        icon: Icons.local_parking_outlined,
        label: '주차',
        value: valueOrStatus(
          place.parking,
          parking: true,
        ),
      ),
      _PracticalItem(
        icon: Icons.phone_outlined,
        label: '전화',
        value: valueOrStatus(
          place.phone,
        ),
      ),
    ];

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: '방문 전 확인',
          icon:
          Icons.fact_check_outlined,
        ),
        const SizedBox(height: 12),

        Container(
          decoration:
          softCardDecoration(),
          padding:
          const EdgeInsets.all(16),
          child: Column(
            children: [
              for (var i = 0;
              i < items.length;
              i++) ...[
                _PracticalInfoRow(
                  item: items[i],
                ),
                if (i !=
                    items.length - 1)
                  const Divider(
                    height: 22,
                    color: AppColors.line,
                  ),
              ],

              const Divider(
                height: 28,
                color: AppColors.line,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '더 알아보기',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '장소명을 기준으로 외부 검색과 관련 자료를 바로 열 수 있어요.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ExternalResearchButton(
                    icon: Icons.search,
                    label: '다음 검색',
                    onPressed: onOpenDaumSearch,
                  ),
                  _ExternalResearchButton(
                    icon: Icons.map_outlined,
                    label: '카카오맵',
                    onPressed: onOpenKakao,
                  ),
                  _ExternalResearchButton(
                    icon: Icons.article_outlined,
                    label: '네이버 블로그',
                    onPressed: onOpenNaverBlog,
                  ),
                  _ExternalResearchButton(
                    icon: Icons.play_circle_outline,
                    label: 'YouTube',
                    onPressed: onOpenYoutube,
                  ),
                  if (onOpenHomepage != null)
                    _ExternalResearchButton(
                      icon: Icons.language,
                      label: '공식 홈페이지',
                      onPressed: onOpenHomepage!,
                    ),
                ],
              ),
              if (place.contentLinks
                  .where((link) => link.url.trim().isNotEmpty)
                  .isNotEmpty) ...[
                const Divider(
                  height: 28,
                  color: AppColors.line,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '검색 결과',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                for (final link in place.contentLinks
                    .where((link) => link.url.trim().isNotEmpty)
                    .take(3))
                  _CompactResearchResult(
                    link: link,
                    onTap: () => onOpenContent(link),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExternalResearchButton
    extends StatelessWidget {
  const _ExternalResearchButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
    );
  }
}

class _CompactResearchResult
    extends StatelessWidget {
  const _CompactResearchResult({
    required this.link,
    required this.onTap,
  });

  final ContentLink link;
  final VoidCallback onTap;

  String get _sourceLabel {
    final type = link.type.toLowerCase();
    final url = link.url.toLowerCase();

    if (type.contains('youtube') ||
        type.contains('video') ||
        url.contains('youtube.com') ||
        url.contains('youtu.be')) {
      return 'YouTube';
    }

    if (type.contains('blog') ||
        url.contains('blog.naver.com')) {
      return '네이버 블로그';
    }

    if (type.contains('official') ||
        type.contains('website') ||
        type == 'web') {
      return '웹사이트';
    }

    return '검색 결과';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.open_in_new,
              size: 17,
              color: AppColors.forest,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sourceLabel,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.title.trim().isEmpty
                        ? '관련 자료 열기'
                        : link.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 19,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticalItem {
  const _PracticalItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _PracticalInfoRow
    extends StatelessWidget {
  const _PracticalInfoRow({
    required this.item,
  });

  final _PracticalItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
            const Color(0xFFF0F4F1),
            borderRadius:
            BorderRadius.circular(11),
          ),
          child: Icon(
            item.icon,
            size: 18,
            color: AppColors.forest,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 66,
          child: Padding(
            padding:
            const EdgeInsets.only(
              top: 7,
            ),
            child: Text(
              item.label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight:
                FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding:
            const EdgeInsets.only(
              top: 6,
            ),
            child: Text(
              item.value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                height: 1.45,
                fontWeight:
                FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _ContentFilter {
  all,
  blog,
  video,
  web,
}

class _ContentFilterRow
    extends StatelessWidget {
  const _ContentFilterRow({
    required this.selected,
    required this.onChanged,
  });

  final _ContentFilter selected;
  final ValueChanged<_ContentFilter>
  onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ContentFilterChip(
          label: '전체',
          selected: selected == _ContentFilter.all,
          onTap: () => onChanged(_ContentFilter.all),
        ),
        _ContentFilterChip(
          label: '블로그',
          selected: selected == _ContentFilter.blog,
          onTap: () => onChanged(_ContentFilter.blog),
        ),
        _ContentFilterChip(
          label: '영상',
          selected: selected == _ContentFilter.video,
          onTap: () => onChanged(_ContentFilter.video),
        ),
        _ContentFilterChip(
          label: '웹사이트',
          selected: selected == _ContentFilter.web,
          onTap: () => onChanged(_ContentFilter.web),
        ),
      ],
    );
  }
}

class _ContentFilterChip
    extends StatelessWidget {
  const _ContentFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.forest
          : Colors.white,
      borderRadius:
      BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(999),
        child: Container(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 9,
          ),
          decoration: BoxDecoration(
            borderRadius:
            BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.forest
                  : AppColors.line,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.forest,
              fontSize: 11,
              fontWeight:
              FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentList
    extends StatelessWidget {
  const _ContentList({
    required this.links,
    required this.showAll,
    required this.onOpen,
  });

  final List<ContentLink> links;
  final bool showAll;
  final ValueChanged<ContentLink> onOpen;

  @override
  Widget build(BuildContext context) {
    final visible = showAll
        ? links
        : links.take(3).toList();

    if (links.isEmpty) {
      return Container(
        padding:
        const EdgeInsets.all(16),
        decoration:
        softCardDecoration(),
        child: const Text(
          '이 유형의 관련 콘텐츠가 아직 없어요.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      children: visible
          .map(
            (link) => Padding(
          padding:
          const EdgeInsets.only(
            bottom: 9,
          ),
          child: _ContentCard(
            link: link,
            onTap: () =>
                onOpen(link),
          ),
        ),
      )
          .toList(),
    );
  }
}

class _ContentCard
    extends StatelessWidget {
  const _ContentCard({
    required this.link,
    required this.onTap,
  });

  final ContentLink link;
  final VoidCallback onTap;

  bool get _isWebsite {
    final type = link.type.toLowerCase();
    return type.contains('official') || type.contains('website') || type == 'web';
  }

  bool get _isVideo {
    final type =
    link.type.toLowerCase();
    final url =
    link.url.toLowerCase();

    return type.contains('youtube') ||
        type.contains('video') ||
        url.contains('youtube.com') ||
        url.contains('youtu.be');
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius:
      BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius:
        BorderRadius.circular(17),
        child: Padding(
          padding:
          const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _isVideo
                      ? const Color(0xFFFFF0EC)
                      : const Color(0xFFF0F4F1),
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Icon(
                  _isVideo
                      ? Icons.play_circle_outline
                      : _isWebsite
                      ? Icons.language_outlined
                      : Icons.article_outlined,
                  color: _isVideo
                      ? const Color(
                    0xFFC95B4F,
                  )
                      : AppColors.forest,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  link.title,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.w800,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.open_in_new,
                size: 17,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityCrowdSummaryCard extends StatelessWidget {
  const _CommunityCrowdSummaryCard({
    required this.systemCongestion,
    required this.summary,
    required this.fallbackPlace,
  });

  final int systemCongestion;
  final Map<String, dynamic> summary;
  final Place fallbackPlace;

  @override
  Widget build(BuildContext context) {
    final reportCount =
        (summary['report_count'] as num?)?.toInt() ?? fallbackPlace.communityReportCount;
    final community =
        (summary['community_average_percent'] as num?)?.round() ??
            fallbackPlace.communityCongestionScore?.round();
    final latestRaw = summary['latest_observed_at'];
    final latest = latestRaw == null
        ? fallbackPlace.communityLatestObservedAt
        : DateTime.tryParse(latestRaw.toString());

    String timeLabel = '';
    if (latest != null) {
      final diff = DateTime.now().difference(latest.toLocal());
      if (diff.inMinutes < 1) {
        timeLabel = '방금 전';
      } else if (diff.inMinutes < 60) {
        timeLabel = '${diff.inMinutes}분 전';
      } else {
        timeLabel = '${diff.inHours}시간 전';
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_outlined, size: 18, color: AppColors.forest),
              SizedBox(width: 7),
              Text(
                '여행자 현장 제보',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            community == null
                ? '최근 현장 제보 $reportCount건이 있어요.'
                : '최근 제보 $reportCount건 · 현장 체감 혼잡도 약 $community%',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 5),
          Text(
            '앱 예상 혼잡도 $systemCongestion%와 현장 제보는 별도로 보여드려요.${timeLabel.isEmpty ? '' : ' · 최근 $timeLabel'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle
    extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 21,
          color: AppColors.forest,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),
      ],
    );
  }
}

class _BottomActionBar
    extends StatelessWidget {
  const _BottomActionBar({
    required this.onDirections,
  });

  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding:
        const EdgeInsets.fromLTRB(
          18,
          10,
          18,
          12,
        ),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(
            top: BorderSide(
              color: AppColors.line,
            ),
          ),
        ),
        child: SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: onDirections,
            icon: const Icon(
              Icons.navigation_outlined,
            ),
            label: const Text(
              '카카오맵으로 길찾기',
              style: TextStyle(
                fontWeight:
                FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
