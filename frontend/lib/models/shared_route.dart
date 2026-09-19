import 'route_plan.dart';

class SharedRouteMember {
  const SharedRouteMember({
    required this.membershipId,
    required this.userId,
    required this.memberCode,
    required this.nickname,
    required this.role,
    required this.joinedAt,
  });

  final String membershipId;
  final String userId;
  final String memberCode;
  final String nickname;
  final String role;
  final DateTime? joinedAt;

  bool get isOwner => role == 'owner';
  bool get canEdit => role == 'owner' || role == 'editor';

  factory SharedRouteMember.fromJson(Map<String, dynamic> json) {
    return SharedRouteMember(
      membershipId: (json['membership_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      memberCode: (json['member_code'] ?? '').toString(),
      nickname: (json['nickname'] ?? '').toString(),
      role: (json['role'] ?? 'viewer').toString(),
      joinedAt: DateTime.tryParse((json['joined_at'] ?? '').toString()),
    );
  }
}

class SharedRoute {
  const SharedRoute({
    required this.id,
    required this.sourceRouteId,
    required this.ownerUserId,
    required this.version,
    required this.route,
    required this.members,
    required this.updatedAt,
  });

  final String id;
  final String sourceRouteId;
  final String ownerUserId;
  final int version;
  final RoutePlan route;
  final List<SharedRouteMember> members;
  final DateTime? updatedAt;

  bool isOwner(String? userId) => userId != null && ownerUserId == userId;

  factory SharedRoute.fromJson(Map<String, dynamic> json) {
    final routeJson = json['route'] is Map
        ? Map<String, dynamic>.from(json['route'] as Map)
        : const <String, dynamic>{};

    final rawMembers = json['members'] is List
        ? json['members'] as List
        : const <dynamic>[];

    return SharedRoute(
      id: (json['shared_route_id'] ?? '').toString(),
      sourceRouteId: (json['source_route_id'] ?? '').toString(),
      ownerUserId: (json['owner_user_id'] ?? '').toString(),
      version: _intValue(json['version'], 1),
      route: RoutePlan.fromJson(routeJson),
      members: rawMembers
          .whereType<Map>()
          .map(
            (item) => SharedRouteMember.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }
}

class RouteCompanionInvite {
  const RouteCompanionInvite({
    required this.token,
    required this.sharedRouteId,
    required this.inviteUrl,
    required this.deepLink,
    required this.expiresAt,
  });

  final String token;
  final String sharedRouteId;
  final String inviteUrl;
  final String deepLink;
  final DateTime? expiresAt;

  factory RouteCompanionInvite.fromJson(Map<String, dynamic> json) {
    return RouteCompanionInvite(
      token: (json['invite_token'] ?? '').toString(),
      sharedRouteId: (json['shared_route_id'] ?? '').toString(),
      inviteUrl: (json['invite_url'] ?? '').toString(),
      deepLink: (json['deep_link'] ?? '').toString(),
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
    );
  }
}

int _intValue(dynamic value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
