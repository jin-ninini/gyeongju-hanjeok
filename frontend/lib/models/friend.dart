class FriendUser {
  const FriendUser({
    required this.userId,
    required this.memberCode,
    required this.nickname,
  });

  final String userId;
  final String memberCode;
  final String nickname;

  factory FriendUser.fromJson(Map<String, dynamic> json) => FriendUser(
        userId: (json['user_id'] ?? '').toString(),
        memberCode: (json['member_code'] ?? '').toString(),
        nickname: (json['nickname'] ?? '').toString(),
      );
}

class Friendship {
  const Friendship({
    required this.id,
    required this.status,
    required this.direction,
    required this.user,
    required this.createdAt,
    this.acceptedAt,
  });

  final String id;
  final String status;
  final String direction;
  final FriendUser user;
  final DateTime? createdAt;
  final DateTime? acceptedAt;

  bool get isAccepted => status == 'accepted';
  bool get isIncoming => direction == 'incoming';
  bool get isOutgoing => direction == 'outgoing';

  factory Friendship.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};

    return Friendship(
      id: (json['friendship_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      direction: (json['direction'] ?? '').toString(),
      user: FriendUser.fromJson(userJson),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      acceptedAt: DateTime.tryParse((json['accepted_at'] ?? '').toString()),
    );
  }
}

class FriendList {
  const FriendList({
    required this.friends,
    required this.incoming,
    required this.outgoing,
  });

  final List<Friendship> friends;
  final List<Friendship> incoming;
  final List<Friendship> outgoing;

  factory FriendList.fromJson(Map<String, dynamic> json) {
    List<Friendship> parse(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((item) => Friendship.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return FriendList(
      friends: parse(json['friends']),
      incoming: parse(json['incoming']),
      outgoing: parse(json['outgoing']),
    );
  }
}

class FriendInvite {
  const FriendInvite({
    required this.token,
    required this.inviteUrl,
    required this.deepLink,
    required this.expiresAt,
  });

  final String token;
  final String inviteUrl;
  final String deepLink;
  final DateTime? expiresAt;

  factory FriendInvite.fromJson(Map<String, dynamic> json) => FriendInvite(
        token: (json['invite_token'] ?? '').toString(),
        inviteUrl: (json['invite_url'] ?? '').toString(),
        deepLink: (json['deep_link'] ?? '').toString(),
        expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
      );
}
