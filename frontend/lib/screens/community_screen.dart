import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/community.dart';
import '../models/completed_trip.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    super.key,
    this.onOpenCourse,
  });

  final VoidCallback? onOpenCourse;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  CommunityPostType? _selectedType;
  String _sort = 'latest';
  bool _requestedInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requestedInitialLoad) return;
    _requestedInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.of(context, listen: false).loadCommunityPosts();
    });
  }

  Future<void> _changeFilter(CommunityPostType? type) async {
    setState(() => _selectedType = type);
    await AppScope.of(context, listen: false).loadCommunityPosts(
      postType: type,
      sort: _sort,
    );
  }

  Future<void> _changeSort(String value) async {
    setState(() => _sort = value);
    await AppScope.of(context, listen: false).loadCommunityPosts(
      postType: _selectedType,
      sort: value,
    );
  }

  Future<void> _openWritePicker() async {
    final controller = AppScope.of(context, listen: false);
    final type = await showModalBottomSheet<CommunityPostType>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '어떤 글을 작성할까요?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              _WriteTypeTile(
                icon: Icons.route_outlined,
                title: '코스 후기',
                subtitle: '완료한 코스를 평가하고 다른 여행자와 공유해요.',
                onTap: () => Navigator.pop(sheetContext, CommunityPostType.course),
              ),
              _WriteTypeTile(
                icon: Icons.location_on_outlined,
                title: '지금 여기',
                subtitle: '현재 관광지가 한적한지 붐비는지 알려줘요.',
                onTap: () => Navigator.pop(sheetContext, CommunityPostType.live),
              ),
              _WriteTypeTile(
                icon: Icons.edit_note_outlined,
                title: '여행 후기',
                subtitle: '장소와 여행 경험을 자유롭게 기록해요.',
                onTap: () => Navigator.pop(sheetContext, CommunityPostType.travel),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || type == null) return;

    CompletedTrip? trip;
    if (type == CommunityPostType.course) {
      if (controller.completedTrips.isEmpty) {
        showAppSnackBar(context, '완료한 코스가 있어야 코스 후기를 작성할 수 있어요.');
        return;
      }
      trip = await _pickCompletedTrip(controller.completedTrips);
      if (trip == null || !mounted) return;
    }

    await _openComposer(type: type, courseTrip: trip);
  }

  Future<CompletedTrip?> _pickCompletedTrip(List<CompletedTrip> trips) async {
    return showModalBottomSheet<CompletedTrip>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            Text('평가할 완료 코스', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...trips.map(
                  (trip) => ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(trip.route.title),
                subtitle: Text('${trip.route.stops.length}곳 · ${_dateLabel(trip.completedAt)}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(sheetContext, trip),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openComposer({
    required CommunityPostType type,
    CompletedTrip? courseTrip,
  }) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => CommunityWriteScreen(
          initialType: type,
          courseTrip: courseTrip,
        ),
      ),
    );
    if (created == true && mounted) {
      await AppScope.of(context, listen: false).loadCommunityPosts(
        postType: _selectedType,
        sort: _sort,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final pendingTrip = controller.pendingCommunityCourseReview;
    final liveNow = controller.communityPosts
        .where((post) => post.postType == CommunityPostType.live && post.liveIsRecent)
        .take(3)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 64,
        titleSpacing: 18,
        title: const Text(
          '커뮤니티',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.0,
            color: AppColors.forest,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => controller.loadCommunityPosts(
          postType: _selectedType,
          sort: _sort,
        ),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 120),
          children: [
            if (pendingTrip != null) ...[
              _PendingCourseReviewCard(
                trip: pendingTrip,
                onWrite: () => _openComposer(
                  type: CommunityPostType.course,
                  courseTrip: pendingTrip,
                ),
                onDismiss: controller.clearPendingCommunityCourseReview,
              ),
              const SizedBox(height: 12),
            ],
            _CommunityCategoryRow(
              selected: _selectedType,
              onChanged: _changeFilter,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.swap_vert, size: 18, color: AppColors.muted),
                const SizedBox(width: 6),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _sort,
                    items: const [
                      DropdownMenuItem(value: 'latest', child: Text('최신순')),
                      DropdownMenuItem(value: 'recommended', child: Text('추천순')),
                    ],
                    onChanged: (value) {
                      if (value != null) _changeSort(value);
                    },
                  ),
                ),
              ],
            ),
            if (_selectedType == null && liveNow.isNotEmpty) ...[
              const SizedBox(height: 8),
              const SectionHeader(
                title: '지금 경주는?',
                subtitle: '최근 여행자가 남긴 현장 혼잡 제보예요.',
              ),
              const SizedBox(height: 10),
              ...liveNow.map(
                    (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LiveNowTile(
                    post: post,
                    onTap: () => _openPost(post),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (controller.isLoadingCommunity)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.communityError != null && controller.communityPosts.isEmpty)
              _CommunityEmptyState(
                icon: Icons.cloud_off_outlined,
                title: '커뮤니티를 불러오지 못했어요',
                description: controller.communityError!,
                actionLabel: '다시 불러오기',
                onAction: () => controller.loadCommunityPosts(
                  postType: _selectedType,
                  sort: _sort,
                ),
              )
            else if (controller.communityPosts.isEmpty)
                _CommunityEmptyState(
                  icon: Icons.forum_outlined,
                  title: '아직 등록된 글이 없어요',
                  description: '첫 여행 기록이나 현장 정보를 남겨보세요.',
                  actionLabel: '글쓰기',
                  onAction: _openWritePicker,
                )
              else
                ...controller.communityPosts.map(
                      (post) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CommunityPostCard(
                      post: post,
                      onOpen: () => _openPost(post),
                      onRecommend: () => controller.toggleCommunityRecommendation(post),
                      onComment: () => _openPost(post, focusComment: true),
                      onMore: controller.userId != post.author.userId
                          ? () => _showPostSafetyMenu(context, post)
                          : null,
                      onSaveCourse: post.postType == CommunityPostType.course
                          ? () => controller.toggleCommunityCourseSaved(post)
                          : null,
                      onFollowCourse: post.postType == CommunityPostType.course
                          ? () => _followCourse(post)
                          : null,
                    ),
                  ),
                ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openWritePicker,
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Future<void> _openPost(CommunityPost post, {bool focusComment = false}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailScreen(
          initialPost: post,
          autofocusComment: focusComment,
          onOpenCourse: widget.onOpenCourse,
        ),
      ),
    );
  }

  Future<void> _followCourse(CommunityPost post) async {
    final controller = AppScope.of(context, listen: false);
    final ok = await controller.followCommunityCourse(post);
    if (!mounted) return;
    if (!ok) {
      showAppSnackBar(context, controller.communityError ?? '코스를 불러오지 못했어요.');
      return;
    }
    showAppSnackBar(context, '코스 탭에 이 여행자의 코스를 불러왔어요.');
    widget.onOpenCourse?.call();
  }
}

