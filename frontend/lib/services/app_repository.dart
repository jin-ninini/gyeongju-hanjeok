import 'package:geolocator/geolocator.dart';

import '../core/app_env.dart';
import '../data/preview_data.dart';
import '../models/app_notification.dart';
import '../models/place.dart';
import '../models/community.dart';
import '../models/friend.dart';
import '../models/route_plan.dart';
import '../models/shared_route.dart';
import '../models/user_account.dart';
import 'api_client.dart';

class AppRepository {
  AppRepository(this._client);

  final ApiClient _client;

  void setAccessToken(String? token) => _client.setAccessToken(token);

  Future<AuthSession> signUp({
    required String email,
    required String password,
    required String nickname,
    required bool termsAgreed,
    required bool privacyAgreed,
    required bool locationAgreed,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 450);
      return AuthSession(
        accessToken: 'preview-token',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        user: UserAccount(
          id: 'preview-user-001',
          memberCode: 'GJ-PRE001',
          email: email.trim().toLowerCase(),
          nickname: nickname.trim(),
          createdAt: DateTime.now(),
          consents: UserConsentState(
            termsAgreed: termsAgreed,
            privacyAgreed: privacyAgreed,
            locationAgreed: locationAgreed,
            termsVersion: '2026-09-14',
            privacyVersion: '2026-09-14',
            locationVersion: '2026-09-14',
          ),
        ),
      );
    }

