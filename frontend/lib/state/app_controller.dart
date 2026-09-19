import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_env.dart';
import '../models/app_notification.dart';
import '../models/completed_trip.dart';
import '../models/community.dart';
import '../models/friend.dart';
import '../models/place.dart';
import '../models/route_plan.dart';
import '../models/shared_route.dart';
import '../models/user_account.dart';
import '../services/app_repository.dart';
import '../services/api_client.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';

class AppController extends ChangeNotifier {
  AppController({
    required AppRepository repository,
    required LocationService locationService,
    required StorageService storageService,
  })  : _repository = repository,
        _locationService = locationService,
        _storageService = storageService;

  final AppRepository _repository;
  final LocationService _locationService;
  final StorageService _storageService;

  bool isInitializing = true;
  bool isLoadingPlaces = false;
  bool isBuildingRoute = false;
  bool isUpdatingRoute = false;
  String? globalError;
  String? routeMessage;

  bool isAuthenticating = false;
  String? authError;
  UserAccount? currentUser;

  bool isLoadingFriends = false;
  String? friendMessage;
  List<Friendship> friends = const [];
  List<Friendship> incomingFriendRequests = const [];
  List<Friendship> outgoingFriendRequests = const [];
  FriendInvite? lastFriendInvite;

  // 알림은 서버 /notifications API를 단일 원본으로 사용합니다.
  List<AppNotificationItem> serverNotifications = const [];
  int _serverUnreadNotificationCount = 0;
  Set<String> _pendingRouteCompanionRequestIds = <String>{};

  List<AppNotificationItem> get notifications => serverNotifications;

  int get unreadNotificationCount => _serverUnreadNotificationCount;

  bool isIncomingFriendRequest(String? friendshipId) {
    if (friendshipId == null || friendshipId.isEmpty) return false;
    return incomingFriendRequests.any((item) => item.id == friendshipId);
  }

  bool isRouteCompanionRequestPending(String? requestId) {
    if (requestId == null || requestId.isEmpty) return false;
    return _pendingRouteCompanionRequestIds.contains(requestId);
  }

  bool isSharingRoute = false;
  String? sharedRouteMessage;
  SharedRoute? sharedRoute;
  RouteCompanionInvite? lastRouteCompanionInvite;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _appLinkSubscription;

  bool get isAuthenticated => currentUser != null;
  String? get userId => currentUser?.id;

  String _requireUserStorageId() {
    final id = currentUser?.id.trim();
    if (id == null || id.isEmpty) {
      throw StateError(
        '로그인된 사용자가 없어 계정별 로컬 데이터를 저장할 수 없습니다.',
      );
    }
    return id;
  }

  List<Place> places = const [];
  final Map<String, Place> _placeCache = <String, Place>{};

  final Map<String, Place> _placeDetailCoreCache =
      <String, Place>{};

  final Map<String, Place> _placeDetailFullCache =
      <String, Place>{};

  Set<String> savedPlaceIds = <String>{};
  Set<String> visitedPlaceIds = <String>{};
  Position? currentPosition;
  String selectedCategory = '전체';
  String searchQuery = '';

  RoutePlan? routePlan;
  RoutePreferences? lastPreferences;

  List<RoutePlan> savedRoutes = const [];
  List<SharedRoute> sharedRoutes = const [];
  bool isLoadingRouteLibrary = false;

  // 커뮤니티
  bool isLoadingCommunity = false;
  String? communityError;
  CommunityPostType? communityFilter;
  String communitySort = 'latest';
  List<CommunityPost> communityPosts = const [];
  CompletedTrip? pendingCommunityCourseReview;

  // 완료한 여행 기록
  List<CompletedTrip> completedTrips = const [];
  CompletedTrip? lastCompletedTrip;
  bool tripJustCompleted = false;
  bool tripActive = false;
  bool isCompletingStop = false;
  int currentStopIndex = 0;
  DateTime? lastCongestionCheck;
  Timer? _congestionTimer;

  double get latitude => currentPosition?.latitude ?? AppEnv.defaultLatitude;
  double get longitude => currentPosition?.longitude ?? AppEnv.defaultLongitude;

  List<Place> get savedPlaces => savedPlaceIds
      .map((id) => _placeCache[id])
      .whereType<Place>()
      .toList()
    ..sort((a, b) => b.quietScore.compareTo(a.quietScore));

  Place? get currentTripPlace {
    final route = routePlan;
    if (!tripActive || route == null || route.stops.isEmpty) return null;
    final safeIndex = currentStopIndex.clamp(0, route.stops.length - 1).toInt();
    return route.stops[safeIndex].place;
  }