class _CommunityCategoryRow extends StatelessWidget {
  const _CommunityCategoryRow({
    required this.selected,
    required this.onChanged,
  });

  final CommunityPostType? selected;
  final ValueChanged<CommunityPostType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <(CommunityPostType?, String, IconData)>[
      (null, '전체', Icons.grid_view_outlined),
      (CommunityPostType.course, '코스 후기', Icons.route_outlined),
      (CommunityPostType.live, '지금 여기', Icons.location_on_outlined),
      (CommunityPostType.travel, '여행 후기', Icons.edit_note_outlined),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final active = selected == item.$1;
          return ChoiceChip(
            selected: active,
            onSelected: (_) => onChanged(item.$1),
            avatar: Icon(item.$3, size: 16),
            label: Text(item.$2),
          );
        },
      ),
    );
  }
}

class _PendingCourseReviewCard extends StatelessWidget {
  const _PendingCourseReviewCard({
    required this.trip,
    required this.onWrite,
    required this.onDismiss,
  });

  final CompletedTrip trip;
  final VoidCallback onWrite;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text('완료한 코스를 평가해보세요', style: Theme.of(context).textTheme.titleMedium),
              ),
              IconButton(onPressed: onDismiss, icon: const Icon(Icons.close)),
            ],
          ),
          Text(trip.route.title),
          const SizedBox(height: 4),
          Text('${trip.route.stops.length}곳 · ${_dateLabel(trip.completedAt)}'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('코스 후기 작성'),
          ),
        ],
      ),
    );
  }
}

