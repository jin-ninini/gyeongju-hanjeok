import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/place.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'my_page_screen.dart';
import 'notification_screen.dart';
import 'place_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.onOpenMap,
    required this.onOpenCourse,
    super.key,
  });

  final VoidCallback onOpenMap;
  final VoidCallback onOpenCourse;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final TextEditingController _searchController;
  String _activeSearchQuery = '';
  Timer? _searchDebounce;

  static const _categories = <_HomeCategory>[
    _HomeCategory('전체', 'assets/images/gh_home_category_all.png'),
    _HomeCategory('문화유산', 'assets/images/gh_home_category_heritage.png'),
    _HomeCategory('전통마을', 'assets/images/gh_home_category_village.png'),
    _HomeCategory('자연', 'assets/images/gh_home_category_nature.png'),
    _HomeCategory('야경', 'assets/images/gh_home_category_night.png'),
    _HomeCategory('핫플레이스', 'assets/images/gh_home_category_hot.png'),
  ];

  static const _homeFeaturedContentTypes = <String>{
    '12',
    '14',
    '25',
    '28',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.of(context, listen: false).refreshNotifications();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      AppScope.of(context, listen: false).refreshNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openNotifications(AppController controller) async {
    await controller.refreshNotifications();
    if (!mounted) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotificationScreen()),
    );

    if (!mounted) return;
    await controller.refreshNotifications();
  }

  bool _isHomeFeaturedPlace(Place place) {
    final contentTypeId = place.contentTypeId.trim();

    if (contentTypeId.isNotEmpty) {
      return _homeFeaturedContentTypes.contains(contentTypeId);
    }

    const allowedCategories = <String>{
      '자연',
      '문화유산',
      '전통마을',
      '야경',
      '핫플레이스',
    };

    return allowedCategories.contains(place.tourismCategory) || place.isHotPlace;
  }

  void _scheduleSearch(AppController controller, String rawValue) {
    _searchDebounce?.cancel();
    final query = rawValue.trim();

    setState(() {
      _activeSearchQuery = query;
    });

    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
          () async {
        if (!mounted) return;
        await controller.loadPlaces(query: query, category: '전체');
      },
    );
  }

  Future<void> _submitSearch(
      AppController controller,
      String rawValue,
      ) async {
    _searchDebounce?.cancel();
    final query = rawValue.trim();

    setState(() {
      _activeSearchQuery = query;
    });

    await controller.loadPlaces(query: query, category: '전체');
  }

  Future<void> _clearSearch(AppController controller) async {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _activeSearchQuery = '';
    });

    await controller.loadPlaces(query: '', category: '전체');
  }

  Future<void> _selectCategory(
      AppController controller,
      String category,
      ) async {
    _searchDebounce?.cancel();
    _searchController.clear();

    setState(() {
      _activeSearchQuery = '';
    });

    await controller.loadPlaces(query: '', category: category);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final isSearching = _activeSearchQuery.isNotEmpty;
    final places = isSearching
        ? controller.places
        : controller.places.where(_isHomeFeaturedPlace).toList();

    return ColoredBox(
      color: AppColors.appBackground,
      child: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () async {
          await Future.wait([
            controller.loadPlaces(),
            controller.refreshNotifications(),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                searchController: _searchController,
                isSearching: isSearching,
                unreadCount: controller.unreadNotificationCount,
                onSearchChanged: (value) => _scheduleSearch(controller, value),
                onSearchSubmitted: (value) => _submitSearch(controller, value),
                onClearSearch: () => _clearSearch(controller),
                onOpenNotifications: () => _openNotifications(controller),
                onOpenMyPage: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const MyPageScreen()),
                ),
              ),
            ),
            if (!isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 10),
                  child: _CategoryStrip(
                    categories: _categories,
                    selectedCategory: controller.selectedCategory,
                    onSelected: (category) => _selectCategory(
                      controller,
                      category,
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                18,
                isSearching ? 10 : 4,
                18,
                112,
              ),
              sliver: SliverList.list(
                children: [
                  if (isSearching)
                    _SearchTitle(
                      query: _activeSearchQuery,
                      count: controller.isLoadingPlaces ? null : places.length,
                    )
                  else
                    _HomePlacesHeader(onOpenMap: widget.onOpenMap),
                  const SizedBox(height: 10),
                  _PlacesBody(
                    places: places,
                    isLoading: controller.isLoadingPlaces,
                    errorMessage: controller.globalError,
                    isSaved: controller.isSaved,
                    onSaved: controller.toggleSaved,
                    onOpenPlace: (place) => _openPlace(context, place),
                    onRetry: () {
                      if (isSearching) {
                        _submitSearch(controller, _activeSearchQuery);
                      } else {
                        controller.loadPlaces();
                      }
                    },
                    emptyTitle: isSearching
                        ? '"$_activeSearchQuery" 검색 결과가 없어요'
                        : '조건에 맞는 장소가 없어요',
                    emptyDescription: isSearching
                        ? '다른 장소 이름으로 다시 검색해보세요.'
                        : '주변 관광지를 다시 확인해보세요.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPlace(BuildContext context, Place place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlaceDetailScreen(place: place)),
    );
  }
}

class _HomeCategory {
  const _HomeCategory(this.label, this.assetPath);

  final String label;
  final String assetPath;
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.searchController,
    required this.isSearching,
    required this.unreadCount,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onOpenNotifications,
    required this.onOpenMyPage,
  });

  final TextEditingController searchController;
  final bool isSearching;
  final int unreadCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenMyPage;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 356 + topInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/gh_home_header.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned(
            left: 18,
            top: topInset + 16,
            child: const _HomeBrand(),
          ),
          Positioned(
            right: 16,
            top: topInset + 90,
            child: Row(
              children: [
                _HeaderActionButton(
                  tooltip: '알림',
                  icon: Icons.notifications_none_rounded,
                  badgeCount: unreadCount,
                  onPressed: onOpenNotifications,
                ),
                const SizedBox(width: 7),
                _HeaderActionButton(
                  tooltip: '내 정보',
                  icon: Icons.person_outline_rounded,
                  onPressed: onOpenMyPage,
                ),
              ],
            ),
          ),
          Positioned(
            left: 28,
            top: topInset + 92,
            child: const Text(
              '천년의 시간을,\n오늘의 여행으로',
              style: TextStyle(
                fontFamily: 'MaruBuri',
                color: Color(0xFF3B302A),
                fontSize: 25.5,
                fontWeight: FontWeight.w800,
                height: 1.12,
                letterSpacing: -0.7,
                shadows: [
                  Shadow(
                    color: Color(0x55FFF8EA),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 4,
            child: _HomeSearchField(
              controller: searchController,
              showClear: isSearching || searchController.text.isNotEmpty,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              onClear: onClearSearch,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBrand extends StatelessWidget {
  const _HomeBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.asset(
            'assets/images/gh_app_icon.png',
            width: 34,
            height: 34,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '경주한적',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: Color(0xFFF1E8D7),
            fontSize: 20.0,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            shadows: [
              Shadow(color: Color(0x66000000), blurRadius: 5),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.badgeCount = 0,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final label = badgeCount > 99 ? '99+' : '$badgeCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: tooltip,
          child: Material(
            color: const Color(0xDDF7EEDD),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  icon,
                  color: const Color(0xFF5B3A2A),
                  size: 23,
                ),
              ),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -2,
            top: -3,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFC54034),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.appBackground, width: 1.2),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeSearchField extends StatelessWidget {
  const _HomeSearchField({
    required this.controller,
    required this.showClear,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool showClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF8),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: const Color(0xFFD6B875),
            width: 1.15,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: '가고 싶은 장소를 검색해보세요',
            hintStyle: const TextStyle(
              color: Color(0xFF9F9688),
              fontSize: 15.0,
            ),
            prefixIcon: const SizedBox(
              width: 52,
              height: 58,
              child: Center(
                child: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF765844),
                  size: 23,
                ),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 52,
              maxWidth: 52,
              minHeight: 58,
              maxHeight: 58,
            ),
            suffixIcon: showClear
                ? IconButton(
              onPressed: onClear,
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFF8C8073),
                size: 19,
              ),
            )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minWidth: 46,
              minHeight: 46,
            ),
            isDense: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          textAlignVertical: TextAlignVertical.center,
        ),
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  final List<_HomeCategory> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const horizontalPadding = 17.0;
    const gap = 7.0;

    return SizedBox(
      height: 88,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 첫 화면에는 카테고리 5개가 정확히 보이고,
          // 6번째부터는 가로 스크롤해서 보이도록 폭을 계산한다.
          final itemWidth =
              (constraints.maxWidth - (horizontalPadding * 2) - (gap * 4)) / 5;

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: horizontalPadding),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: gap),
            itemBuilder: (context, index) {
              final item = categories[index];
              final selected = item.label == selectedCategory;

              return SizedBox(
                width: itemWidth,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onSelected(item.label),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 160),
                        scale: selected ? 1.06 : 1,
                        child: Container(
                          width: 53,
                          height: 53,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: selected
                                ? const [
                              BoxShadow(
                                color: Color(0x2E8D623C),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ]
                                : null,
                          ),
                          child: Image.asset(
                            item.assetPath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFFB72E27)
                              : const Color(0xFF746B61),
                          fontSize: 10.5,
                          fontWeight:
                          selected ? FontWeight.w900 : FontWeight.w700,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _HomePlacesHeader extends StatelessWidget {
  const _HomePlacesHeader({required this.onOpenMap});

  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            '지금 한적한 경주',
            style: TextStyle(
              fontFamily: 'MaruBuri',
              color: Color(0xFF4B3429),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onOpenMap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(
            Icons.map_outlined,
            size: 15,
            color: Color(0xFF765844),
          ),
          label: const Text(
            '지도에서 보기',
            style: TextStyle(
              color: Color(0xFF765844),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchTitle extends StatelessWidget {
  const _SearchTitle({required this.query, required this.count});

  final String query;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '"$query" 검색 결과',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'MaruBuri',
              color: Color(0xFF4B3429),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (count != null)
          Text(
            '$count곳',
            style: const TextStyle(
              color: Color(0xFF765844),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
      ],
    );
  }
}

class _PlacesBody extends StatelessWidget {
  const _PlacesBody({
    required this.places,
    required this.isLoading,
    required this.errorMessage,
    required this.isSaved,
    required this.onSaved,
    required this.onOpenPlace,
    required this.onRetry,
    required this.emptyTitle,
    required this.emptyDescription,
  });

  final List<Place> places;
  final bool isLoading;
  final String? errorMessage;
  final bool Function(String placeId) isSaved;
  final Future<void> Function(Place place) onSaved;
  final void Function(Place place) onOpenPlace;
  final VoidCallback onRetry;
  final String emptyTitle;
  final String emptyDescription;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.forest,
            strokeWidth: 2.4,
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return _ErrorCard(message: errorMessage!, onRetry: onRetry);
    }

    if (places.isEmpty) {
      return Container(
        height: 210,
        decoration: BoxDecoration(
          color: const Color(0xB3FFFDF8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x33A98252)),
        ),
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: emptyTitle,
          description: emptyDescription,
        ),
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = ((screenWidth - 48) / 2).clamp(158.0, 210.0).toDouble();

    return SizedBox(
      height: 218,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: places.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final place = places[index];
          return _HomePlaceCard(
            place: place,
            width: cardWidth,
            isSaved: isSaved(place.id),
            onTap: () => onOpenPlace(place),
            onSaved: () => onSaved(place),
          );
        },
      ),
    );
  }
}

class _HomePlaceCard extends StatelessWidget {
  const _HomePlaceCard({
    required this.place,
    required this.width,
    required this.isSaved,
    required this.onTap,
    required this.onSaved,
  });

  final Place place;
  final double width;
  final bool isSaved;
  final VoidCallback onTap;
  final VoidCallback onSaved;

  int get _congestion => (100 - place.quietScore).clamp(0, 100).toInt();

  String get _congestionAsset {
    final value = _congestion;
    if (value <= 20) return 'assets/images/gh_congestion_blue.png';
    if (value <= 40) return 'assets/images/gh_congestion_green.png';
    if (value <= 60) return 'assets/images/gh_congestion_yellow.png';
    if (value <= 80) return 'assets/images/gh_congestion_orange.png';
    return 'assets/images/gh_congestion_red.png';
  }

  Color get _congestionColor {
    final value = _congestion;
    if (value <= 20) return const Color(0xFF236AA8);
    if (value <= 40) return const Color(0xFF347A56);
    if (value <= 60) return const Color(0xFFB98B23);
    if (value <= 80) return const Color(0xFFD66A33);
    return const Color(0xFFC53B31);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFDF9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x229B774F)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 112,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        PlaceImage(place: place),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0x22000000)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 7,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(5, 3, 7, 3),
                            decoration: BoxDecoration(
                              color: const Color(0xF2FFFDF8),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(color: const Color(0x229B774F)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  _congestionAsset,
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '혼잡도 $_congestion%',
                                  style: TextStyle(
                                    color: _congestionColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Material(
                            color: const Color(0xE6FFFDF8),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onSaved,
                              child: SizedBox(
                                width: 29,
                                height: 29,
                                child: Icon(
                                  isSaved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: isSaved
                                      ? const Color(0xFFC73A31)
                                      : const Color(0xFF5E584F),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'MaruBuri',
                              color: Color(0xFF372B25),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.25,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Expanded(
                            child: Text(
                              place.description.trim().isEmpty
                                  ? '${place.tourismCategory}에서 여유롭게 둘러보세요.'
                                  : place.description.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF7E7469),
                                fontSize: 9.2,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                size: 12,
                                color: Color(0xFFC94438),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  place.hasLocalDistance
                                      ? '${place.tourismCategory} · ${place.distanceKm.toStringAsFixed(1)}km'
                                      : place.tourismCategory,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF6E655D),
                                    fontSize: 8.6,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5EF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x33D96B5F)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppColors.danger,
            size: 32,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('다시 불러오기'),
          ),
        ],
      ),
    );
  }
}