  Future<void> initialize() async {
    _startAppLinkListener();
    isInitializing = true;
    globalError = null;
    authError = null;
    notifyListeners();

    try {
      final token = await _storageService.loadAuthToken();

      if (token != null) {
        _repository.setAccessToken(token);
        try {
          currentUser = await _repository.getCurrentUser();
        } catch (_) {
          currentUser = null;
          _repository.setAccessToken(null);
          await _storageService.clearAuthToken();
        }
      }

      if (isAuthenticated) {
        await _loadUserAppData();
        await _consumePendingFriendActions();
      }
    } catch (error) {
      globalError = _message(error);
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> _loadUserAppData() async {
    final storageUserId = _requireUserStorageId();

    // 로컬 저장 데이터는 계정별 키로 분리합니다.
    // 같은 기기에서 다른 계정으로 로그인해도 저장 장소/방문 기록/
    // 완료 코스/저장 코스가 서로 섞이지 않습니다.
    final saved = await _storageService.loadSavedPlaceIds(
      storageUserId,
    );
    final visited = await _storageService.loadVisitedPlaceIds(
      storageUserId,
    );
    final completed = await _storageService.loadCompletedTrips(
      storageUserId,
    );
    final savedCourseList = await _storageService.loadSavedRoutes(
      storageUserId,
    );

    savedPlaceIds = saved;
    visitedPlaceIds = visited;
    completedTrips = completed;
    savedRoutes = savedCourseList;

    for (final trip in completedTrips) {
      _cacheRoutePlaces(trip.route);
    }

    for (final route in savedRoutes) {
      _cacheRoutePlaces(route);
    }

    await loadPlaces();

    // 홈 카드 거리 표시는 휴대폰 GPS를 프론트 메모리에서만 사용해 계산합니다.
    // 위치 획득은 초기 화면을 막지 않도록 백그라운드에서 수행하며,
    // 좌표를 FastAPI나 로컬 영구저장소에 보내거나 저장하지 않습니다.
    if (currentUser?.consents.locationAgreed == true) {
      unawaited(refreshPlaceDistancesFromDevice());
    }

    await loadFriends(silent: true);
    await loadCommunityPosts(silent: true);
    await loadRouteLibrary(silent: true);
  }

  Future<bool> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    if (isAuthenticating) return false;
    isAuthenticating = true;
    authError = null;
    globalError = null;
    notifyListeners();

    try {
      final session = await _repository.login(
        email: email,
        password: password,
      );
      _repository.setAccessToken(session.accessToken);

      if (rememberMe) {
        await _storageService.saveAuthToken(
          session.accessToken,
        );
      } else {
        await _storageService.clearAuthToken();
      }

      currentUser = session.user;
      await _loadUserAppData();
      await _consumePendingFriendActions();
      return true;
    } catch (error) {
      authError = _message(error);
      return false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String nickname,
    required bool termsAgreed,
    required bool privacyAgreed,
    required bool locationAgreed,
    bool rememberMe = true,
  }) async {
    if (isAuthenticating) return false;
    isAuthenticating = true;
    authError = null;
    globalError = null;
    notifyListeners();

    try {
      final session = await _repository.signUp(
        email: email,
        password: password,
        nickname: nickname,
        termsAgreed: termsAgreed,
        privacyAgreed: privacyAgreed,
        locationAgreed: locationAgreed,
      );
      _repository.setAccessToken(session.accessToken);

      if (rememberMe) {
        await _storageService.saveAuthToken(
          session.accessToken,
        );
      } else {
        await _storageService.clearAuthToken();
      }

      currentUser = session.user;
      await _loadUserAppData();
      await _consumePendingFriendActions();
      return true;
    } catch (error) {
      authError = _message(error);
      return false;
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    if (isAuthenticating) return;
    isAuthenticating = true;
    notifyListeners();

    try {
      await _repository.logout();
    } finally {
      await _storageService.clearAuthToken();
      _repository.setAccessToken(null);
      currentUser = null;
      authError = null;
      globalError = null;
      places = const [];
      _placeCache.clear();
      savedPlaceIds = <String>{};
      visitedPlaceIds = <String>{};
      completedTrips = const [];
      savedRoutes = const [];
      sharedRoutes = const [];
      friends = const [];
      incomingFriendRequests = const [];
      outgoingFriendRequests = const [];
      lastFriendInvite = null;
      friendMessage = null;
      serverNotifications = const [];
      _serverUnreadNotificationCount = 0;
      _pendingRouteCompanionRequestIds = <String>{};
      sharedRoute = null;
      lastRouteCompanionInvite = null;
      sharedRouteMessage = null;
      isSharingRoute = false;
      communityPosts = const [];
      communityFilter = null;
      communitySort = 'latest';
      communityError = null;
      pendingCommunityCourseReview = null;
      lastCompletedTrip = null;
      tripJustCompleted = false;
      routePlan = null;
      lastPreferences = null;
      tripActive = false;
      isCompletingStop = false;
      currentStopIndex = 0;
      _congestionTimer?.cancel();
      _congestionTimer = null;
      isAuthenticating = false;
      notifyListeners();
    }
  }


  void _startAppLinkListener() {
    _appLinkSubscription ??= _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_handleAppLink(uri)),
      onError: (_) {},
    );
  }

  Future<void> _handleAppLink(Uri uri) async {
    if (uri.scheme.toLowerCase() != 'gyeongjuhanjeok') return;
    if (uri.pathSegments.isEmpty) return;

    final value = Uri.decodeComponent(uri.pathSegments.first).trim();
    if (value.isEmpty) return;

    if (uri.host == 'route-invite') {
      await _storageService.savePendingRouteInviteToken(value);
      sharedRouteMessage = '동행 코스 초대를 확인했어요. 로그인하면 코스를 연결합니다.';
      notifyListeners();
      if (isAuthenticated) {
        await _consumePendingFriendActions();
      }
      return;
    }

    if (uri.host == 'invite') {
      await _storageService.savePendingInviteToken(value);
      friendMessage = '동행 초대를 확인했어요. 로그인하면 자동으로 친구 연결을 진행합니다.';
      notifyListeners();
      if (isAuthenticated) {
        await _consumePendingFriendActions();
      }
      return;
    }

    if (uri.host == 'friend') {
      await _storageService.savePendingFriendCode(value);
      friendMessage = '친구 QR을 확인했어요. 로그인 후 친구 요청을 보낼 수 있어요.';
      notifyListeners();
      if (isAuthenticated) {
        await _consumePendingFriendActions();
      }
    }
  }

  Future<void> _consumePendingFriendActions() async {
    if (!isAuthenticated) return;

    final inviteToken = await _storageService.loadPendingInviteToken();
    if (inviteToken != null) {
      try {
        final friendship = await _repository.claimFriendInvite(inviteToken);
        friendMessage = '${friendship.user.nickname}님과 친구가 되었어요.';
        await _storageService.clearPendingInviteToken();
        await loadFriends(silent: true);
      } catch (error) {
        friendMessage = _message(error);
      }
    }

    final routeInviteToken =
        await _storageService.loadPendingRouteInviteToken();

    if (routeInviteToken != null) {
      try {
        final claimed =
            await _repository.claimRouteCompanionInvite(routeInviteToken);
        sharedRoute = claimed;
        routePlan = claimed.route;
        _cacheRoutePlaces(routePlan);
        sharedRouteMessage = '동행 코스에 참여했어요. 같은 코스를 함께 확인하고 수정할 수 있어요.';
        await _storageService.clearPendingRouteInviteToken();
        await loadFriends(silent: true);
      } catch (error) {
        sharedRouteMessage = _message(error);
      }
    }

    final friendCode = await _storageService.loadPendingFriendCode();
    if (friendCode != null) {
      try {
        final friendship = await _repository.requestFriendByCode(friendCode);
        friendMessage = friendship.isAccepted
            ? '${friendship.user.nickname}님과 친구가 되었어요.'
            : '${friendship.user.nickname}님께 친구 요청을 보냈어요.';
        await _storageService.clearPendingFriendCode();
        await loadFriends(silent: true);
      } catch (error) {
        friendMessage = _message(error);
      }
    }

    notifyListeners();
  }

  Future<void> loadFriends({bool silent = false}) async {
    if (!isAuthenticated || isLoadingFriends) return;
    isLoadingFriends = true;
    if (!silent) notifyListeners();
    try {
      final result = await _repository.getFriends();
      friends = result.friends;
      incomingFriendRequests = result.incoming;
      outgoingFriendRequests = result.outgoing;
    } catch (error) {
      friendMessage = _message(error);
    } finally {
      isLoadingFriends = false;
      notifyListeners();
    }
  }

