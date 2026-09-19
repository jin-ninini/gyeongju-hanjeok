import 'place.dart';

class RoutePreferences {
  const RoutePreferences({
    required this.startLatitude,
    required this.startLongitude,
    required this.availableHours,
    required this.transportType,
    required this.radiusKm,
    required this.preferredCategories,
    required this.avoidPaid,
    required this.weatherAware,
    required this.includeRestStops,
    required this.expectedInclude,
    required this.expectedExclude,
    required this.memo,
    this.travelDate = '',
    this.startTime = '',
    this.visitedPlaceIds = const [],
  });

  final double startLatitude;
  final double startLongitude;
  final double availableHours;
  final String transportType;
  final double radiusKm;
  final List<String> preferredCategories;
  final bool avoidPaid;
  final bool weatherAware;
  final bool includeRestStops;
  final String expectedInclude;
  final String expectedExclude;
  final String memo;
  final String travelDate; // YYYY-MM-DD
  final String startTime;  // HH:mm
  final List<String> visitedPlaceIds;

  RoutePreferences copyWith({
    double? startLatitude,
    double? startLongitude,
    double? availableHours,
    String? transportType,
    double? radiusKm,
    List<String>? preferredCategories,
    bool? avoidPaid,
    bool? weatherAware,
    bool? includeRestStops,
    String? expectedInclude,
    String? expectedExclude,
    String? memo,
    String? travelDate,
    String? startTime,
    List<String>? visitedPlaceIds,
  }) {
    return RoutePreferences(
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      availableHours: availableHours ?? this.availableHours,
      transportType: transportType ?? this.transportType,
      radiusKm: radiusKm ?? this.radiusKm,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      avoidPaid: avoidPaid ?? this.avoidPaid,
      weatherAware: weatherAware ?? this.weatherAware,
      includeRestStops: includeRestStops ?? this.includeRestStops,
      expectedInclude: expectedInclude ?? this.expectedInclude,
      expectedExclude: expectedExclude ?? this.expectedExclude,
      memo: memo ?? this.memo,
      travelDate: travelDate ?? this.travelDate,
      startTime: startTime ?? this.startTime,
      visitedPlaceIds: visitedPlaceIds ?? this.visitedPlaceIds,
    );
  }

  Map<String, dynamic> toJson({String contract = 'snake_flat'}) {
    if (contract == 'camel_nested') {
      return {
        // 실제 사용자 GPS는 단말기 내부에서만 사용하고 서버로 전송하지 않습니다.
        'availableHours': availableHours,
        'transportType': transportType,
        'radiusKm': radiusKm,
        'preferredCategories': preferredCategories,
        'freeOnly': avoidPaid,
        'useWeather': weatherAware,
        'includeRestStop': includeRestStops,
        'expectedInclude': expectedInclude,
        'expectedExclude': expectedExclude,
        'memo': memo,
        'travelDate': travelDate,
        'startTime': startTime,
        'visitedPlaceIds': visitedPlaceIds,
      };
    }

    return {
      // 실제 사용자 GPS는 단말기 내부에서만 사용하고 서버로 전송하지 않습니다.
      'available_hours': availableHours,
      'transport_type': transportType,
      'radius_km': radiusKm,
      'preferred_categories': preferredCategories,
      'avoid_paid': avoidPaid,
      'weather_aware': weatherAware,
      'include_rest_stops': includeRestStops,
      'expected_include': expectedInclude,
      'expected_exclude': expectedExclude,
      'memo': memo,
      'travel_date': travelDate,
      'start_time': startTime,
      'visited_place_ids': visitedPlaceIds,
    };
  }
}

class RoutePlan {
  const RoutePlan({
    required this.id,
    required this.title,
    required this.summary,
    required this.totalMinutes,
    required this.totalDistanceKm,
    required this.averageQuietScore,
    required this.stops,
    required this.updatedAt,
    this.weatherSummary = '',
  });

  final String id;
  final String title;
  final String summary;
  final int totalMinutes;
  final double totalDistanceKm;
  final int averageQuietScore;
  final List<RouteStop> stops;
  final DateTime updatedAt;
  final String weatherSummary;

