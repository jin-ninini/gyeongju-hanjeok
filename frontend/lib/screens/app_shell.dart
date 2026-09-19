import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'chatbot_screen.dart';
import 'community_screen.dart';
import 'course_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            onOpenMap: () => setState(() => _index = 1),
            onOpenCourse: () => setState(() => _index = 2),
          ),
          if (_index == 1) const MapScreen() else const SizedBox.shrink(),
          CourseScreen(
            onOpenCommunityReview: (trip) {
              AppScope.of(context, listen: false)
                  .prepareCommunityCourseReview(trip);
              setState(() => _index = 3);
            },
          ),
          CommunityScreen(
            onOpenCourse: () => setState(() => _index = 2),
          ),
          const ChatbotScreen(),
        ],
      ),
      bottomNavigationBar: _GyeongjuBottomNavigation(
        selectedIndex: _index,
        onSelected: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _GyeongjuBottomNavigation extends StatelessWidget {
  const _GyeongjuBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = <_BottomNavItem>[
    _BottomNavItem(
      label: '홈',
      selectedAsset: 'assets/images/gh_nav_home_selected.png',
      unselectedAsset: 'assets/images/gh_nav_home_unselected.png',
    ),
    _BottomNavItem(
      label: '지도',
      selectedAsset: 'assets/images/gh_nav_map_selected.png',
      unselectedAsset: 'assets/images/gh_nav_map_unselected.png',
    ),
    _BottomNavItem(
      label: '코스',
      selectedAsset: 'assets/images/gh_nav_course_selected.png',
      unselectedAsset: 'assets/images/gh_nav_course_unselected.png',
    ),
    _BottomNavItem(
      label: '커뮤니티',
      selectedAsset: 'assets/images/gh_nav_community_selected.png',
      unselectedAsset: 'assets/images/gh_nav_community_unselected.png',
    ),
    _BottomNavItem(
      label: '챗봇',
      selectedAsset: 'assets/images/gh_nav_chatbot_selected.png',
      unselectedAsset: 'assets/images/gh_nav_chatbot_unselected.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Container(
        height: 78,
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x26966F48)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x20000000),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = index == selectedIndex;

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: selected ? 1.08 : 1,
                        child: Image.asset(
                          selected
                              ? item.selectedAsset
                              : item.unselectedAsset,
                          width: 41,
                          height: 41,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF6F3F25)
                              : const Color(0xFF8E8176),
                          fontSize: 10.0,
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem({
    required this.label,
    required this.selectedAsset,
    required this.unselectedAsset,
  });

  final String label;
  final String selectedAsset;
  final String unselectedAsset;
}

class AppLoadingScreen extends StatelessWidget {
  const AppLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1E8D7),
      body: SafeArea(
        child: Center(
          child: Transform.translate(
            offset: Offset(0, -18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.all(
                        Radius.circular(16),
                      ),
                      child: Image(
                        image: AssetImage(
                          'assets/images/gh_app_icon.png',
                        ),
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: 14),
                    Text(
                      '경주한적',
                      style: TextStyle(
                        fontFamily: 'MaruBuri',
                        color: Color(0xFF34384D),
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 34),
                SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    color: Color(0xFF315E4F),
                    strokeWidth: 2.8,
                  ),
                ),
                SizedBox(height: 18),
                Text(
                  '한적한 경주 여행을 준비하고 있어요',
                  style: TextStyle(
                    color: Color(0xFF8E8176),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
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

class AppFatalErrorScreen extends StatelessWidget {
  const AppFatalErrorScreen({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: Icons.cloud_off_outlined,
        title: '앱을 시작하지 못했어요',
        description: message,
        actionLabel: '다시 시도',
        onAction: onRetry,
      ),
    );
  }
}
