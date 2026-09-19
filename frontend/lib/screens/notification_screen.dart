import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_notification.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'community_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  _NotificationFilter _filter = _NotificationFilter.all;
  final Set<String> _working = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.of(context, listen: false).refreshNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final items = controller.notifications.where((item) {
      return switch (_filter) {
        _NotificationFilter.all => true,
        _NotificationFilter.community => item.type.isCommunity,
        _NotificationFilter.friend => item.type.isFriendOrCompanion,
      };
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1E8D7),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: Color(0xFF4A382C),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (controller.unreadNotificationCount > 0)
            TextButton(
              onPressed: controller.markAllNotificationsRead,
              child: const Text('모두 읽음'),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: controller.refreshNotifications,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
          children: [
            _FilterRow(
              selected: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: '새로운 알림이 없어요',
                  description: '추천, 댓글, 친구 요청, 동행 요청을 여기에서 확인할 수 있어요.',
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _NotificationCard(
                    item: item,
                    isWorking: _working.contains(item.id),
                    onTap: () => _openNotification(item, controller),
                    onAccept: _acceptAction(item, controller),
                    onReject: _rejectAction(item, controller),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  VoidCallback? _acceptAction(
    AppNotificationItem item,
    AppController controller,
  ) {
    return switch (item.type) {
      AppNotificationType.friendRequest =>
        controller.isIncomingFriendRequest(item.friendshipId)
            ? () => _acceptFriend(item, controller)
            : null,
      AppNotificationType.routeCompanionInvite =>
        controller.isRouteCompanionRequestPending(item.routeRequestId)
            ? () => _acceptCompanion(item, controller)
            : null,
      _ => null,
    };
  }

  VoidCallback? _rejectAction(
    AppNotificationItem item,
    AppController controller,
  ) {
    return switch (item.type) {
      AppNotificationType.friendRequest =>
        controller.isIncomingFriendRequest(item.friendshipId)
            ? () => _rejectFriend(item, controller)
            : null,
      AppNotificationType.routeCompanionInvite =>
        controller.isRouteCompanionRequestPending(item.routeRequestId)
            ? () => _rejectCompanion(item, controller)
            : null,
      _ => null,
    };
  }

  Future<void> _openNotification(
    AppNotificationItem item,
    AppController controller,
  ) async {
    if (!item.isRead) {
      await controller.markNotificationRead(item.id);
    }
    if (!mounted) return;

    if (!item.type.isCommunity) return;

    final postId = item.postId;
    if (postId == null || postId.isEmpty) return;

    var post = controller.communityPostById(postId);
    if (post == null) {
      await controller.loadCommunityPosts(silent: true);
      post = controller.communityPostById(postId);
    }

    if (!mounted) return;

    if (post == null) {
      showAppSnackBar(context, '해당 게시물을 불러오지 못했어요.');
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CommunityPostDetailScreen(
          initialPost: post!,
          autofocusComment: item.type == AppNotificationType.comment,
        ),
      ),
    );
  }

  Future<void> _acceptFriend(
    AppNotificationItem item,
    AppController controller,
  ) async {
    final friendshipId = item.friendshipId;
    if (friendshipId == null || _working.contains(item.id)) return;

    setState(() => _working.add(item.id));
    await controller.acceptFriend(friendshipId);
    await controller.markNotificationRead(item.id);
    await controller.refreshNotifications(silent: true);

    if (!mounted) return;
    setState(() => _working.remove(item.id));
    showAppSnackBar(
      context,
      controller.friendMessage ?? '친구 요청을 수락했어요.',
    );
  }

  Future<void> _rejectFriend(
    AppNotificationItem item,
    AppController controller,
  ) async {
    final friendshipId = item.friendshipId;
    if (friendshipId == null || _working.contains(item.id)) return;

    setState(() => _working.add(item.id));
    await controller.removeFriend(friendshipId);
    await controller.markNotificationRead(item.id);
    await controller.refreshNotifications(silent: true);

    if (!mounted) return;
    setState(() => _working.remove(item.id));
    showAppSnackBar(context, '친구 요청을 거절했어요.');
  }

  Future<void> _acceptCompanion(
    AppNotificationItem item,
    AppController controller,
  ) async {
    if (_working.contains(item.id)) return;
    setState(() => _working.add(item.id));

    final ok = await controller.acceptRouteCompanionNotification(item);
    await controller.refreshNotifications(silent: true);

    if (!mounted) return;
    setState(() => _working.remove(item.id));
    showAppSnackBar(
      context,
      controller.sharedRouteMessage ??
          (ok ? '동행 요청을 수락했어요.' : '동행 요청을 처리하지 못했어요.'),
    );
  }

  Future<void> _rejectCompanion(
    AppNotificationItem item,
    AppController controller,
  ) async {
    if (_working.contains(item.id)) return;
    setState(() => _working.add(item.id));

    final ok = await controller.rejectRouteCompanionNotification(item);
    await controller.refreshNotifications(silent: true);

    if (!mounted) return;
    setState(() => _working.remove(item.id));
    showAppSnackBar(
      context,
      controller.sharedRouteMessage ??
          (ok ? '동행 요청을 거절했어요.' : '동행 요청을 처리하지 못했어요.'),
    );
  }
}

enum _NotificationFilter { all, community, friend }

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.selected,
    required this.onChanged,
  });

  final _NotificationFilter selected;
  final ValueChanged<_NotificationFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _FilterChip(
          label: '전체',
          selected: selected == _NotificationFilter.all,
          onTap: () => onChanged(_NotificationFilter.all),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: '커뮤니티',
          selected: selected == _NotificationFilter.community,
          onTap: () => onChanged(_NotificationFilter.community),
        ),
        const SizedBox(width: 8),
        _FilterChip(
          label: '친구·동행',
          selected: selected == _NotificationFilter.friend,
          onTap: () => onChanged(_NotificationFilter.friend),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF315E4F) : const Color(0xFFFFFBF3),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF315E4F) : const Color(0xFFD6B166),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isWorking,
    required this.onTap,
    this.onAccept,
    this.onReject,
  });

  final AppNotificationItem item;
  final bool isWorking;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.type) {
      AppNotificationType.recommendation => Icons.favorite_outline_rounded,
      AppNotificationType.comment => Icons.chat_bubble_outline_rounded,
      AppNotificationType.friendRequest => Icons.person_add_alt_1_rounded,
      AppNotificationType.friendAccepted => Icons.people_alt_outlined,
      AppNotificationType.routeCompanionInvite => Icons.group_add_outlined,
      AppNotificationType.routeCompanionAccepted => Icons.route_outlined,
      AppNotificationType.unknown => Icons.notifications_none_rounded,
    };

    final iconColor = switch (item.type) {
      AppNotificationType.recommendation => AppColors.danger,
      AppNotificationType.comment => AppColors.forestLight,
      AppNotificationType.friendRequest => AppColors.forest,
      AppNotificationType.friendAccepted => AppColors.success,
      AppNotificationType.routeCompanionInvite => AppColors.gold,
      AppNotificationType.routeCompanionAccepted => AppColors.success,
      AppNotificationType.unknown => AppColors.muted,
    };

    return Material(
      color: item.isRead
          ? const Color(0xFFFFFBF3)
          : const Color(0xFFFFF4DB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: item.isRead
                  ? const Color(0xFFE0CDA7)
                  : const Color(0xFFC79B52),
              width: item.isRead ? 1 : 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.danger,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.message,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.muted,
                      ),
                    ),
                    if (onAccept != null || onReject != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (onAccept != null)
                            Expanded(
                              child: FilledButton(
                                onPressed: isWorking ? null : onAccept,
                                child: isWorking
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('수락'),
                              ),
                            ),
                          if (onAccept != null && onReject != null)
                            const SizedBox(width: 8),
                          if (onReject != null)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isWorking ? null : onReject,
                                child: const Text('거절'),
                              ),
                            ),
                        ],
                      ),
                    ],
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