  RoutePlan copyWith({
    String? title,
    String? summary,
    int? totalMinutes,
    double? totalDistanceKm,
    int? averageQuietScore,
    List<RouteStop>? stops,
    DateTime? updatedAt,
    String? weatherSummary,
  }) {
    return RoutePlan(
      id: id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      averageQuietScore: averageQuietScore ?? this.averageQuietScore,
      stops: stops ?? this.stops,
      updatedAt: updatedAt ?? this.updatedAt,
      weatherSummary: weatherSummary ?? this.weatherSummary,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'total_minutes': totalMinutes,
      'total_distance_km': totalDistanceKm,
      'average_quiet_score': averageQuietScore,
      'weather_summary': weatherSummary,
      'updated_at': updatedAt.toIso8601String(),
      'stops': stops.map((stop) => stop.toJson()).toList(),
    };
  }

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    final nested = json['route'] ?? json['course'];
    final route = nested is Map
        ? Map<String, dynamic>.from(nested)
        : json;

    final stopList = _extractList(
      route['stops'] ??
          route['places'] ??
          route['items'] ??
          route['course'],
    );

    final stops = stopList.asMap().entries.map((entry) {
      final map = Map<String, dynamic>.from(
        entry.value as Map,
      );

      return RouteStop.fromJson(
        map,
        fallbackOrder: entry.key + 1,
      );
    }).toList();

    final rawTotalMinutes = _int(
      route['total_minutes'] ??
          route['totalMinutes'] ??
          route['duration_minutes'] ??
          route['total_time'],
      fallback: 180,
    );

    final calculatedMinutes = stops.fold<int>(
      0,
      (sum, stop) =>
          sum +
          stop.stayMinutes +
          stop.travelMinutes,
    );

    // 과거 자동차 duration(ms)을 분으로 잘못 해석해 저장한 데이터는
    // 수백 시간으로 남아 있을 수 있습니다. 정규화된 stop 합계가
    // 현실적인 범위라면 그 값을 우선합니다.
    final normalizedTotalMinutes =
        rawTotalMinutes > 24 * 60 &&
                calculatedMinutes > 0 &&
                calculatedMinutes <= 24 * 60
            ? calculatedMinutes
            : rawTotalMinutes;

    final rawTitle = _string(
      route['title'],
      fallback: '한적한 경주 추천 코스',
    );

    final legacyFixedTitle =
        rawTitle.startsWith('경주한적 ') &&
        rawTitle.endsWith('형 코스');

    String normalizedTitle = rawTitle;

    if (legacyFixedTitle && stops.isNotEmpty) {
      final first = stops.first.place.name.trim();
      final last = stops.last.place.name.trim();
      final hours = (normalizedTotalMinutes / 60)
          .round()
          .clamp(1, 12);

      if (
        first.isNotEmpty &&
        last.isNotEmpty &&
        first != last
      ) {
        normalizedTitle =
            '경주 ${hours}시간 · $first→$last';
      } else if (first.isNotEmpty) {
        normalizedTitle =
            '경주 ${hours}시간 · $first';
      } else {
        normalizedTitle =
            '경주 ${hours}시간 추천 코스';
      }
    }

    return RoutePlan(
      id: _string(
        route['id'] ??
            route['route_id'] ??
            route['course_id'],
        fallback: 'route',
      ),
      title: normalizedTitle,
      summary: _string(
        route['summary'] ??
            route['subtitle'] ??
            route['description'],
        fallback:
            '혼잡도와 이동 부담을 줄여 구성한 여행 코스입니다.',
      ),
      totalMinutes: normalizedTotalMinutes,
      totalDistanceKm: _double(
        route['total_distance_km'] ??
            route['totalDistanceKm'] ??
            route['distance_km'] ??
            route['total_distance'],
        fallback: 0,
      ),
      averageQuietScore: _quietScore(
        quietValue:
            route['average_quiet_score'] ??
            route['averageQuietScore'] ??
            route['quiet_score'] ??
            route['quietScore'],
        congestionValue:
            route['average_congestion_score'] ??
            route['averageCongestionScore'],
      ),
      stops: stops,
      updatedAt: DateTime.tryParse(
            _string(
              route['updated_at'] ??
                  route['updatedAt'] ??
                  route['createdAt'],
            ),
          ) ??
          DateTime.now(),
      weatherSummary: _string(
        route['weather_summary'] ??
            route['weatherSummary'] ??
            route['weather'],
      ),
    );
  }
}