class _LiveNowTile extends StatelessWidget {
  const _LiveNowTile({required this.post, required this.onTap});

  final CommunityPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      leading: const Icon(Icons.location_on_outlined),
      title: Text(post.placeTitle ?? '관광지'),
      subtitle: Text('${post.crowdPercent ?? 0}% · ${post.crowdBucket?.label ?? '현장 제보'} · ${_relativeTime(post.observedAt ?? post.createdAt)}'),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  const _CommunityPostCard({
    required this.post,
    required this.onOpen,
    required this.onRecommend,
    required this.onComment,
    this.onMore,
    this.onSaveCourse,
    this.onFollowCourse,
  });

  final CommunityPost post;
  final VoidCallback onOpen;
  final VoidCallback onRecommend;
  final VoidCallback onComment;
  final VoidCallback? onMore;
  final VoidCallback? onSaveCourse;
  final VoidCallback? onFollowCourse;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: softCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(post.author.nickname.isEmpty ? '여' : post.author.nickname.characters.first),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.author.nickname, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(_relativeTime(post.createdAt), style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                _TypeBadge(type: post.postType),
                if (onMore != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '게시물 메뉴',
                    onPressed: onMore,
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            if (post.title.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(post.title, style: Theme.of(context).textTheme.titleMedium),
              ),
            if (post.postType == CommunityPostType.live)
              _LiveInfoRow(post: post),
            if (post.postType == CommunityPostType.course)
              _CourseSummary(post: post),
            const SizedBox(height: 8),
            Text(post.content, maxLines: 4, overflow: TextOverflow.ellipsis),
            if (post.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: post.tags.map((tag) => Text('#$tag')).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                _PostActionButton(
                  icon: post.recommendedByMe ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                  label: '추천 ${post.recommendationCount}',
                  onTap: onRecommend,
                ),
                const SizedBox(width: 8),
                _PostActionButton(
                  icon: Icons.chat_bubble_outline,
                  label: '댓글 ${post.commentCount}',
                  onTap: onComment,
                ),
              ],
            ),
            if (post.postType == CommunityPostType.course) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSaveCourse,
                      icon: Icon(post.courseSavedByMe ? Icons.bookmark : Icons.bookmark_outline),
                      label: Text(post.courseSavedByMe ? '저장됨' : '코스 저장'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onFollowCourse,
                      icon: const Icon(Icons.directions_walk_outlined),
                      label: const Text('이 코스 따라가기'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final CommunityPostType type;

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      CommunityPostType.course => Icons.route_outlined,
      CommunityPostType.live => Icons.location_on_outlined,
      CommunityPostType.travel => Icons.edit_note_outlined,
    };
    return Chip(
      avatar: Icon(icon, size: 15),
      label: Text(type.label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _LiveInfoRow extends StatelessWidget {
  const _LiveInfoRow({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined),
          const SizedBox(width: 8),
          Expanded(child: Text(post.placeTitle ?? '관광지')),
          Text('${post.crowdPercent ?? 0}% · ${post.crowdBucket?.label ?? ''}'),
        ],
      ),
    );
  }
}

class _CourseSummary extends StatelessWidget {
  const _CourseSummary({required this.post});
  final CommunityPost post;

  @override
  Widget build(BuildContext context) {
    RoutePlan? route;
    try {
      if (post.courseSnapshot != null) route = RoutePlan.fromJson(post.courseSnapshot!);
    } catch (_) {}

    final names = route?.stops.map((stop) => stop.place.name).toList() ?? const <String>[];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_outline, size: 18),
              const SizedBox(width: 6),
              Text('평점 ${post.courseRating?.toStringAsFixed(1) ?? '-'} / 5'),
              if (post.travelDate != null) ...[
                const SizedBox(width: 12),
                Text(post.travelDate!),
              ],
            ],
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(names.join(' → '), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }
}

class _PostActionButton extends StatelessWidget {
  const _PostActionButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(onPressed: onTap, icon: Icon(icon, size: 18), label: Text(label));
  }
}

