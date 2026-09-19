enum AppNotificationType {
  recommendation,
  comment,
  friendRequest,
  friendAccepted,
  routeCompanionInvite,
  routeCompanionAccepted,
  unknown;

  bool get isCommunity =>
      this == AppNotificationType.recommendation ||
      this == AppNotificationType.comment;

  bool get isFriendOrCompanion =>
      this == AppNotificationType.friendRequest ||
      this == AppNotificationType.friendAccepted ||
      this == AppNotificationType.routeCompanionInvite ||
      this == AppNotificationType.routeCompanionAccepted;

  bool get needsDecision =>
      this == AppNotificationType.friendRequest ||
      this == AppNotificationType.routeCompanionInvite;

  String get value => switch (this) {
        AppNotificationType.recommendation => 'recommendation',
        AppNotificationType.comment => 'comment',
        AppNotificationType.friendRequest => 'friend_request',
        AppNotificationType.friendAccepted => 'friend_accepted',
        AppNotificationType.routeCompanionInvite => 'shared_route_invite',
        AppNotificationType.routeCompanionAccepted =>
          'shared_route_invite_accepted',
        AppNotificationType.unknown => 'unknown',
      };

  static AppNotificationType fromValue(String value) {
    return switch (value.trim()) {
      'recommendation' => AppNotificationType.recommendation,
      'comment' => AppNotificationType.comment,
      'friend_request' => AppNotificationType.friendRequest,
      'friendRequest' => AppNotificationType.friendRequest,
      'friend_accepted' => AppNotificationType.friendAccepted,
      'shared_route_invite' => AppNotificationType.routeCompanionInvite,
      'routeCompanionInvite' => AppNotificationType.routeCompanionInvite,
      'shared_route_invite_accepted' =>
        AppNotificationType.routeCompanionAccepted,
      _ => AppNotificationType.unknown,
    };
  }
}

class NotificationActor {
  const NotificationActor({
    required this.userId,
    required this.nickname,
    this.memberCode,
  });

  final String userId;
  final String nickname;
  final String? memberCode;

  factory NotificationActor.fromJson(Map<String, dynamic> json) {
    return NotificationActor(
      userId: (json['user_id'] ?? '').toString(),
      memberCode: _nullableString(json['member_code']),
      nickname: (json['nickname'] ?? '경주한적 사용자').toString(),
    );
  }
}

class AppNotificationItem {
  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
    this.actor,
    this.postId,
    this.friendshipId,
    this.sharedRouteId,
    this.routeRequestId,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final NotificationActor? actor;
  final String? postId;
  final String? friendshipId;
  final String? sharedRouteId;
  final String? routeRequestId;

  AppNotificationItem copyWith({
    bool? isRead,
  }) {
    return AppNotificationItem(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      actor: actor,
      postId: postId,
      friendshipId: friendshipId,
      sharedRouteId: sharedRouteId,
      routeRequestId: routeRequestId,
    );
  }

  Map<String, dynamic> toJson() => {
        'notification_id': id,
        'id': id,
        'type': type.value,
        'title': title,
        'message': message,
        'created_at': createdAt.toIso8601String(),
        'is_read': isRead,
        'actor': actor == null
            ? null
            : {
                'user_id': actor!.userId,
                'member_code': actor!.memberCode,
                'nickname': actor!.nickname,
              },
        'post_id': postId,
        'friendship_id': friendshipId,
        'shared_route_id': sharedRouteId,
        'route_request_id': routeRequestId,
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    final actorRaw = json['actor'];
    final actor = actorRaw is Map
        ? NotificationActor.fromJson(Map<String, dynamic>.from(actorRaw))
        : null;

    return AppNotificationItem(
      id: (json['notification_id'] ?? json['id'] ?? '').toString(),
      type: AppNotificationType.fromValue((json['type'] ?? '').toString()),
      title: (json['title'] ?? '알림').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      isRead: json['is_read'] == true,
      actor: actor,
      postId: _nullableString(json['post_id']),
      friendshipId: _nullableString(json['friendship_id']),
      sharedRouteId: _nullableString(json['shared_route_id']),
      routeRequestId: _nullableString(json['route_request_id']),
    );
  }
}

class NotificationFeed {
  const NotificationFeed({
    required this.items,
    required this.unreadCount,
  });

  final List<AppNotificationItem> items;
  final int unreadCount;

  factory NotificationFeed.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => AppNotificationItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <AppNotificationItem>[];

    return NotificationFeed(
      items: items,
      unreadCount: _asInt(json['unread_count']),
    );
  }
}

class RouteCompanionRequest {
  const RouteCompanionRequest({
    required this.requestId,
    required this.sharedRouteId,
    required this.requesterUserId,
    required this.recipientUserId,
    required this.requesterNickname,
    required this.status,
    required this.createdAt,
  });

  final String requestId;
  final String sharedRouteId;
  final String requesterUserId;
  final String recipientUserId;
  final String requesterNickname;
  final String status;
  final DateTime createdAt;

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';

  factory RouteCompanionRequest.fromJson(Map<String, dynamic> json) {
    return RouteCompanionRequest(
      requestId: (json['request_id'] ?? '').toString(),
      sharedRouteId: (json['shared_route_id'] ?? '').toString(),
      requesterUserId: (json['requester_user_id'] ?? '').toString(),
      recipientUserId: (json['recipient_user_id'] ?? '').toString(),
      requesterNickname:
          (json['requester_nickname'] ?? '경주한적 사용자').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