    final data = await _client.post(
      '/auth/signup',
      data: {
        'email': email.trim(),
        'password': password,
        'nickname': nickname.trim(),
        'terms_agreed': termsAgreed,
        'privacy_agreed': privacyAgreed,
        'location_agreed': locationAgreed,
      },
    );
    return AuthSession.fromJson(_extractMap(data));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 350);
      return AuthSession(
        accessToken: 'preview-token',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        user: UserAccount(
          id: 'preview-user-001',
          memberCode: 'GJ-PRE001',
          email: email.trim().toLowerCase(),
          nickname: '한적 여행자',
          createdAt: DateTime.now(),
          consents: const UserConsentState(
            termsAgreed: true,
            privacyAgreed: true,
            locationAgreed: true,
            termsVersion: '2026-09-14',
            privacyVersion: '2026-09-14',
            locationVersion: '2026-09-14',
          ),
        ),
      );
    }

    final data = await _client.post(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );
    return AuthSession.fromJson(_extractMap(data));
  }

  Future<UserAccount> getCurrentUser() async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 180);
      return UserAccount(
        id: 'preview-user-001',
        memberCode: 'GJ-PRE001',
        email: 'preview@gyeongju-hanjeok.local',
        nickname: '한적 여행자',
        createdAt: DateTime.now(),
        consents: const UserConsentState(
          termsAgreed: true,
          privacyAgreed: true,
          locationAgreed: true,
          termsVersion: '2026-09-14',
          privacyVersion: '2026-09-14',
          locationVersion: '2026-09-14',
        ),
      );
    }

    final data = await _client.get('/auth/me');
    return UserAccount.fromJson(_extractMap(data));
  }

  Future<UserAccount> updateLocationConsent(bool agreed) async {
    if (AppEnv.isPreview) {
      return getCurrentUser();
    }

    final data = await _client.patch(
      '/auth/consents',
      data: {'location_agreed': agreed},
    );
    return UserAccount.fromJson(_extractMap(data));
  }

  Future<void> logout() async {
    if (!AppEnv.isPreview) {
      try {
        await _client.post('/auth/logout');
      } catch (_) {
        // 로컬 토큰 삭제가 실제 로그아웃의 핵심이므로 서버 응답 실패는 무시합니다.
      }
    }
    _client.setAccessToken(null);
  }


  Future<FriendList> getFriends() async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 180);
      return const FriendList(friends: [], incoming: [], outgoing: []);
    }
    final data = await _client.get('/friends');
    return FriendList.fromJson(_extractMap(data));
  }

  Future<Friendship> requestFriendByCode(String memberCode) async {
    final normalized = memberCode.trim().toUpperCase();
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 180);
      return Friendship(
        id: 'preview-friendship',
        status: 'pending',
        direction: 'outgoing',
        user: FriendUser(
          userId: 'preview-friend',
          memberCode: normalized,
          nickname: '경주 친구',
        ),
        createdAt: DateTime.now(),
      );
    }
    final data = await _client.post(
      '/friends/requests',
      data: {'member_code': normalized},
    );
    return Friendship.fromJson(_extractMap(data));
  }

  Future<Friendship> acceptFriend(String friendshipId) async {
    final data = await _client.post('/friends/$friendshipId/accept');
    return Friendship.fromJson(_extractMap(data));
  }

  Future<void> removeFriend(String friendshipId) async {
    if (AppEnv.isPreview) return;
    await _client.delete('/friends/$friendshipId');
  }

  Future<FriendInvite> createFriendInvite() async {
    if (AppEnv.isPreview) {
      return FriendInvite(
        token: 'preview-invite-token',
        inviteUrl: 'https://example.com/invite/preview-invite-token',
        deepLink: 'gyeongjuhanjeok://invite/preview-invite-token',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
    }
    final data = await _client.post('/friends/invites');
    return FriendInvite.fromJson(_extractMap(data));
  }

  Future<Friendship> claimFriendInvite(String token) async {
    if (AppEnv.isPreview) {
      return Friendship(
        id: 'preview-claimed-friendship',
        status: 'accepted',
        direction: 'friend',
        user: FriendUser(
          userId: 'preview-inviter',
          memberCode: 'GJ-INVITE',
          nickname: '초대한 친구',
        ),
        createdAt: DateTime.now(),
        acceptedAt: DateTime.now(),
      );
    }
    final data = await _client.post('/friends/invites/$token/claim');
    return Friendship.fromJson(_extractMap(data));
  }

  Future<List<SharedRoute>> listSharedRoutes() async {
    if (AppEnv.isPreview) {
      return const [];
    }

    final data = await _client.get('/shared-routes');
    final items = _extractList(data);

    return items
        .whereType<Map>()
        .map(
          (item) => SharedRoute.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<SharedRoute> createSharedRoute(RoutePlan route) async {
    if (AppEnv.isPreview) {
      return SharedRoute(
        id: 'preview-shared-route',
        sourceRouteId: route.id,
        ownerUserId: 'preview-user-001',
        version: 1,
        route: route,
        members: const [],
        updatedAt: DateTime.now(),
      );
    }

    final data = await _client.post(
      '/shared-routes',
      data: {
        'source_route_id': route.id,
        'route': route.toJson(),
      },
    );
    return SharedRoute.fromJson(_extractMap(data));
  }

  Future<SharedRoute> getSharedRoute(String sharedRouteId) async {
    final data = await _client.get('/shared-routes/$sharedRouteId');
    return SharedRoute.fromJson(_extractMap(data));
  }

  Future<SharedRoute> updateSharedRoute({
    required SharedRoute shared,
    required RoutePlan route,
  }) async {
    if (AppEnv.isPreview) {
      return SharedRoute(
        id: shared.id,
        sourceRouteId: shared.sourceRouteId,
        ownerUserId: shared.ownerUserId,
        version: shared.version + 1,
        route: route,
        members: shared.members,
        updatedAt: DateTime.now(),
      );
    }

    final data = await _client.put(
      '/shared-routes/${shared.id}',
      data: {
        'route': route.toJson(),
        'expected_version': shared.version,
      },
    );
    return SharedRoute.fromJson(_extractMap(data));
  }

  Future<SharedRoute> addSharedRouteMember({
    required String sharedRouteId,
    required String memberCode,
  }) async {
    final data = await _client.post(
      '/shared-routes/$sharedRouteId/members/by-code',
      data: {
        'member_code': memberCode.trim().toUpperCase(),
        'role': 'editor',
      },
    );
    return SharedRoute.fromJson(_extractMap(data));
  }

  Future<SharedRoute> removeSharedRouteMember({
    required String sharedRouteId,
    required String membershipId,
  }) async {
    final data = await _client.delete(
      '/shared-routes/$sharedRouteId/members/$membershipId',
    );
    return SharedRoute.fromJson(_extractMap(data));
  }

  Future<RouteCompanionInvite> createRouteCompanionInvite(
    String sharedRouteId,
  ) async {
    final data = await _client.post(
      '/shared-routes/$sharedRouteId/invites',
    );
    return RouteCompanionInvite.fromJson(_extractMap(data));
  }

  Future<SharedRoute> claimRouteCompanionInvite(String token) async {
    final data = await _client.post(
      '/shared-routes/invites/$token/claim',
    );
    return SharedRoute.fromJson(_extractMap(data));
  }

  Future<NotificationFeed> getNotifications({
    bool unreadOnly = false,
    int limit = 100,
  }) async {
    if (AppEnv.isPreview) {
      return const NotificationFeed(items: [], unreadCount: 0);
    }

    final data = await _client.get(
      '/notifications',
      queryParameters: {
        'unread_only': unreadOnly,
        'limit': limit,
      },
    );
    return NotificationFeed.fromJson(_extractMap(data));
  }

  Future<AppNotificationItem> markNotificationRead(
    String notificationId,
  ) async {
    final data = await _client.patch(
      '/notifications/$notificationId/read',
    );
    return AppNotificationItem.fromJson(_extractMap(data));
  }

  Future<void> markAllNotificationsRead() async {
    if (AppEnv.isPreview) return;
    await _client.patch('/notifications/read-all');
  }

  Future<RouteCompanionRequest> requestRouteCompanion({
    required String sharedRouteId,
    required String memberCode,
  }) async {
    final normalized = memberCode.trim().toUpperCase();
    final data = await _client.post(
      '/shared-routes/$sharedRouteId/companion-requests',
      data: {'member_code': normalized},
    );
    return RouteCompanionRequest.fromJson(_extractMap(data));
  }

  Future<List<RouteCompanionRequest>> getIncomingRouteCompanionRequests() async {
    if (AppEnv.isPreview) return const [];
    final data = await _client.get(
      '/shared-routes/companion-requests/incoming',
    );
    return _extractList(data)
        .whereType<Map>()
        .map(
          (item) => RouteCompanionRequest.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList();
  }

  Future<RouteCompanionRequest> acceptRouteCompanionRequest(
    String requestId,
  ) async {
    final data = await _client.post(
      '/shared-routes/companion-requests/$requestId/accept',
    );
    return RouteCompanionRequest.fromJson(_extractMap(data));
  }

  Future<RouteCompanionRequest> rejectRouteCompanionRequest(
    String requestId,
  ) async {
    final data = await _client.post(
      '/shared-routes/companion-requests/$requestId/reject',
    );
    return RouteCompanionRequest.fromJson(_extractMap(data));
  }

  /// 지도 검색 전용 조회입니다.
  ///
  /// 1차로 서버 키워드 검색을 사용하고, 결과가 비거나 일시적으로 실패하면
  /// 경주 장소 목록을 받아 프론트에서 정확/부분 일치 검색을 다시 수행합니다.
  /// 사용자 현재 GPS는 서버로 전송하지 않습니다.
  Future<List<Place>> searchPlacesForMap(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];

    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'\\s+'), '')
        .replaceAll(RegExp(r'[^0-9a-z가-힣]'), '');

    List<Place> rankMatches(List<Place> source) {
      final target = normalize(query);
      final matches = source.where((place) {
        final name = normalize(place.name);
        final address = normalize(place.address);
        return name == target ||
            name.contains(target) ||
            target.contains(name) ||
            address.contains(target);
      }).toList();

      matches.sort((a, b) {
        int rank(Place place) {
          final name = normalize(place.name);
          if (name == target) return 0;
          if (name.startsWith(target)) return 1;
          if (name.contains(target)) return 2;
          if (target.contains(name)) return 3;
          return 4;
        }

        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        return a.name.length.compareTo(b.name.length);
      });
      return matches;
    }

    if (AppEnv.isPreview) {
      await _previewDelay();
      return rankMatches(PreviewData.places);
    }

    try {
      final data = await _client.get(
        '/places',
        queryParameters: {
          'query': query,
          'radius_km': 20,
          'limit': 100,
        },
      );
      final direct = rankMatches(_extractList(data).map(Place.fromJson).toList());
      if (direct.isNotEmpty) return direct;
    } catch (_) {
      // 아래 전체 목록 fallback으로 이어갑니다.
    }

    try {
      final data = await _client.get(
        '/places',
        queryParameters: {
          'radius_km': 20,
          'limit': 100,
        },
      );
      return rankMatches(_extractList(data).map(Place.fromJson).toList());
    } catch (_) {
      return const [];
    }
  }

  Future<List<Place>> getPlaces({
    String query = '',
    String category = '',
    double? latitude,
    double? longitude,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay();
      final preview = PreviewData.places.where((place) {
        final queryMatched = query.isEmpty ||
            place.name.contains(query) ||
            place.address.contains(query) ||
            place.category.contains(query);

        final categoryMatched =
            query.isNotEmpty && (category.isEmpty || category == '전체')
                ? true
                : place.matchesHomeCategory(category);

        return queryMatched && categoryMatched;
      }).toList();
      if (query.isEmpty && category == '핫플레이스') {
        preview.sort((a, b) => b.hotPlaceScore.compareTo(a.hotPlaceScore));
      }
      return _applyLocalDistances(
        preview,
        latitude: latitude,
        longitude: longitude,
      );
    }

    // 사용자의 현재 위치는 백엔드로 전송하지 않습니다.
    // 서버는 경주 공공 관광지/혼잡도 정보만 내려주고,
    // 사용자-장소 간 거리는 단말기에서 계산합니다.
    final data = await _client.get(
      '/places',
      queryParameters: {
        if (query.isNotEmpty) 'query': query,
        'radius_km': 20,
        'limit': 100,
      },
    );
    final rawPlaces = _extractList(data).map(Place.fromJson).toList();

    final places =
        query.isNotEmpty && (category.isEmpty || category == '전체')
            ? rawPlaces
            : rawPlaces
                .where((place) => place.matchesHomeCategory(category))
                .toList();

    if (query.isEmpty && category == '핫플레이스') {
      places.sort((a, b) => b.hotPlaceScore.compareTo(a.hotPlaceScore));
    }

    return _applyLocalDistances(
      places,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<Place?> getNearestTourist({
    required double latitude,
    required double longitude,
  }) async {
    final candidates = await getPlaces(
      latitude: latitude,
      longitude: longitude,
    );

    final touristCandidates = candidates
        .where(
          (place) =>
              place.contentTypeId != '39' &&
              place.category != '맛집' &&
              place.category != '카페' &&
              place.category != '음식점',
        )
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return touristCandidates.isEmpty ? null : touristCandidates.first;
  }

  Future<List<Place>> getNearbyPlaces({
    required double latitude,
    required double longitude,
    double radiusKm = 15,
  }) async {
    final candidates = await getPlaces(
      latitude: latitude,
      longitude: longitude,
    );

    final withinRadius = candidates
        .where((place) => place.distanceKm <= radiusKm)
        .toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    // 경주 외곽 등에서 고정 경주 카탈로그와 반경이 겹치지 않는 경우에도
    // 빈 화면 대신 가장 가까운 후보를 보여줍니다.
    if (withinRadius.isNotEmpty) {
      return withinRadius;
    }

    final nearest = [...candidates]
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return nearest.take(30).toList();
  }

  Future<Place> getPlaceDetail(
    Place initial,
  ) async {
    return _getPlaceDetailStage(
      initial,
      stage: 'core',
    );
  }

  Future<Place> getPlaceDetailExtras(
    Place initial,
  ) async {
    return _getPlaceDetailStage(
      initial,
      stage: 'full',
    );
  }

  Future<Place> _getPlaceDetailStage(
    Place initial, {
    required String stage,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay();
      return initial;
    }

    final detailData = await _client.get(
      '/places/${initial.id}',
      queryParameters: {
        if (initial.contentTypeId.isNotEmpty)
          'content_type_id':
              initial.contentTypeId,
        'title': initial.name,
        'address': initial.address,
        'latitude': initial.latitude,
        'longitude': initial.longitude,
        'stage': stage,
      },
    );

    final mergedDetail =
        _placeSeedJson(initial);

    for (final entry
        in _extractMap(detailData).entries) {
      final value = entry.value;

      if (value == null) {
        continue;
      }

      if (
        value is String &&
        value.trim().isEmpty
      ) {
        continue;
      }

      // 빈 리스트도 의도적인 응답입니다.
      // 관련 콘텐츠 정확 일치 결과가 없으면 이전 링크를 지웁니다.
      mergedDetail[entry.key] = value;
    }

    return Place.fromJson(
      mergedDetail,
    );
  }


  Future<List<Place>> getCurrentCongestion() async {
    if (AppEnv.isPreview) {
      await _previewDelay();
      return PreviewData.places;
    }

    final data = await _client.get('/congestion/now');
    return _extractList(data).map(Place.fromJson).toList();
  }

  Future<Place> refreshPlaceCongestion(Place place) async {
    if (AppEnv.isPreview) {
      await _previewDelay();
      final adjusted = (place.quietScore - 2 + DateTime.now().second % 5).clamp(0, 100).toInt();
      return place.copyWith(quietScore: adjusted);
    }

    final data = await _client.get(
      '/congestion/${place.id}',
      queryParameters: {'title': place.name},
    );
    final map = _extractMap(data);
    final merged = <String, dynamic>{
      'id': place.id,
      'name': place.name,
      'address': place.address,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'quiet_score': place.quietScore,
      'category': place.category,
      'description': place.description,
      'image_url': place.imageUrl,
      'image_asset': place.imageAsset,
      'distance_km': place.distanceKm,
      'has_local_distance': place.hasLocalDistance,
      'recommended_time': place.recommendedTime,
      'stay_minutes': place.stayMinutes,
      'is_paid': place.isPaid,
      'blog_count': place.blogCount,
      'video_count': place.videoCount,
      ...map,
    };
    return Place.fromJson(merged);
  }

  Future<RoutePlan> recommendRoute(RoutePreferences preferences) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 850);
      return PreviewData.route();
    }

    final data = await _client.post(
      '/routes/recommend',
      data: preferences.toJson(contract: AppEnv.backendContract),
    );
    return _validatedRoute(data);
  }

  Future<RoutePlan> refreshRoute({
    required RoutePlan current,
    required RoutePreferences preferences,
    String reason = 'congestion_changed',
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 700);
      return PreviewData.route(title: '혼잡 변화를 반영한 대체 코스');
    }

    final data = await _client.post(
      '/routes/recommend/refresh',
      data: AppEnv.usesCamelContract
          ? {
              'course_id': current.id,
              'reason': reason,
              'course': _routeRequestJson(current),
            }
          : {
              'route_id': current.id,
              'reason': reason,
              'current_route': _routeRequestJson(current),
              'preferences': preferences.toJson(contract: AppEnv.backendContract),
            },
    );
    return _validatedRoute(data);
  }

  Future<RoutePlan> replaceRouteStop({
    required RoutePlan current,
    required RouteStop stop,
    required String transportType,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 500);
      return current;
    }

    final data = await _client.post(
      '/routes/replace-stop',
      data: {
        'current_route': _routeRequestJson(current),
        'target_place_id': stop.place.id,
        'target_name': stop.place.name,
        // 실제 사용자 GPS는 전송하지 않습니다.
        'transport_type': transportType,
      },
    );

    return _validatedRoute(data);
  }

  Future<RoutePlan> modifyRoute({
    required RoutePlan current,
    required String message,
    required RoutePreferences preferences,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 700);
      final title = message.contains('카페')
          ? '카페 휴식을 더한 한적 코스'
          : message.contains('짧')
              ? '이동을 줄인 짧은 코스'
              : '요청을 반영한 맞춤 코스';
      return PreviewData.route(title: title);
    }

    final data = await _client.post(
      '/chat/modify-course',
      data: AppEnv.usesCamelContract
          ? {
              'courseId': current.id,
              'message': message,
              'lockedPlaceIds': const <String>[],
              'excludedPlaceIds': const <String>[],
              'course': _routeRequestJson(current),
            }
          : {
              'route_id': current.id,
              'message': message,
              'current_route': _routeRequestJson(current),
              'preferences': preferences.toJson(),
            },
    );
    return _validatedRoute(data);
  }

  Future<void> checkIn(String placeId) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 250);
      return;
    }
    await _client.post('/visits/check-in', data: {'place_id': placeId});
  }

  Future<Map<String, dynamic>> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 250);
      return const {
        'summary': '구름 조금',
        'temperature': 24,
        'outdoor_suitable': true,
      };
    }

    // 경주 서비스 기준 날씨를 조회합니다.
    // 사용자의 실제 GPS 좌표는 백엔드로 보내지 않습니다.
    final data = await _client.get('/weather/current');
    return _extractMap(data);
  }


  Future<List<CommunityPost>> getCommunityPosts({
    CommunityPostType? postType,
    String sort = 'latest',
    String? placeId,
  }) async {
    if (AppEnv.isPreview) {
      await _previewDelay(milliseconds: 180);
      return const [];
    }

    final data = await _client.get(
      '/community/posts',
      queryParameters: {
        if (postType != null) 'post_type': postType.value,
        'sort': sort,
        if (placeId != null && placeId.trim().isNotEmpty) 'place_id': placeId.trim(),
      },
    );
    return _extractList(data).map(CommunityPost.fromJson).toList();
  }

  Future<CommunityPost> createCommunityPost(Map<String, dynamic> payload) async {
    if (AppEnv.isPreview) {
      throw const ApiException('게시물을 등록할 수 없어요. 잠시 후 다시 시도해주세요.');
    }
    final data = await _client.post('/community/posts', data: payload);
    return CommunityPost.fromJson(_extractMap(data));
  }

  Future<CommunityPost> getCommunityPost(String postId) async {
    final data = await _client.get('/community/posts/$postId');
    return CommunityPost.fromJson(_extractMap(data));
  }

  Future<void> reportCommunityPost({
    required String postId,
    required String reason,
    String detail = '',
  }) async {
    if (AppEnv.isPreview) return;
    await _client.post(
      '/community/posts/$postId/report',
      data: {'reason': reason, 'detail': detail.trim()},
    );
  }

  Future<void> hideCommunityPost(String postId) async {
    if (AppEnv.isPreview) return;
    await _client.post('/community/posts/$postId/hide');
  }

  Future<Map<String, dynamic>> toggleCommunityRecommendation({
    required String postId,
    required bool recommend,
  }) async {
    final data = recommend
        ? await _client.post('/community/posts/$postId/recommend')
        : await _client.delete('/community/posts/$postId/recommend');
    return _extractMap(data);
  }

  Future<List<CommunityComment>> getCommunityComments(String postId) async {
    if (AppEnv.isPreview) return const [];
    final data = await _client.get('/community/posts/$postId/comments');
    return _extractList(data).map(CommunityComment.fromJson).toList();
  }

  Future<CommunityComment> createCommunityComment({
    required String postId,
    required String content,
  }) async {
    final data = await _client.post(
      '/community/posts/$postId/comments',
      data: {'content': content.trim()},
    );
    return CommunityComment.fromJson(_extractMap(data));
  }

  Future<void> deleteCommunityComment(String commentId) async {
    if (AppEnv.isPreview) return;
    await _client.delete('/community/comments/$commentId');
  }

  Future<void> setCommunityCourseSaved({
    required String postId,
    required bool saved,
  }) async {
    if (AppEnv.isPreview) return;
    if (saved) {
      await _client.post('/community/posts/$postId/save-course');
    } else {
      await _client.delete('/community/posts/$postId/save-course');
    }
  }

  Future<CommunityCourseCopy> getCommunityCourseCopy(String postId) async {
    final data = await _client.get('/community/posts/$postId/course-copy');
    return CommunityCourseCopy.fromJson(_extractMap(data));
  }

  Future<Map<String, dynamic>> getCommunityLiveSummary(String placeId) async {
    if (AppEnv.isPreview) return const <String, dynamic>{};
    final data = await _client.get('/community/places/$placeId/live-summary');
    return _extractMap(data);
  }

  Future<void> _previewDelay({int milliseconds = 420}) =>
      Future<void>.delayed(Duration(milliseconds: milliseconds));
}