class _CommunityEmptyState extends StatelessWidget {
  const _CommunityEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(description, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _WriteTypeTile extends StatelessWidget {
  const _WriteTypeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class CommunityWriteScreen extends StatefulWidget {
  const CommunityWriteScreen({
    super.key,
    required this.initialType,
    this.courseTrip,
    this.initialPlace,
  });

  final CommunityPostType initialType;
  final CompletedTrip? courseTrip;
  final Place? initialPlace;

  @override
  State<CommunityWriteScreen> createState() => _CommunityWriteScreenState();
}

class _CommunityWriteScreenState extends State<CommunityWriteScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();
  double _rating = 4;
  int _crowdPercent = 30;
  String? _selectedPlaceId;
  final Set<String> _relatedPlaceIds = <String>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedPlaceId = widget.initialPlace?.id;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final type = widget.initialType;
    final placeOptions = [...controller.places];
    final initialPlace = widget.initialPlace;
    if (initialPlace != null && !placeOptions.any((place) => place.id == initialPlace.id)) {
      placeOptions.insert(0, initialPlace);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${type.label} 작성'),
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: const Text('등록'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
        children: [
          if (type == CommunityPostType.course && widget.courseTrip != null)
            _SelectedCourseBlock(trip: widget.courseTrip!),
          if (type == CommunityPostType.live) ...[
            const _FormLabel(icon: Icons.place_outlined, label: '현재 관광지'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedPlaceId,
              hint: const Text('관광지를 선택하세요'),
              items: placeOptions
                  .map((place) => DropdownMenuItem(value: place.id, child: Text(place.name)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedPlaceId = value),
            ),
            const SizedBox(height: 20),
            const _FormLabel(icon: Icons.groups_outlined, label: '현장 혼잡도'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                (10, '0~20%'),
                (30, '20~40%'),
                (50, '40~60%'),
                (70, '60~80%'),
                (90, '80~100%'),
              ].map((item) {
                return ChoiceChip(
                  label: Text(item.$2),
                  selected: _crowdPercent == item.$1,
                  onSelected: (_) => setState(() => _crowdPercent = item.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
          if (type == CommunityPostType.course) ...[
            const _FormLabel(icon: Icons.star_outline, label: '코스 만족도'),
            Slider(
              value: _rating,
              min: 1,
              max: 5,
              divisions: 8,
              label: _rating.toStringAsFixed(1),
              onChanged: (value) => setState(() => _rating = value),
            ),
            Center(child: Text('${_rating.toStringAsFixed(1)} / 5.0')),
            const SizedBox(height: 20),
          ],
          if (type != CommunityPostType.live) ...[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '제목',
                prefixIcon: Icon(Icons.title),
              ),
              maxLength: 160,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _contentController,
            minLines: 6,
            maxLines: 12,
            maxLength: 6000,
            decoration: const InputDecoration(
              labelText: '내용',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 100),
                child: Icon(Icons.notes_outlined),
              ),
            ),
          ),
          if (type == CommunityPostType.travel) ...[
            const SizedBox(height: 12),
            const _FormLabel(icon: Icons.place_outlined, label: '관련 장소 (선택)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: placeOptions.take(12).map((place) {
                return FilterChip(
                  label: Text(place.name),
                  selected: _relatedPlaceIds.contains(place.id),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _relatedPlaceIds.add(place.id);
                      } else {
                        _relatedPlaceIds.remove(place.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '태그',
                hintText: '야경, 산책, 가족여행',
                prefixIcon: Icon(Icons.tag),
              ),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('사진 첨부'),
          ),
          const SizedBox(height: 6),
          Text(
            '여행 사진을 추가해보세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_submitting) ...[
            const SizedBox(height: 20),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final controller = AppScope.of(context, listen: false);
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      showAppSnackBar(context, '내용을 입력해주세요.');
      return;
    }

    final type = widget.initialType;
    if (type == CommunityPostType.live && (_selectedPlaceId == null || _selectedPlaceId!.isEmpty)) {
      showAppSnackBar(context, '현재 관광지를 선택해주세요.');
      return;
    }
    if (type == CommunityPostType.course && widget.courseTrip == null) {
      showAppSnackBar(context, '평가할 완료 코스를 선택해주세요.');
      return;
    }

    setState(() => _submitting = true);
    final payload = <String, dynamic>{
      'post_type': type.value,
      'title': _titleController.text.trim(),
      'content': content,
      'image_urls': const <String>[],
    };

    if (type == CommunityPostType.course) {
      final trip = widget.courseTrip!;
      payload.addAll({
        'course_snapshot': trip.route.toJson(),
        'course_rating': _rating,
        'travel_date': _yyyyMmDd(trip.completedAt),
      });
    } else if (type == CommunityPostType.live) {
      payload.addAll({
        'place_id': _selectedPlaceId,
        'crowd_percent': _crowdPercent,
      });
    } else {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim().replaceFirst(RegExp(r'^#'), ''))
          .where((tag) => tag.isNotEmpty)
          .toList();
      payload.addAll({
        'related_place_ids': _relatedPlaceIds.toList(),
        'tags': tags,
      });
    }

    final created = await controller.createCommunityPost(payload);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created == null) {
      showAppSnackBar(context, controller.communityError ?? '글을 등록하지 못했어요.');
      return;
    }
    Navigator.pop(context, true);
  }
}

class _SelectedCourseBlock extends StatelessWidget {
  const _SelectedCourseBlock({required this.trip});
  final CompletedTrip trip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FormLabel(icon: Icons.route_outlined, label: '평가할 코스'),
          const SizedBox(height: 8),
          Text(trip.route.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(trip.route.stops.map((stop) => stop.place.name).join(' → ')),
          const SizedBox(height: 6),
          Text('${trip.route.stops.length}곳 · ${_dateLabel(trip.completedAt)}'),
        ],
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class CommunityPostDetailScreen extends StatefulWidget {
  const CommunityPostDetailScreen({
    super.key,
    required this.initialPost,
    this.autofocusComment = false,
    this.onOpenCourse,
  });

  final CommunityPost initialPost;
  final bool autofocusComment;
  final VoidCallback? onOpenCourse;

  @override
  State<CommunityPostDetailScreen> createState() => _CommunityPostDetailScreenState();
}

class _CommunityPostDetailScreenState extends State<CommunityPostDetailScreen> {
  late CommunityPost _post;
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();
  List<CommunityComment> _comments = const [];
  bool _loadingComments = true;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadComments();
      if (widget.autofocusComment && mounted) _commentFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final items = await AppScope.of(context, listen: false).loadCommunityComments(_post.postId);
    if (!mounted) return;
    setState(() {
      _comments = items;
      _loadingComments = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final latest = controller.communityPosts.where((item) => item.postId == _post.postId);
    if (latest.isNotEmpty) _post = latest.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(_post.postType.label),
        actions: [
          if (controller.userId != _post.author.userId)
            IconButton(
              tooltip: '게시물 메뉴',
              onPressed: () => _showPostSafetyMenu(context, _post, closeDetailOnHide: true),
              icon: const Icon(Icons.more_vert),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(_post.author.nickname.isEmpty ? '여' : _post.author.nickname.characters.first)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_post.author.nickname, style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(_relativeTime(_post.createdAt)),
                  ],
                ),
              ),
              _TypeBadge(type: _post.postType),
            ],
          ),
          const SizedBox(height: 18),
          if (_post.title.isNotEmpty) Text(_post.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          if (_post.postType == CommunityPostType.live) _LiveInfoRow(post: _post),
          if (_post.postType == CommunityPostType.course) _CourseSummary(post: _post),
          const SizedBox(height: 12),
          Text(_post.content, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
          if (_post.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: _post.tags.map((tag) => Chip(label: Text('#$tag'))).toList()),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => controller.toggleCommunityRecommendation(_post),
                  icon: Icon(_post.recommendedByMe ? Icons.thumb_up : Icons.thumb_up_alt_outlined),
                  label: Text('추천 ${_post.recommendationCount}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _commentFocus.requestFocus(),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text('댓글 ${_post.commentCount}'),
                ),
              ),
            ],
          ),
          if (_post.postType == CommunityPostType.course) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => controller.toggleCommunityCourseSaved(_post),
                    icon: Icon(_post.courseSavedByMe ? Icons.bookmark : Icons.bookmark_outline),
                    label: Text(_post.courseSavedByMe ? '저장됨' : '코스 저장'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _follow,
                    icon: const Icon(Icons.directions_walk_outlined),
                    label: const Text('이 코스 따라가기'),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 36),
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline, size: 18),
              const SizedBox(width: 8),
              Text('댓글', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          if (_loadingComments)
            const Center(child: CircularProgressIndicator())
          else if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('첫 댓글을 남겨보세요.'),
            )
          else
            ..._comments.map(
                  (comment) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(child: Text(comment.author.nickname.isEmpty ? '여' : comment.author.nickname.characters.first)),
                title: Text(comment.author.nickname),
                subtitle: Text(comment.content),
                trailing: Text(_relativeTime(comment.createdAt), style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
        ],
      ),
      bottomSheet: SafeArea(
        top: false,
        child: Material(
          color: Colors.white,
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocus,
                    decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
                  ),
                ),
                IconButton(
                  onPressed: _sendingComment ? null : _sendComment,
                  icon: const Icon(Icons.send_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    final controller = AppScope.of(context, listen: false);
    final comment = await controller.addCommunityComment(post: _post, content: text);
    if (!mounted) return;
    setState(() => _sendingComment = false);
    if (comment == null) {
      showAppSnackBar(context, controller.communityError ?? '댓글을 등록하지 못했어요.');
      return;
    }
    _commentController.clear();
    setState(() {
      _comments = [..._comments, comment];
      _post = _post.copyWith(commentCount: _post.commentCount + 1);
    });
  }

  Future<void> _follow() async {
    final controller = AppScope.of(context, listen: false);
    final ok = await controller.followCommunityCourse(_post);
    if (!mounted) return;
    if (!ok) {
      showAppSnackBar(context, controller.communityError ?? '코스를 불러오지 못했어요.');
      return;
    }
    Navigator.pop(context);
    widget.onOpenCourse?.call();
  }
}

Future<void> _showPostSafetyMenu(
    BuildContext context,
    CommunityPost post, {
      bool closeDetailOnHide = false,
    }) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('신고하기'),
            subtitle: const Text('운영팀에 부적절한 게시물을 알려요.'),
            onTap: () => Navigator.pop(sheetContext, 'report'),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined),
            title: const Text('이 게시물 숨기기'),
            subtitle: const Text('나에게만 이 게시물이 보이지 않아요.'),
            onTap: () => Navigator.pop(sheetContext, 'hide'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return;

  final controller = AppScope.of(context, listen: false);
  if (action == 'hide') {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('게시물을 숨길까요?'),
        content: const Text('이 게시물은 내 커뮤니티 목록에서 보이지 않게 됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('숨기기')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final ok = await controller.hideCommunityPost(post);
    if (!context.mounted) return;
    if (ok) {
      showAppSnackBar(context, '게시물을 숨겼어요.');
      if (closeDetailOnHide && Navigator.of(context).canPop()) Navigator.of(context).pop();
    } else {
      showAppSnackBar(context, controller.communityError ?? '게시물을 숨기지 못했어요.');
    }
    return;
  }

  const reasons = <(String, String)>[
    ('spam', '스팸·홍보'),
    ('abuse', '욕설·괴롭힘'),
    ('inappropriate', '부적절한 콘텐츠'),
    ('false_information', '허위·오해 소지가 있는 정보'),
    ('privacy', '개인정보 노출'),
    ('other', '기타'),
  ];
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('신고 사유를 선택해주세요', style: TextStyle(fontWeight: FontWeight.w800))),
          ...reasons.map((item) => ListTile(
            title: Text(item.$2),
            onTap: () => Navigator.pop(sheetContext, item.$1),
          )),
        ],
      ),
    ),
  );
  if (reason == null || !context.mounted) return;
  final ok = await controller.reportCommunityPost(post, reason);
  if (!context.mounted) return;
  showAppSnackBar(
    context,
    ok ? '신고가 접수됐어요. 검토에 참고할게요.' : (controller.communityError ?? '신고를 접수하지 못했어요.'),
  );
}

String _dateLabel(DateTime value) {
  final local = value.toLocal();
  return "${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}";
}

String _yyyyMmDd(DateTime value) {
  final local = value.toLocal();
  return "${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}";
}

String _relativeTime(DateTime value) {
  final diff = DateTime.now().difference(value.toLocal());
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  if (diff.inDays < 7) return '${diff.inDays}일 전';
  return _dateLabel(value);
}
