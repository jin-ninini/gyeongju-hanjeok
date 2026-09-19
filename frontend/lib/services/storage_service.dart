import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/completed_trip.dart';
import '../models/route_plan.dart';

class StorageService {
  static const _savedPlacesKey =
      'gyeongju_hanjeok_saved_place_ids';

  static const _visitedPlacesKey =
      'gyeongju_hanjeok_visited_place_ids';

  static const _completedTripsKey =
      'gyeongju_hanjeok_completed_trips_v1';

  static const _savedRoutesKey =
      'gyeongju_hanjeok_saved_routes_v1';

  static const _authTokenKey =
      'gyeongju_hanjeok_auth_token_v1';

  static const _pendingInviteTokenKey =
      'gyeongju_hanjeok_pending_friend_invite_v1';

  static const _pendingFriendCodeKey =
      'gyeongju_hanjeok_pending_friend_code_v1';

  static const _pendingRouteInviteTokenKey =
      'gyeongju_hanjeok_pending_route_invite_v1';

  static String _userScopedKey(
    String baseKey,
    String userId,
  ) {
    final normalizedUserId = Uri.encodeComponent(
      userId.trim(),
    );
    return '${baseKey}_user_$normalizedUserId';
  }

  Future<String?> loadAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_authTokenKey)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Future<void> saveAuthToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_authTokenKey, token);
  }

  Future<void> clearAuthToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
  }

  Future<Set<String>> loadSavedPlaceIds(
    String userId,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    return (
      prefs.getStringList(
            _userScopedKey(
              _savedPlacesKey,
              userId,
            ),
          ) ??
          const <String>[]
    ).toSet();
  }

  Future<void> savePlaceIds(
    String userId,
    Set<String> ids,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final values = ids.toList()
      ..sort();

    await prefs.setStringList(
      _userScopedKey(
        _savedPlacesKey,
        userId,
      ),
      values,
    );
  }

  Future<Set<String>> loadVisitedPlaceIds(
    String userId,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    return (
      prefs.getStringList(
            _userScopedKey(
              _visitedPlacesKey,
              userId,
            ),
          ) ??
          const <String>[]
    ).toSet();
  }

  Future<void> saveVisitedPlaceIds(
    String userId,
    Set<String> ids,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final values = ids.toList()
      ..sort();

    await prefs.setStringList(
      _userScopedKey(
        _visitedPlacesKey,
        userId,
      ),
      values,
    );
  }

  Future<List<RoutePlan>> loadSavedRoutes(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(
      _userScopedKey(
        _savedRoutesKey,
        userId,
      ),
    );

    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final routes = decoded
          .whereType<Map>()
          .map(
            (item) => RoutePlan.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      routes.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );

      return routes;
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveRoutes(
    String userId,
    List<RoutePlan> routes,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _userScopedKey(
        _savedRoutesKey,
        userId,
      ),
      jsonEncode(
        routes
            .map((route) => route.toJson())
            .toList(),
      ),
    );
  }

  Future<List<CompletedTrip>>
      loadCompletedTrips(
    String userId,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final raw =
        prefs.getString(
          _userScopedKey(
            _completedTripsKey,
            userId,
          ),
        );

    if (raw == null ||
        raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded =
          jsonDecode(raw);

      if (decoded is! List) {
        return const [];
      }

      final result = decoded
          .whereType<Map>()
          .map(
            (item) =>
                CompletedTrip.fromJson(
                  Map<String, dynamic>.from(
                    item,
                  ),
                ),
          )
          .toList();

      result.sort(
        (a, b) =>
            b.completedAt.compareTo(
              a.completedAt,
            ),
      );

      return result;
    } catch (_) {
      // 손상된 로컬 데이터 때문에 앱 실행 자체가
      // 막히지 않도록 빈 목록으로 복구합니다.
      return const [];
    }
  }

  Future<void> saveCompletedTrips(
    String userId,
    List<CompletedTrip> trips,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    final encoded =
        jsonEncode(
          trips
              .map(
                (trip) =>
                    trip.toJson(),
              )
              .toList(),
        );

    await prefs.setString(
      _userScopedKey(
        _completedTripsKey,
        userId,
      ),
      encoded,
    );
  }

  Future<String?> loadPendingInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingInviteTokenKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> savePendingInviteToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteTokenKey, token.trim());
  }

  Future<void> clearPendingInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteTokenKey);
  }

  Future<String?> loadPendingRouteInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingRouteInviteTokenKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> savePendingRouteInviteToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingRouteInviteTokenKey, token.trim());
  }

  Future<void> clearPendingRouteInviteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingRouteInviteTokenKey);
  }


  Future<String?> loadPendingFriendCode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_pendingFriendCodeKey)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> savePendingFriendCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingFriendCodeKey, code.trim().toUpperCase());
  }

  Future<void> clearPendingFriendCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingFriendCodeKey);
  }
}