  Future<bool> requestFriendByCode(String memberCode) async {
    final normalized = memberCode.trim().toUpperCase();
    if (normalized.isEmpty) return false;
    friendMessage = null;
    try {
      final friendship = await _repository.requestFriendByCode(normalized);
      friendMessage = friendship.isAccepted
          ? '${friendship.user.nickname}님과 친구가 되었어요.'
          : '${friendship.user.nickname}님께 친구 요청을 보냈어요.';
      await loadFriends(silent: true);
      return true;
    } catch (error) {
      friendMessage = _message(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> acceptFriend(String friendshipId) async {
    try {
      final friendship = await _repository.acceptFriend(friendshipId);
      friendMessage = '${friendship.user.nickname}님과 친구가 되었어요.';
      await loadFriends(silent: true);
    } catch (error) {
      friendMessage = _message(error);
      notifyListeners();
    }
  }

  Future<void> removeFriend(String friendshipId) async {
    try {
      await _repository.removeFriend(friendshipId);
      friendMessage = '친구 관계를 정리했어요.';
      await loadFriends(silent: true);
    } catch (error) {
      friendMessage = _message(error);
      notifyListeners();
    }
  }

  Future<FriendInvite?> createFriendInvite() async {
    try {
      final invite = await _repository.createFriendInvite();
      lastFriendInvite = invite;
      notifyListeners();
      return invite;
    } catch (error) {
      friendMessage = _message(error);
      notifyListeners();
      return null;
    }
  }

  void clearFriendMessage() {
    friendMessage = null;
    notifyListeners();
  }

  Future<void> refreshNotifications({bool silent = false}) async {
    if (!isAuthenticated) {
      serverNotifications = const [];
      _serverUnreadNotificationCount = 0;
      _pendingRouteCompanionRequestIds = <String>{};
      if (!silent) notifyListeners();
      return;
    }

    try {
      final feed = await _repository.getNotifications(limit: 100);
      serverNotifications = feed.items;
      _serverUnreadNotificationCount = feed.unreadCount;

      // 처리 완료된 친구/동행 요청에 수락·거절 버튼이 다시 보이지 않도록
      // 현재 pending 요청 목록도 함께 동기화합니다.
      try {
        final friendList = await _repository.getFriends();
        friends = friendList.friends;
        incomingFriendRequests = friendList.incoming;
        outgoingFriendRequests = friendList.outgoing;
      } catch (_) {}

      try {
        final pending = await _repository.getIncomingRouteCompanionRequests();
        _pendingRouteCompanionRequestIds =
            pending.where((item) => item.isPending).map((item) => item.requestId).toSet();
      } catch (_) {}
    } catch (error) {
      if (!silent) globalError = _message(error);
    } finally {
      if (!silent) notifyListeners();
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (!isAuthenticated || notificationId.trim().isEmpty) return;

    try {
      final updated = await _repository.markNotificationRead(notificationId);
      serverNotifications = serverNotifications
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      _serverUnreadNotificationCount = serverNotifications
          .where((item) => !item.isRead)
          .length;
      notifyListeners();
    } catch (error) {
      globalError = _message(error);
      notifyListeners();
    }
  }

  Future<void> markAllNotificationsRead() async {
    if (!isAuthenticated) return;

    try {
      await _repository.markAllNotificationsRead();
      serverNotifications = serverNotifications
          .map((item) => item.copyWith(isRead: true))
          .toList();
      _serverUnreadNotificationCount = 0;
      notifyListeners();
    } catch (error) {
      globalError = _message(error);
      notifyListeners();
    }
  }

  Future<bool> acceptRouteCompanionNotification(
    AppNotificationItem notification,
  ) async {
    final requestId = notification.routeRequestId?.trim() ?? '';
    if (requestId.isEmpty) {
      sharedRouteMessage = '동행 요청 정보를 확인할 수 없어요.';
      notifyListeners();
      return false;
    }

    isSharingRoute = true;
    notifyListeners();

    try {
      await _repository.acceptRouteCompanionRequest(requestId);
      _pendingRouteCompanionRequestIds.remove(requestId);

      final sharedRouteId = notification.sharedRouteId?.trim();
      if (sharedRouteId != null && sharedRouteId.isNotEmpty) {
        try {
          final latest = await _repository.getSharedRoute(sharedRouteId);
          sharedRoute = latest;
          routePlan = latest.route;
          _cacheRoutePlaces(routePlan);
        } catch (_) {
          // 수락 자체가 성공했다면 화면 갱신 실패 때문에 요청 처리를 되돌리지 않습니다.
        }
      }

      await loadRouteLibrary(silent: true);
      await markNotificationRead(notification.id);
      sharedRouteMessage =
          '${notification.actor?.nickname ?? '친구'}님의 동행 요청을 수락했어요.';
      return true;
    } catch (error) {
      sharedRouteMessage = _message(error);
      return false;
    } finally {
      isSharingRoute = false;
      notifyListeners();
    }
  }

  Future<bool> rejectRouteCompanionNotification(
    AppNotificationItem notification,
  ) async {
    final requestId = notification.routeRequestId?.trim() ?? '';
    if (requestId.isEmpty) {
      sharedRouteMessage = '동행 요청 정보를 확인할 수 없어요.';
      notifyListeners();
      return false;
    }

    try {
      await _repository.rejectRouteCompanionRequest(requestId);
      _pendingRouteCompanionRequestIds.remove(requestId);
      await markNotificationRead(notification.id);
      sharedRouteMessage =
          '${notification.actor?.nickname ?? '친구'}님의 동행 요청을 거절했어요.';
      return true;
    } catch (error) {
      sharedRouteMessage = _message(error);
      notifyListeners();
      return false;
    }
  }

  CommunityPost? communityPostById(String postId) {
    for (final post in communityPosts) {
      if (post.postId == postId) return post;
    }
    return null;
  }



  void prepareCommunityCourseReview(CompletedTrip trip) {
    pendingCommunityCourseReview = trip;
    notifyListeners();
  }

  void clearPendingCommunityCourseReview() {
    pendingCommunityCourseReview = null;
    notifyListeners();
  }

  Future<void> loadCommunityPosts({
    CommunityPostType? postType,
    String? sort,
    bool silent = false,
  }) async {
    if (!isAuthenticated) {
      communityPosts = const [];
      return;
    }

    communityFilter = postType;
    if (sort != null) communitySort = sort;
    communityError = null;
    if (!silent) {
      isLoadingCommunity = true;
      notifyListeners();
    }

    try {
      communityPosts = await _repository.getCommunityPosts(
        postType: communityFilter,
        sort: communitySort,
      );
    } catch (error) {
      communityError = _message(error);
    } finally {
      if (!silent) {
        isLoadingCommunity = false;
        notifyListeners();
      }
    }
  }

  Future<CommunityPost?> createCommunityPost(Map<String, dynamic> payload) async {
    communityError = null;
    try {
      final post = await _repository.createCommunityPost(payload);
      communityPosts = [
        post,
        ...communityPosts.where((item) => item.postId != post.postId),
      ];
      if (post.postType == CommunityPostType.course) {
        pendingCommunityCourseReview = null;
      }
      notifyListeners();
      return post;
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
      return null;
    }
  }

  Future<bool> reportCommunityPost(CommunityPost post, String reason) async {
    communityError = null;
    try {
      await _repository.reportCommunityPost(postId: post.postId, reason: reason);
      return true;
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
      return false;
    }
  }

  Future<bool> hideCommunityPost(CommunityPost post) async {
    communityError = null;
    try {
      await _repository.hideCommunityPost(post.postId);
      communityPosts = communityPosts.where((item) => item.postId != post.postId).toList();
      notifyListeners();
      return true;
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleCommunityRecommendation(CommunityPost post) async {
    final target = !post.recommendedByMe;
    try {
      final result = await _repository.toggleCommunityRecommendation(
        postId: post.postId,
        recommend: target,
      );
      final count = int.tryParse(result['recommendation_count']?.toString() ?? '') ??
          (post.recommendationCount + (target ? 1 : -1)).clamp(0, 1 << 30).toInt();
      final updated = post.copyWith(
        recommendedByMe: result['recommended'] == true,
        recommendationCount: count,
      );
      _replaceCommunityPost(updated);
      if (updated.author.userId == currentUser?.id) {
      }
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
    }
  }

  Future<List<CommunityComment>> loadCommunityComments(String postId) async {
    try {
      return await _repository.getCommunityComments(postId);
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
      return const [];
    }
  }

  Future<CommunityComment?> addCommunityComment({
    required CommunityPost post,
    required String content,
  }) async {
    try {
      final comment = await _repository.createCommunityComment(
        postId: post.postId,
        content: content,
      );
      final updated = post.copyWith(commentCount: post.commentCount + 1);
      _replaceCommunityPost(updated);
      if (updated.author.userId == currentUser?.id) {
      }
      return comment;
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
      return null;
    }
  }

  Future<void> toggleCommunityCourseSaved(CommunityPost post) async {
    if (post.postType != CommunityPostType.course) return;
    final nextSaved = !post.courseSavedByMe;
    try {
      await _repository.setCommunityCourseSaved(
        postId: post.postId,
        saved: nextSaved,
      );

      final route = _communityRouteFromPost(post);
      if (route != null) {
        if (nextSaved) {
          savedRoutes = [
            route,
            ...savedRoutes.where((item) => item.id != route.id),
          ];
        } else {
          savedRoutes = savedRoutes.where((item) => item.id != route.id).toList();
        }
        await _storageService.saveRoutes(
          _requireUserStorageId(),
          savedRoutes,
        );
      }

      _replaceCommunityPost(post.copyWith(courseSavedByMe: nextSaved));
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
    }
  }

  Future<bool> followCommunityCourse(CommunityPost post) async {
    if (post.postType != CommunityPostType.course) return false;
    communityError = null;

    try {
      final seed = await _repository.getCommunityCourseCopy(post.postId);
      final snapshotRoute = RoutePlan.fromJson(seed.courseSnapshot);

      if (snapshotRoute.stops.isEmpty) {
        throw const ApiException('이 후기의 코스 정보를 확인할 수 없어요.');
      }

      // 가능하면 버튼을 누른 시점의 실제 위치를 다시 받아 현재 상황으로 재추천합니다.
      try {
        currentPosition = await _locationService.determinePosition();
      } catch (_) {
        // 위치 권한이 없으면 마지막으로 알고 있던 좌표를 사용합니다.
      }

      final patchRequired = seed.sameCourseRequestPatch['required_place_names'];
      final requiredNames = patchRequired is List
          ? patchRequired.map((value) => value.toString().trim()).where((value) => value.isNotEmpty).toList()
          : seed.sourcePlaceNames;

      final attractionCategories = snapshotRoute.stops
          .map((stop) => stop.place.category.trim())
          .where((value) => value.isNotEmpty && value != '맛집' && value != '카페' && value != '음식점')
          .toSet()
          .toList();

      final categories = <String>[
        ...attractionCategories,
        if (seed.includeFood) '맛집',
        if (seed.includeCafe) '카페',
      ];

      final availableMinutes = seed.suggestedAvailableMinutes ?? snapshotRoute.totalMinutes;
      final preferences = RoutePreferences(
        startLatitude: latitude,
        startLongitude: longitude,
        availableHours: (availableMinutes / 60).clamp(1, 12).toDouble(),
        transportType: lastPreferences?.transportType ?? 'walking',
        // UI에서는 탐색 반경을 사용하지 않으며, 백엔드도 하드필터로 사용하지 않습니다.
        radiusKm: 30,
        preferredCategories: categories,
        avoidPaid: lastPreferences?.avoidPaid ?? false,
        weatherAware: true,
        includeRestStops: true,
        expectedInclude: requiredNames.join(', '),
        expectedExclude: '',
        memo: '커뮤니티 코스를 현재 혼잡도와 현장 제보를 반영해 다시 추천',
        visitedPlaceIds: visitedPlaceIds.toList(),
      );

      RoutePlan route;
      try {
        // 이 호출에서 V2.4.4 + 최근 커뮤니티 현장 제보(routing congestion)를 다시 계산합니다.
        route = await _repository.recommendRoute(preferences);
        routeMessage =
            '다른 여행자의 코스를 최신 혼잡도와 현장 제보를 반영해 다시 추천했어요.';
      } catch (_) {
        // 외부 API 장애 등으로 재계산이 실패해도 게시 당시 코스는 확인할 수 있게 둡니다.
        route = RoutePlan(
          id: 'community_${post.postId}',
          title: snapshotRoute.title,
          summary: snapshotRoute.summary,
          totalMinutes: snapshotRoute.totalMinutes,
          totalDistanceKm: snapshotRoute.totalDistanceKm,
          averageQuietScore: snapshotRoute.averageQuietScore,
          stops: snapshotRoute.stops,
          updatedAt: DateTime.now(),
          weatherSummary: snapshotRoute.weatherSummary,
        );
        routeMessage =
            '현재 상황 재계산에 실패해 게시 당시 코스를 불러왔어요. 출발 전에 새로고침해 주세요.';
      }

      routePlan = route;
      sharedRoute = null;
      tripActive = false;
      tripJustCompleted = false;
      currentStopIndex = 0;
      lastPreferences = preferences;
      _cacheRoutePlaces(route);
      notifyListeners();
      return true;
    } catch (error) {
      communityError = _message(error);
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> getCommunityLiveSummary(String placeId) async {
    try {
      return await _repository.getCommunityLiveSummary(placeId);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  RoutePlan? _communityRouteFromPost(CommunityPost post) {
    final snapshot = post.courseSnapshot;
    if (snapshot == null || snapshot.isEmpty) return null;
    try {
      final raw = RoutePlan.fromJson(snapshot);
      if (raw.stops.isEmpty) return null;
      return RoutePlan(
        id: 'community_${post.postId}',
        title: raw.title,
        summary: raw.summary,
        totalMinutes: raw.totalMinutes,
        totalDistanceKm: raw.totalDistanceKm,
        averageQuietScore: raw.averageQuietScore,
        stops: raw.stops,
        updatedAt: DateTime.now(),
        weatherSummary: raw.weatherSummary,
      );
    } catch (_) {
      return null;
    }
  }

  void _replaceCommunityPost(CommunityPost updated) {
    communityPosts = communityPosts
        .map((post) => post.postId == updated.postId ? updated : post)
        .toList();
    notifyListeners();
  }

  Future<void> loadRouteLibrary({
    bool silent = false,
  }) async {
    if (!isAuthenticated) {
      sharedRoutes = const [];
      return;
    }

    if (!silent) {
      isLoadingRouteLibrary = true;
      notifyListeners();
    }

    try {
      sharedRoutes = await _repository.listSharedRoutes();

      for (final shared in sharedRoutes) {
        _cacheRoutePlaces(shared.route);
      }
    } catch (error) {
      if (!silent) {
        routeMessage = _message(error);
      }
    } finally {
      if (!silent) {
        isLoadingRouteLibrary = false;
        notifyListeners();
      }
    }
  }

  bool isRouteSaved(String routeId) {
    return savedRoutes.any((route) => route.id == routeId);
  }

  Future<void> toggleSaveCurrentRoute() async {
    final current = routePlan;
    if (current == null) return;

    if (isRouteSaved(current.id)) {
      savedRoutes = savedRoutes
          .where((route) => route.id != current.id)
          .toList();
      routeMessage = '저장한 코스에서 삭제했어요.';
    } else {
      savedRoutes = [
        current.copyWith(updatedAt: DateTime.now()),
        ...savedRoutes.where((route) => route.id != current.id),
      ];
      routeMessage = '코스를 저장했어요.';
    }

    await _storageService.saveRoutes(
          _requireUserStorageId(),
          savedRoutes,
        );
    notifyListeners();
  }

  Future<void> removeSavedRoute(String routeId) async {
    savedRoutes = savedRoutes
        .where((route) => route.id != routeId)
        .toList();

    await _storageService.saveRoutes(
          _requireUserStorageId(),
          savedRoutes,
        );
    notifyListeners();
  }

  void openSavedRoute(RoutePlan route) {
    routePlan = route;
    sharedRoute = null;
    lastPreferences = null;
    tripActive = false;
    tripJustCompleted = false;
    currentStopIndex = 0;
    _cacheRoutePlaces(route);
    routeMessage = '저장한 코스를 열었어요.';
    notifyListeners();
  }

  void openSharedRoute(SharedRoute shared) {
    sharedRoute = shared;
    routePlan = shared.route;
    lastPreferences = null;
    tripActive = false;
    tripJustCompleted = false;
    currentStopIndex = 0;
    _cacheRoutePlaces(shared.route);
    routeMessage = '동행 코스를 열었어요.';
    notifyListeners();
  }



  Future<SharedRoute?> ensureSharedRoute() async {
    final current = routePlan;
    if (current == null || !isAuthenticated) return null;
    if (isSharingRoute) return sharedRoute;

    isSharingRoute = true;
    sharedRouteMessage = null;
    notifyListeners();

    try {
      if (sharedRoute == null) {
        sharedRoute = await _repository.createSharedRoute(current);
      } else {
        sharedRoute = await _repository.updateSharedRoute(
          shared: sharedRoute!,
          route: current,
        );
      }
      final currentShared = sharedRoute;
      if (currentShared != null) {
        sharedRoutes = [
          currentShared,
          ...sharedRoutes.where(
            (item) => item.id != currentShared.id,
          ),
        ];
      }

      return sharedRoute;
    } catch (error) {
      sharedRouteMessage = _message(error);
      return null;
    } finally {
      isSharingRoute = false;
      notifyListeners();
    }
  }

  Future<bool> addCompanionByCode(String memberCode) async {
    final normalized = memberCode.trim().toUpperCase();
    if (normalized.isEmpty) return false;

    Friendship? acceptedFriend;
    for (final friendship in friends) {
      if (friendship.isAccepted &&
          friendship.user.memberCode.toUpperCase() == normalized) {
        acceptedFriend = friendship;
        break;
      }
    }

    if (acceptedFriend == null) {
      final requested = await requestFriendByCode(normalized);
      sharedRouteMessage = requested
          ? '친구 요청을 보냈어요. 상대가 수락한 뒤 동행 요청을 보내주세요.'
          : friendMessage;
      notifyListeners();
      return false;
    }

    return _sendCompanionRequestToFriend(acceptedFriend);
  }

  Future<bool> addCompanionFriend(Friendship friendship) {
    return _sendCompanionRequestToFriend(friendship);
  }

  Future<bool> _sendCompanionRequestToFriend(Friendship friendship) async {
    if (!friendship.isAccepted) {
      sharedRouteMessage = '친구가 된 사용자에게만 동행 요청을 보낼 수 있어요.';
      notifyListeners();
      return false;
    }

    final shared = await ensureSharedRoute();
    if (shared == null) return false;

    isSharingRoute = true;
    notifyListeners();
    try {
      await _repository.requestRouteCompanion(
        sharedRouteId: shared.id,
        memberCode: friendship.user.memberCode,
      );
      sharedRouteMessage =
          '${friendship.user.nickname}님에게 동행 요청을 보냈어요.';
      return true;
    } catch (error) {
      sharedRouteMessage = _message(error);
      return false;
    } finally {
      isSharingRoute = false;
      notifyListeners();
    }
  }

  Future<void> removeCompanion(String membershipId) async {
    final shared = sharedRoute;
    if (shared == null) return;

    isSharingRoute = true;
    notifyListeners();
    try {
      sharedRoute = await _repository.removeSharedRouteMember(
        sharedRouteId: shared.id,
        membershipId: membershipId,
      );
      sharedRouteMessage = '동행을 코스에서 제외했어요.';
    } catch (error) {
      sharedRouteMessage = _message(error);
    } finally {
      isSharingRoute = false;
      notifyListeners();
    }
  }

  Future<RouteCompanionInvite?> createRouteCompanionInvite() async {
    final shared = await ensureSharedRoute();
    if (shared == null) return null;

    isSharingRoute = true;
    notifyListeners();
    try {
      final invite = await _repository.createRouteCompanionInvite(shared.id);
      lastRouteCompanionInvite = invite;
      return invite;
    } catch (error) {
      sharedRouteMessage = _message(error);
      return null;
    } finally {
      isSharingRoute = false;
      notifyListeners();
    }
  }

  Future<void> reloadSharedRoute() async {
    final shared = sharedRoute;
    if (shared == null || isSharingRoute) return;

    isSharingRoute = true;
    notifyListeners();
    try {
      final latest = await _repository.getSharedRoute(shared.id);
      sharedRoute = latest;
      routePlan = latest.route;
      _cacheRoutePlaces(routePlan);
      sharedRouteMessage = '동행이 수정한 최신 코스를 불러왔어요.';
    } catch (error) {
      sharedRouteMessage = _message(error);
    } finally {
      isSharingRoute = false;
      notifyListeners();
    }
  }

  Future<void> _syncSharedRouteIfNeeded() async {
    final shared = sharedRoute;
    final current = routePlan;
    if (shared == null || current == null) return;

    try {
      sharedRoute = await _repository.updateSharedRoute(
        shared: shared,
        route: current,
      );
    } catch (error) {
      sharedRouteMessage = _message(error);
    }
  }

  void clearSharedRouteMessage() {
    sharedRouteMessage = null;
    notifyListeners();
  }


  Future<List<Place>> searchPlacesForMap(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return const [];

    try {
      final fetched = await _repository.searchPlacesForMap(query);
      final results = fetched.map(_withCurrentDistance).toList();
      for (final place in results) {
        _placeCache[place.id] = place;
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<void> loadPlaces({String? query, String? category}) async {
    isLoadingPlaces = true;
    globalError = null;
    if (query != null) searchQuery = query;
    if (category != null) selectedCategory = category;
    notifyListeners();

    try {
      final position = currentPosition;
      places = await _repository.getPlaces(
        query: searchQuery,
        category: selectedCategory,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      places = [...places]..sort((a, b) => b.quietScore.compareTo(a.quietScore));
      for (final place in places) {
        _placeCache[place.id] = place;
      }
      _hydratePlaceCardsInBackground(
        places
            .where((place) => const {'12', '14', '25', '28'}.contains(place.contentTypeId) ||
                (place.contentTypeId.isEmpty &&
                    place.category != '맛집' &&
                    place.category != '카페' &&
                    place.category != '음식점'))
            .take(4)
            .toList(),
      );
    } catch (error) {
      globalError = _message(error);
    } finally {
      isLoadingPlaces = false;
      notifyListeners();
    }
  }

  void _hydratePlaceCardsInBackground(List<Place> seeds) {
    // 홈 카드의 운영시간/공식 홈페이지/관련 콘텐츠를 초기 목록 표시 후
    // 백그라운드에서 보완합니다. 첫 화면 렌더링은 막지 않습니다.
    Future<void>(() async {
      for (final seed in seeds) {
        try {
          final core = await _repository.getPlaceDetail(seed);
          final fetched = await _repository.getPlaceDetailExtras(core);
          final full = _withCurrentDistance(fetched);
          _placeDetailCoreCache[seed.id] = full;
          _placeDetailFullCache[seed.id] = full;
          _placeCache[seed.id] = full;
          places = places
              .map((item) => item.id == seed.id ? full : item)
              .toList();
          notifyListeners();
        } catch (_) {
          // 카드 보완 실패는 홈 목록 자체를 막지 않습니다.
        }
      }
    });
  }

  Place _withCurrentDistance(Place place) {
    final position = currentPosition;
    if (position == null) {
      return place.copyWith(hasLocalDistance: false);
    }

    return place.copyWith(
      distanceKm: Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            place.latitude,
            place.longitude,
          ) /
          1000,
      hasLocalDistance: true,
    );
  }

  void _recalculatePlaceDistancesInMemory() {
    if (currentPosition == null) return;

    places = places.map(_withCurrentDistance).toList();

    for (final entry in _placeCache.entries.toList()) {
      _placeCache[entry.key] = _withCurrentDistance(entry.value);
    }
    for (final entry in _placeDetailCoreCache.entries.toList()) {
      _placeDetailCoreCache[entry.key] = _withCurrentDistance(entry.value);
    }
    for (final entry in _placeDetailFullCache.entries.toList()) {
      _placeDetailFullCache[entry.key] = _withCurrentDistance(entry.value);
    }
  }

  /// 홈 장소카드용 현재 위치 갱신.
  ///
  /// 위치는 [currentPosition] 메모리에만 유지하고, 백엔드 API/DB/
  /// SharedPreferences 등 영구 저장소로 전송·저장하지 않습니다.
  Future<void> refreshPlaceDistancesFromDevice() async {
    try {
      currentPosition = await _locationService.determinePosition();
      _recalculatePlaceDistancesInMemory();
      notifyListeners();
    } catch (_) {
      // 권한 거부/서비스 꺼짐이면 0.0km를 만들지 않고 거리 표시를 숨깁니다.
      notifyListeners();
    }
  }

  Future<String> useCurrentLocation() async {
    try {
      currentPosition = await _locationService.determinePosition();
      _recalculatePlaceDistancesInMemory();
      notifyListeners();
      await loadNearbyPlaces();
      return '현재 위치를 반영했어요.';
    } catch (error) {
      return _message(error);
    }
  }

  Future<void> loadNearbyPlaces({double radiusKm = 15}) async {
    isLoadingPlaces = true;
    globalError = null;
    notifyListeners();
    try {
      final position = currentPosition;
      if (position == null) {
        await loadPlaces();
        return;
      }

      places = await _repository.getNearbyPlaces(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: radiusKm,
      );
      places = [...places]..sort((a, b) => b.quietScore.compareTo(a.quietScore));
      for (final place in places) {
        _placeCache[place.id] = place;
      }
    } catch (error) {
      globalError = _message(error);
    } finally {
      isLoadingPlaces = false;
      notifyListeners();
    }
  }

  Future<Place?> fetchNearestTouristAt({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final place =
          await _repository.getNearestTourist(
        latitude: latitude,
        longitude: longitude,
      );

      if (place != null) {
        _placeCache[
          place.id
        ] = place;
      }

      return place;
    } catch (_) {
      return null;
    }
  }

  Future<List<Place>> fetchPlacesAt({
    required double latitude,
    required double longitude,
    double radiusKm = 15,
  }) async {
    final result = await _repository.getNearbyPlaces(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
    );

    final sorted = [...result]
      ..sort((a, b) => b.quietScore.compareTo(a.quietScore));

    for (final place in sorted) {
      _placeCache[place.id] = place;
    }

    return sorted;
  }


  /// Kakao Maps가 반환한 실제 장소명과 같은 앱 장소카드를 찾습니다.
  ///
  /// 중요:
  /// - [places]를 통째로 교체하지 않습니다.
  /// - 현재 화면/캐시에 이미 있는 장소를 먼저 확인합니다.
  /// - 없을 때만 백엔드 장소 검색을 사용합니다.
  /// - 마지막에는 전체 관광지 목록에서도 같은 이름을 다시 확인합니다.
  /// - 사용자 현재 위치는 repository 내부에서 거리 계산에만 사용되고
  ///   백엔드 query/body/header로 전송되지 않습니다.
  Future<Place?> findPlaceCardByName(
    String placeName, {
    String originalQuery = '',
  }) async {
    String normalize(String value) => value
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^0-9a-z가-힣]'), '');

    final target = normalize(placeName);
    final queryTarget = normalize(originalQuery);

    Place? pickExact(Iterable<Place> source) {
      for (final place in source) {
        if (normalize(place.name) == target) {
          return place;
        }
      }

      // Kakao 장소명에 지점/괄호 표기가 붙는 경우를 위한 보조 매칭.
      for (final place in source) {
        final name = normalize(place.name);
        if (name.isEmpty) continue;

        if (name.contains(target) || target.contains(name)) {
          return place;
        }
      }

      // 사용자가 입력한 원래 검색어와 앱 카드명이 정확히 같은 경우.
      if (queryTarget.isNotEmpty) {
        for (final place in source) {
          if (normalize(place.name) == queryTarget) {
            return place;
          }
        }
      }

      return null;
    }

    // 1) 현재 UI 목록 + 그동안 조회한 장소 캐시
    final memoryPool = <String, Place>{
      for (final place in places) place.id: place,
      for (final place in _placeCache.values) place.id: place,
    }.values;

    var matched = pickExact(memoryPool);
    if (matched != null) {
      return _withCurrentDistance(matched);
    }

    final position = currentPosition;

    // 2) Kakao가 반환한 실제 장소명으로 백엔드 검색
    Future<Place?> searchRepository(String query) async {
      if (query.trim().isEmpty) return null;

      try {
        final results = await _repository.getPlaces(
          query: query,
          category: '전체',
          latitude: position?.latitude,
          longitude: position?.longitude,
        );

        for (final place in results) {
          _placeCache[place.id] = place;
        }

        return pickExact(results);
      } catch (_) {
        return null;
      }
    }

    matched = await searchRepository(placeName);
    if (matched != null) {
      return _withCurrentDistance(matched);
    }

    // 3) Kakao 이름과 사용자가 입력한 이름이 다르면 원 검색어로 한 번 더 확인
    if (queryTarget.isNotEmpty && queryTarget != target) {
      matched = await searchRepository(originalQuery);
      if (matched != null) {
        return _withCurrentDistance(matched);
      }
    }

    // 4) 검색 API가 이름 필터를 제대로 반환하지 않는 경우를 대비해
    //    전체 관광지 목록에서도 같은 이름을 마지막으로 확인합니다.
    try {
      final allPlaces = await _repository.getPlaces(
        category: '전체',
        latitude: position?.latitude,
        longitude: position?.longitude,
      );

      for (final place in allPlaces) {
        _placeCache[place.id] = place;
      }

      matched = pickExact(allPlaces);
      if (matched != null) {
        return _withCurrentDistance(matched);
      }
    } catch (_) {
      // 아래 null 반환
    }

    return null;
  }

  Future<void> toggleSaved(Place place) async {
    _placeCache[place.id] = place;
    if (savedPlaceIds.contains(place.id)) {
      savedPlaceIds.remove(place.id);
    } else {
      savedPlaceIds.add(place.id);
      if (!places.any((item) => item.id == place.id)) {
        places = [...places, place];
      }
    }
    notifyListeners();
    await _storageService.savePlaceIds(
      _requireUserStorageId(),
      savedPlaceIds,
    );
  }

  bool isSaved(String placeId) => savedPlaceIds.contains(placeId);
  bool isVisited(String placeId) => visitedPlaceIds.contains(placeId);

  Future<Place> fetchPlaceDetail(
    Place place,
  ) async {
    final full =
        _placeDetailFullCache[place.id];

    if (full != null) {
      return full;
    }

    final cached =
        _placeDetailCoreCache[place.id];

    if (cached != null) {
      return cached;
    }

    final fetched =
        await _repository.getPlaceDetail(
      place,
    );
    final detail = _withCurrentDistance(fetched);

    _placeDetailCoreCache[place.id] =
        detail;

    _placeCache[detail.id] = detail;
    places = places.map((item) => item.id == detail.id ? detail : item).toList();

    return detail;
  }

  Future<Place> fetchPlaceDetailExtras(
    Place place,
  ) async {
    final cached =
        _placeDetailFullCache[place.id];

    if (cached != null) {
      return cached;
    }

    final fetched =
        await _repository
            .getPlaceDetailExtras(
      place,
    );
    final detail = _withCurrentDistance(fetched);

    _placeDetailCoreCache[place.id] =
        detail;

    _placeDetailFullCache[place.id] =
        detail;

    _placeCache[detail.id] = detail;
    places = places.map((item) => item.id == detail.id ? detail : item).toList();
    notifyListeners();

    return detail;
  }

  Future<void> buildRoute(RoutePreferences preferences) async {
    if (isBuildingRoute) return;
    final requestPreferences = preferences.copyWith(
      visitedPlaceIds: visitedPlaceIds.toList(),
    );
    isBuildingRoute = true;
    routeMessage = null;
    lastPreferences = requestPreferences;
    notifyListeners();
    try {
      routePlan = await _repository.recommendRoute(requestPreferences);
      _cacheRoutePlaces(routePlan);
      sharedRoute = null;
      lastRouteCompanionInvite = null;
      sharedRouteMessage = null;
      tripActive = false;
      tripJustCompleted = false;
      lastCompletedTrip = null;
      currentStopIndex = 0;
      routeMessage = '조건에 맞는 한적한 코스를 만들었어요.';
    } catch (error) {
      routeMessage = _message(error);
    } finally {
      isBuildingRoute = false;
      notifyListeners();
    }
  }

  Future<void> refreshRoute({String reason = 'manual_refresh'}) async {
    final current = routePlan;
    final preferences = lastPreferences;
    if (current == null || preferences == null || isUpdatingRoute) return;

    final refreshedPreferences = preferences.copyWith(
      visitedPlaceIds: visitedPlaceIds.toList(),
    );
    lastPreferences = refreshedPreferences;
    isUpdatingRoute = true;
    routeMessage = null;
    notifyListeners();
    try {
      routePlan = await _repository.refreshRoute(
        current: current,
        preferences: refreshedPreferences,
        reason: reason,
      );
      _cacheRoutePlaces(routePlan);
      currentStopIndex = 0;
      await _syncSharedRouteIfNeeded();
      routeMessage = '현재 혼잡도와 이동 조건을 반영해 코스를 다시 만들었어요.';
    } catch (error) {
      routeMessage = _message(error);
    } finally {
      isUpdatingRoute = false;
      notifyListeners();
    }
  }

  Future<void> replaceRouteStop(
    RouteStop stop,
  ) async {
    final current = routePlan;

    if (
      current == null ||
      isUpdatingRoute
    ) {
      return;
    }

    final oldName = stop.place.name;

    isUpdatingRoute = true;
    routeMessage = '$oldName 대신 갈 곳을 찾고 있어요.';
    notifyListeners();

    try {
      final updated = await _repository.replaceRouteStop(
        current: current,
        stop: stop,
        transportType:
            lastPreferences?.transportType ?? 'walking',
      );

      routePlan = updated;
      _cacheRoutePlaces(routePlan);
      currentStopIndex = 0;

      await _syncSharedRouteIfNeeded();

      RouteStop? replaced;

      if (
        stop.order > 0 &&
        stop.order <= updated.stops.length
      ) {
        replaced =
            updated.stops[stop.order - 1];
      }

      routeMessage = replaced == null
          ? '장소를 다른 추천 장소로 바꿨어요.'
          : '$oldName 대신 ${replaced.place.name}(으)로 바꿨어요.';
    } catch (error) {
      routeMessage = _message(error);
    } finally {
      isUpdatingRoute = false;
      notifyListeners();
    }
  }

  Future<void> modifyRoute(String message) async {
    final current = routePlan;
    if (current == null || message.trim().isEmpty || isUpdatingRoute) return;

    isUpdatingRoute = true;
    routeMessage = null;
    notifyListeners();
    try {
      final preferences = lastPreferences;

      if (preferences == null) {
        throw StateError(
          '현재 코스 조건을 찾지 못했습니다.',
        );
      }

      routePlan = await _repository.modifyRoute(
        current: current,
        message: message.trim(),
        preferences: preferences,
      );
      _cacheRoutePlaces(routePlan);
      currentStopIndex = 0;
      await _syncSharedRouteIfNeeded();
      routeMessage = '요청한 내용을 코스에 반영했어요.';
    } catch (error) {
      routeMessage = _message(error);
    } finally {
      isUpdatingRoute = false;
      notifyListeners();
    }
  }

  void startTrip() {
    final route = routePlan;
    if (route == null) return;
    if (route.stops.isEmpty) {
      routeMessage = '여행을 시작할 장소가 없어요. 코스를 다시 만들어주세요.';
      notifyListeners();
      return;
    }
    tripActive = true;
    tripJustCompleted = false;
    currentStopIndex = 0;
    lastCongestionCheck = DateTime.now();
    _startCongestionTimer();
    notifyListeners();
  }

  void stopTrip() {
    tripActive = false;
    _congestionTimer?.cancel();
    _congestionTimer = null;
    notifyListeners();
  }

  Future<void> completeCurrentStop() async {
    // Prevent a second tap (or a second async call) from recording
    // the same stop / completed route twice.
    if (isCompletingStop || !tripActive) return;

    final route = routePlan;
    if (route == null || route.stops.isEmpty) return;

    isCompletingStop = true;
    notifyListeners();

    final stop =
        route.stops[
          currentStopIndex
              .clamp(0, route.stops.length - 1)
              .toInt()
        ];

    try {
      await _repository.checkIn(stop.place.id);

      visitedPlaceIds.add(stop.place.id);
      await _storageService.saveVisitedPlaceIds(
        _requireUserStorageId(),
        visitedPlaceIds,
      );

      lastPreferences = lastPreferences?.copyWith(
        visitedPlaceIds: visitedPlaceIds.toList(),
      );

      if (currentStopIndex < route.stops.length - 1) {
        currentStopIndex += 1;
        routeMessage = '방문 완료! 다음 장소로 안내할게요.';
      } else {
        // Mark the trip inactive before persisting the completion record so
        // any later callback cannot complete the same trip again.
        tripActive = false;
        _congestionTimer?.cancel();
        _congestionTimer = null;

        final completedAt = DateTime.now();

        // Extra safety: if this route has already just been recorded,
        // do not append another completion entry.
        final alreadyRecorded =
            lastCompletedTrip?.route.id == route.id &&
            lastCompletedTrip != null &&
            completedAt.difference(lastCompletedTrip!.completedAt).abs() <
                const Duration(seconds: 5);

        if (!alreadyRecorded) {
          final completedTrip = CompletedTrip(
            id: '${route.id}_${completedAt.microsecondsSinceEpoch}',
            route: route,
            completedAt: completedAt,
          );

          completedTrips = [
            completedTrip,
            ...completedTrips,
          ];
          lastCompletedTrip = completedTrip;

          await _storageService.saveCompletedTrips(
            _requireUserStorageId(),
            completedTrips,
          );
        }

        tripJustCompleted = true;
        routeMessage = '오늘의 한적한 경주 여행을 완료했어요.';
      }
    } catch (error) {
      routeMessage = _message(error);
    } finally {
      isCompletingStop = false;
      notifyListeners();
    }
  }

  Future<void> recheckTripCongestion() async {
    final route = routePlan;
    if (!tripActive || route == null || route.stops.isEmpty || isUpdatingRoute) return;

    isUpdatingRoute = true;
    notifyListeners();
    try {
      final index = currentStopIndex.clamp(0, route.stops.length - 1).toInt();
      final currentStop = route.stops[index];
      final refreshed = await _repository.refreshPlaceCongestion(currentStop.place);
      _placeCache[refreshed.id] = refreshed;
      final updatedStops = [...route.stops];
      updatedStops[index] = RouteStop(
        order: currentStop.order,
        place: refreshed,
        arrivalTime: currentStop.arrivalTime,
        stayMinutes: currentStop.stayMinutes,
        travelMinutes: currentStop.travelMinutes,
        transportInstruction: currentStop.transportInstruction,
        isRestStop: currentStop.isRestStop,
      );
      routePlan = route.copyWith(stops: updatedStops, updatedAt: DateTime.now());
      lastCongestionCheck = DateTime.now();

      if (refreshed.congestionScoreValue > 8 && lastPreferences != null) {
        routeMessage = '${refreshed.name}의 혼잡도가 기준을 넘어서 대체 코스를 찾고 있어요.';
        notifyListeners();
        final refreshedPreferences = lastPreferences!.copyWith(
          visitedPlaceIds: visitedPlaceIds.toList(),
        );
        lastPreferences = refreshedPreferences;
        routePlan = await _repository.refreshRoute(
          current: routePlan!,
          preferences: refreshedPreferences,
          reason: 'congestion_over_8',
        );
        _cacheRoutePlaces(routePlan);
        currentStopIndex = 0;
        routeMessage = '혼잡한 장소를 제외한 대체 코스로 변경했어요.';
      } else {
        routeMessage = '현재 혼잡도를 다시 확인했어요.';
      }
    } catch (error) {
      routeMessage = _message(error);
    } finally {
      isUpdatingRoute = false;
      notifyListeners();
    }
  }

  Future<void> removeCompletedTrip(String tripId) async {
    final previous = completedTrips;

    completedTrips = completedTrips
        .where((trip) => trip.id != tripId)
        .toList();

    if (lastCompletedTrip?.id == tripId) {
      lastCompletedTrip = null;
      tripJustCompleted = false;
    }

    notifyListeners();

    try {
      await _storageService.saveCompletedTrips(
          _requireUserStorageId(),
          completedTrips,
        );
    } catch (error) {
      completedTrips = previous;
      globalError = _message(error);
      notifyListeners();
    }
  }

  void closeTripCompletion() {
    tripJustCompleted = false;
    lastCompletedTrip = null;
    tripActive = false;
    _congestionTimer?.cancel();
    _congestionTimer = null;
    routePlan = null;
    lastPreferences = null;
    routeMessage = null;
    currentStopIndex = 0;
    notifyListeners();
  }

  void clearRoute() {
    stopTrip();
    routePlan = null;
    sharedRoute = null;
    lastRouteCompanionInvite = null;
    sharedRouteMessage = null;
    lastPreferences = null;
    routeMessage = null;
    currentStopIndex = 0;
    notifyListeners();
  }

  void clearRouteMessage() {
    routeMessage = null;
    notifyListeners();
  }

  void _cacheRoutePlaces(RoutePlan? route) {
    if (route == null) return;
    for (final stop in route.stops) {
      _placeCache[stop.place.id] = stop.place;
    }
  }

  void _startCongestionTimer() {
    _congestionTimer?.cancel();
    _congestionTimer = Timer.periodic(
      Duration(minutes: AppEnv.congestionRefreshMinutes),
      (_) => recheckTripCongestion(),
    );
  }

  String _message(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  void dispose() {
    _congestionTimer?.cancel();
    _appLinkSubscription?.cancel();
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    required AppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppController of(BuildContext context, {bool listen = true}) {
    if (listen) {
      final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
      assert(scope != null, 'AppScope를 찾을 수 없습니다.');
      return scope!.notifier!;
    }
    final element = context.getElementForInheritedWidgetOfExactType<AppScope>();
    final scope = element?.widget as AppScope?;
    assert(scope != null, 'AppScope를 찾을 수 없습니다.');
    return scope!.notifier!;
  }
}