class RouteStop {
  const RouteStop({
    required this.order,
    required this.place,
    required this.arrivalTime,
    required this.stayMinutes,
    required this.travelMinutes,
    required this.transportInstruction,
    required this.isRestStop,
  });

  final int order;
  final Place place;
  final String arrivalTime;
  final int stayMinutes;
  final int travelMinutes;
  final String transportInstruction;
  final bool isRestStop;

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'arrival_time': arrivalTime,
      'stay_minutes': stayMinutes,
      'travel_minutes': travelMinutes,
      'transport_instruction': transportInstruction,
      'is_rest_stop': isRestStop,
      'place': {
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
        'recommended_time': place.recommendedTime,
        'stay_minutes': place.stayMinutes,
        'is_paid': place.isPaid,
        'content_type_id': place.contentTypeId,
        'operating_hours': place.operatingHours,
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
        'is_rest_point': place.isRestPoint,
        'event_start_date': place.eventStartDate,
        'event_end_date': place.eventEndDate,
        'event_start_time': place.eventStartTime,
        'event_end_time': place.eventEndTime,
        'event_place': place.eventPlace,
        'event_time_type': place.eventTimeType,
        'source': place.source,
      },
    };
  }

  factory RouteStop.fromJson(
    Map<String, dynamic> json, {
    required int fallbackOrder,
  }) {
    final placeJson = json['place'] is Map
        ? Map<String, dynamic>.from(json['place'] as Map)
        : json;
    return RouteStop(
      order: _int(json['order'] ?? json['sequence'], fallback: fallbackOrder),
      place: Place.fromJson(placeJson),
      arrivalTime: _string(json['arrival_time'] ?? json['arrivalTime']),
      stayMinutes: _int(
        json['stay_minutes'] ?? json['stayMinutes'] ?? json['duration_minutes'],
        fallback: 60,
      ),
      travelMinutes: _normalizeTravelMinutes(
        _int(
          json['travel_minutes'] ??
              json['travelMinutes'] ??
              json['travelMinutesFromPrevious'],
          fallback: 15,
        ),
      ),
      transportInstruction: _string(
        json['transport_instruction'] ?? json['transportInstruction'] ?? json['move_description'],
        fallback: '다음 장소로 이동',
      ),
      isRestStop: _bool(json['is_rest_stop'] ?? json['isRestStop'] ?? json['rest_stop']),
    );
  }
}

List<dynamic> _extractList(dynamic value) {
  if (value is List) return value.whereType<Map>().toList();
  return const [];
}

String _string(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int _int(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int _normalizeTravelMinutes(int minutes) {
  if (minutes <= 0) {
    return 0;
  }

  // 과거 자동차 카카오 duration(ms)을 초로 잘못 해석한 데이터는
  // 실제 분의 약 1000배로 저장될 수 있습니다.
  // 경주 시내 단일 구간이 6시간(360분)을 넘는 경우에만
  // 이전 단위 오류 데이터로 보고 1000으로 보정합니다.
  if (minutes > 360) {
    final normalized = (minutes / 1000).round();

    if (normalized > 0 && normalized <= 360) {
      return normalized;
    }
  }

  return minutes;
}

double _double(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {'true', '1', 'yes', 'y'}.contains(value?.toString().toLowerCase());
}

int _quietScore({dynamic quietValue, dynamic congestionValue}) {
  if (quietValue != null) {
    final quiet = _double(quietValue, fallback: 75);
    return (quiet <= 10 ? quiet * 10 : quiet).round().clamp(0, 100).toInt();
  }
  if (congestionValue != null) {
    final congestion = _double(congestionValue, fallback: 2.5);
    final converted = congestion <= 10 ? 100 - congestion * 10 : 100 - congestion;
    return converted.round().clamp(0, 100).toInt();
  }
  return 75;
}