List<Place> _applyLocalDistances(
  List<Place> places, {
  double? latitude,
  double? longitude,
}) {
  if (latitude == null || longitude == null) {
    return places;
  }

  return places
      .map(
        (place) => place.copyWith(
          distanceKm: Geolocator.distanceBetween(
                latitude,
                longitude,
                place.latitude,
                place.longitude,
              ) /
              1000,
          hasLocalDistance: true,
        ),
      )
      .toList();
}

RoutePlan _validatedRoute(dynamic data) {
  final route = RoutePlan.fromJson(_extractMap(data));
  if (route.stops.isEmpty) {
    throw const ApiException(
      '추천 가능한 장소가 없어요. 테마나 여행 시간을 바꿔 다시 시도해주세요.',
    );
  }
  if (route.stops.any((stop) => stop.place.id.trim().isEmpty)) {
    throw const ApiException('코스 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
  }
  return route;
}

Map<String, dynamic> _placeSeedJson(Place place) {
  return {
    'id': place.id,
    'name': place.name,
    'address': place.address,
    'latitude': place.latitude,
    'longitude': place.longitude,
    'quiet_score': place.quietScore,
    'category': place.category,
    'description': place.description,
    'image_url': place.imageUrl,
    'image_asset': place.imageAsset,
    'distance_km': place.distanceKm,
    'has_local_distance': place.hasLocalDistance,
    'recommended_time': place.recommendedTime,
    'stay_minutes': place.stayMinutes,
    'is_paid': place.isPaid,
    'content_type_id': place.contentTypeId,
    'etiquette': place.etiquette,
    'blog_count': place.blogCount,
    'video_count': place.videoCount,
    'content_links': place.contentLinks
        .map(
          (link) => {
            'title': link.title,
            'url': link.url,
            'type': link.type,
          },
        )
        .toList(),
    'operating_hours': place.operatingHours,
    'operating_hours_label': place.operatingHoursLabel,
    'break_time': place.breakTime,
    'rest_date': place.restDate,
    'fee_text': place.feeText,
    'parking': place.parking,
    'phone': place.phone,
    'homepage': place.homepage,
    'kakao_place_url': place.kakaoPlaceUrl,
    'representative_menu': place.representativeMenu,
    'menu_items': place.menuItems
        .map((item) => item.toJson())
        .toList(),
    'community_congestion_score': place.communityCongestionScore,
    'community_report_count': place.communityReportCount,
    'community_latest_observed_at': place.communityLatestObservedAt?.toIso8601String(),
    'routing_congestion_score': place.routingCongestionScore,
  };
}

Map<String, dynamic> _routeRequestJson(RoutePlan route) {
  return {
    'id': route.id,
    'title': route.title,
    'stops': route.stops
        .map(
          (stop) => {
            'order': stop.order,
            'place_id': stop.place.id,
            'placeId': stop.place.id,
            'name': stop.place.name,
            'content_type_id': stop.place.contentTypeId,
          },
        )
        .toList(),
  };
}

Map<String, dynamic> _extractMap(dynamic data) {
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    for (final key in const [
      'data',
      'result',
      'response',
      'body',
      'item',
      'route',
      'course',
      'place',
    ]) {
      final nested = map[key];
      if (nested is Map) return _extractMap(nested);
    }
    return map;
  }
  throw const ApiException('정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
}

List<Map<String, dynamic>> _extractList(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    for (final key in const [
      'places',
      'items',
      'results',
      'content',
      'links',
      'data',
      'result',
      'response',
      'body',
      'item',
    ]) {
      if (map.containsKey(key)) {
        final nested = map[key];
        if (nested == null) return const [];
        return _extractList(nested);
      }
    }
    return map.isEmpty ? const [] : [map];
  }

  return const [];
}

List<String> _extractStringList(dynamic value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  if (value is String && value.trim().isNotEmpty) return [value.trim()];
  return const [];
}
