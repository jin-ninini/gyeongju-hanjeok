class Place {
  const Place({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.quietScore,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.imageAsset,
    required this.distanceKm,
    this.hasLocalDistance = false,
    required this.recommendedTime,
    required this.stayMinutes,
    required this.isPaid,
    this.contentTypeId = '',
    this.etiquette = const [],
    this.contentLinks = const [],
    this.blogCount = 0,
    this.videoCount = 0,
    this.operatingHours = '',
    this.operatingHoursLabel = '',
    this.breakTime = '',
    this.restDate = '',
    this.feeText = '',
    this.parking = '',
    this.phone = '',
    this.homepage = '',
    this.kakaoPlaceUrl = '',
    this.representativeMenu = '',
    this.menuItems = const [],
    this.isRestPoint = false,
    this.eventStartDate = '',
    this.eventEndDate = '',
    this.eventStartTime = '',
    this.eventEndTime = '',
    this.eventPlace = '',
    this.eventTimeType = 'unknown',
    this.source = '',
    this.communityCongestionScore,
    this.communityReportCount = 0,
    this.communityLatestObservedAt,
    this.routingCongestionScore,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final int quietScore;
  final String category;
  final String description;
  final String imageUrl;
  final String imageAsset;
  final double distanceKm;
  // 사용자 현재 위치와의 거리를 단말기에서 계산했는지 여부.
  // false이면 distanceKm 값이 있더라도 홈/지도 UI에서 거리로 노출하지 않습니다.
  final bool hasLocalDistance;
  final String recommendedTime;
  final int stayMinutes;
  final bool isPaid;
  final String contentTypeId;
  final List<String> etiquette;
  final List<ContentLink> contentLinks;
  final int blogCount;
  final int videoCount;

  // 백엔드 상세정보 호환 필드
  final String operatingHours;
  final String operatingHoursLabel;
  final String breakTime;
  final String restDate;
  final String feeText;
  final String parking;
  final String phone;
  final String homepage;
  final String kakaoPlaceUrl;
  final String representativeMenu;
  final List<MenuItem> menuItems;
  final bool isRestPoint;

  // 행사/축제 정보. 실제 백엔드/TourAPI 응답에 있는 값만 사용합니다.
  final String eventStartDate;
  final String eventEndDate;
  final String eventStartTime;
  final String eventEndTime;
  final String eventPlace;
  final String eventTimeType;
  final String source;

  final double? communityCongestionScore;
  final int communityReportCount;
  final DateTime? communityLatestObservedAt;
  final double? routingCongestionScore;

  bool get isEvent =>
      contentTypeId == '15' || tourismCategory == '행사' || category == '행사';

  String get eventPeriodLabel {
    if (!isEvent) return '';
    final start = _eventDateLabel(eventStartDate);
    final end = _eventDateLabel(eventEndDate);
    if (start.isEmpty && end.isEmpty) return '';
    if (start.isNotEmpty && end.isNotEmpty && start != end) {
      return '$start~$end';
    }
    return start.isNotEmpty ? start : end;
  }

  String get eventTimeLabel {
    if (!isEvent) return '';
    if (eventStartTime.isNotEmpty && eventEndTime.isNotEmpty) {
      return '$eventStartTime~$eventEndTime';
    }
    if (eventStartTime.isNotEmpty) return eventStartTime;
    return '';
  }

  double get congestionScoreValue =>
      ((100 - quietScore) / 10).clamp(0, 10).toDouble();

  int get congestionScore => congestionScoreValue.round();

  String get quietLabel {
    if (quietScore >= 90) return '매우 여유로워요';
    if (quietScore >= 80) return '여유로워요';
    if (quietScore >= 70) return '비교적 여유로워요';
    return '보통이에요';
  }

  /// 홈 장소카드의 기본 관광 유형입니다.
  ///
  /// 행사(contentTypeId=15)는 홈 카테고리에서 제외하고 코스 구성 단계에서만
  /// 활용합니다. `핫플레이스`는 기본 유형을 덮어쓰는 카테고리가 아니라
  /// 최근 관심도(블로그/영상)로 골라보는 별도 탐색 필터입니다.
  String get tourismCategory {
    final raw = category.replaceAll('·', ' ').trim();
    const canonical = {'자연', '문화유산', '전통마을', '야경'};
    if (canonical.contains(raw)) return raw;

    // 음식/카페는 관광지 분류 대상이 아니므로 원래 값을 보존합니다.
    if (raw == '맛집' || raw == '카페' || raw == '음식점' || contentTypeId == '39') {
      return raw.isEmpty ? '맛집' : raw;
    }

    // 축제/행사는 홈 카테고리에서 노출하지 않습니다.
    if (contentTypeId == '15' || _containsAny('$name $raw $description'.toLowerCase(), const [
      '축제',
      '행사',
      '공연',
      '이벤트',
      '페스티벌',
    ])) {
      return '행사';
    }

    final nameKey = name.replaceAll(' ', '').toLowerCase();
    final haystack = '$name $raw $description'.toLowerCase();

    // 전통마을은 실제 마을/한옥뿐 아니라 경주의 골목·거리형 관광지까지 포함합니다.
    // 단, 둘레길/숲길/산책길처럼 자연 탐방 성격의 "길"은 자연으로 남깁니다.
    final looksLikeStreet =
        nameKey.endsWith('단길') ||
        _containsAny(nameKey, const [
          '황리단길',
          '교촌길',
          '한옥길',
          '전통길',
          '문화거리',
          '전통거리',
          '골목',
        ]) ||
        (nameKey.endsWith('길') &&
            !_containsAny(nameKey, const [
              '둘레길',
              '산책길',
              '숲길',
              '탐방길',
              '등산길',
              '자전거길',
              '해파랑길',
              '벚꽃길',
            ]));

    if (looksLikeStreet ||
        _containsAny(haystack, const [
          '전통마을',
          '한옥마을',
          '한옥',
          '고택',
          '양동마을',
          '교촌마을',
          '교촌 한옥',
        ])) {
      return '전통마을';
    }

    if (_containsAny(haystack, const [
      '야경',
      '야간',
      '라이트',
      '동궁과 월지',
      '월정교',
      '첨성대',
    ])) {
      return '야경';
    }

    if (_containsAny(haystack, const [
      '숲',
      '공원',
      '산',
      '호수',
      '강',
      '계곡',
      '해변',
      '자연',
      '수목원',
      '정원',
      '습지',
      '생태',
      '둘레길',
      '산책길',
      '숲길',
      '탐방길',
    ])) {
      return '자연';
    }

    // 경주의 일반 관광/문화시설은 위 분류에 해당하지 않으면 문화유산으로 표시합니다.
    return '문화유산';
  }

  int get hotPlaceScore {
    if (contentTypeId == '15' ||
        category == '맛집' ||
        category == '카페' ||
        category == '음식점' ||
        contentTypeId == '39') {
      return 0;
    }

    final linkedBlogs = contentLinks
        .where((link) => link.type.toLowerCase().contains('blog'))
        .length;
    final linkedVideos = contentLinks
        .where((link) {
          final type = link.type.toLowerCase();
          return type.contains('youtube') || type.contains('video');
        })
        .length;

    final effectiveBlogs = blogCount > linkedBlogs ? blogCount : linkedBlogs;
    final effectiveVideos = videoCount > linkedVideos ? videoCount : linkedVideos;

    var score = effectiveBlogs * 3 + effectiveVideos * 4;

    // 목록 API에서 콘텐츠 수를 아직 내려주지 않는 경우를 위한 최소 fallback.
    // 실제 블로그/영상 관심도 값이 들어오면 그 값이 우선합니다.
    final key = name.replaceAll(' ', '').toLowerCase();
    if (_containsAny(key, const [
      '황리단길',
      '대릉원',
      '동궁과월지',
      '월정교',
      '첨성대',
      '불국사',
      '보문관광단지',
      '경주월드',
    ])) {
      score += 20;
    }

    return score;
  }

  bool get isHotPlace => hotPlaceScore >= 12;

  bool matchesHomeCategory(String requestedCategory) {
    final requested = requestedCategory.trim();
    if (requested.isEmpty || requested == '전체') {
      return contentTypeId != '15' && tourismCategory != '행사';
    }
    if (requested == '핫플레이스') {
      return isHotPlace;
    }
    return tourismCategory == requested;
  }

  Place copyWith({
    int? quietScore,
    double? distanceKm,
    bool? hasLocalDistance,
    List<String>? etiquette,
    List<ContentLink>? contentLinks,
    int? blogCount,
    int? videoCount,
    String? operatingHours,
    String? operatingHoursLabel,
    String? breakTime,
    String? restDate,
    String? feeText,
    String? parking,
    String? phone,
    String? homepage,
    String? kakaoPlaceUrl,
    String? representativeMenu,
    List<MenuItem>? menuItems,
    bool? isRestPoint,
    String? eventStartDate,
    String? eventEndDate,
    String? eventStartTime,
    String? eventEndTime,
    String? eventPlace,
    String? eventTimeType,
    String? source,
    double? communityCongestionScore,
    int? communityReportCount,
    DateTime? communityLatestObservedAt,
    double? routingCongestionScore,
  }) {
    return Place(
      id: id,
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      quietScore: quietScore ?? this.quietScore,
      category: category,
      description: description,
      imageUrl: imageUrl,
      imageAsset: imageAsset,
      distanceKm: distanceKm ?? this.distanceKm,
      hasLocalDistance: hasLocalDistance ?? this.hasLocalDistance,
      recommendedTime: recommendedTime,
      stayMinutes: stayMinutes,
      isPaid: isPaid,
      contentTypeId: contentTypeId,
      etiquette: etiquette ?? this.etiquette,
      contentLinks: contentLinks ?? this.contentLinks,
      blogCount: blogCount ?? this.blogCount,
      videoCount: videoCount ?? this.videoCount,
      operatingHours: operatingHours ?? this.operatingHours,
      operatingHoursLabel: operatingHoursLabel ?? this.operatingHoursLabel,
      breakTime: breakTime ?? this.breakTime,
      restDate: restDate ?? this.restDate,
      feeText: feeText ?? this.feeText,
      parking: parking ?? this.parking,
      phone: phone ?? this.phone,
      homepage: homepage ?? this.homepage,
      kakaoPlaceUrl:
          kakaoPlaceUrl ?? this.kakaoPlaceUrl,
      representativeMenu:
          representativeMenu ?? this.representativeMenu,
      menuItems: menuItems ?? this.menuItems,
      isRestPoint: isRestPoint ?? this.isRestPoint,
      eventStartDate: eventStartDate ?? this.eventStartDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      eventStartTime: eventStartTime ?? this.eventStartTime,
      eventEndTime: eventEndTime ?? this.eventEndTime,
      eventPlace: eventPlace ?? this.eventPlace,
      eventTimeType: eventTimeType ?? this.eventTimeType,
      source: source ?? this.source,
      communityCongestionScore: communityCongestionScore ?? this.communityCongestionScore,
      communityReportCount: communityReportCount ?? this.communityReportCount,
      communityLatestObservedAt: communityLatestObservedAt ?? this.communityLatestObservedAt,
      routingCongestionScore: routingCongestionScore ?? this.routingCongestionScore,
    );
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates'] is Map
        ? Map<String, dynamic>.from(json['coordinates'] as Map)
        : const <String, dynamic>{};

    final rawQuiet = _number(
      json['quietScore'] ??
          json['quiet_score'] ??
          json['hanjeok_score'] ??
          json['quietness'] ??
          json['quietness_score'],
      fallback: -1,
    );

    final rawCongestion = _number(
      json['congestionScore'] ??
          json['congestion_score'] ??
          json['crowd_score'] ??
          json['congestion'],
      fallback: -1,
    );

    int quietScore;
    if (rawQuiet >= 0) {
      quietScore = rawQuiet <= 10
          ? (rawQuiet * 10).round()
          : rawQuiet.round();
    } else if (rawCongestion >= 0) {
      quietScore = rawCongestion <= 10
          ? (100 - rawCongestion * 10).round()
          : (100 - rawCongestion).round();
    } else {
      quietScore = 70;
    }

    final links = _list(
      json['content_links'] ??
          json['contentLinks'] ??
          json['contents'] ??
          json['links'],
    )
        .whereType<Map>()
        .map(
          (e) => ContentLink.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
        .toList();

    return Place(
      id: _text(
        json['id'] ??
            json['place_id'] ??
            json['placeId'] ??
            json['contentid'] ??
            json['contentId'] ??
            json['title'],
      ),
      name: _text(
        json['name'] ?? json['title'],
        fallback: '이름 없는 장소',
      ),
      address: _text(
        json['address'] ??
            json['addr1'] ??
            json['road_address'] ??
            json['area'],
        fallback: '경주시',
      ),
      latitude: _number(
        json['latitude'] ??
            json['lat'] ??
            json['mapy'] ??
            coordinates['latitude'],
        fallback: 35.8562,
      ),
      longitude: _number(
        json['longitude'] ??
            json['lng'] ??
            json['mapx'] ??
            coordinates['longitude'],
        fallback: 129.2247,
      ),
      quietScore: quietScore.clamp(0, 100).toInt(),
      category: _text(
        json['category'] ??
            json['place_category'] ??
            json['mapped_category'] ??
            json['theme'] ??
            json['content_type'],
        fallback: '관광지',
      ),
      description: _text(
        json['description'] ??
            json['place_description'] ??
            json['intro'] ??
            json['overview'] ??
            json['summary'] ??
            json['subtitle'],
        fallback: '',
      ),
      imageUrl: _text(
        json['imageUrl'] ??
            json['image_url'] ??
            json['firstimage'] ??
            json['firstImage'],
      ),
      imageAsset: _text(
        json['imageAsset'] ?? json['image_asset'],
        fallback: _assetFromImageKey(json['imageKey']),
      ),
      distanceKm: _number(
        json['distanceKm'] ??
            json['distance_km'] ??
            json['distance'],
        fallback: 0,
      ),
      hasLocalDistance: _boolean(
        json['has_local_distance'] ??
            json['hasLocalDistance'],
      ),
      recommendedTime: _text(
        json['recommendedTime'] ??
            json['recommended_time'],
        fallback: '현재 시간대',
      ),
      stayMinutes: _integer(
        json['stayMinutes'] ??
            json['stay_minutes'] ??
            json['duration_minutes'],
        fallback: 60,
      ),
      isPaid: _paidValue(json),
      contentTypeId: _text(
        json['content_type_id'] ??
            json['contentTypeId'] ??
            json['contenttypeid'],
      ),
      etiquette: _list(
        json['etiquette'] ??
            json['etiquette_tips'],
      ).map((e) => e.toString()).toList(),
      contentLinks: links,
      blogCount: _integer(
        json['blog_count'] ?? json['blogCount'],
        fallback: 0,
      ),
      videoCount: _integer(
        json['video_count'] ?? json['videoCount'],
        fallback: 0,
      ),
      operatingHours: _text(
        json['opening_hours'] ??
            json['openingHours'] ??
            json['operating_hours'] ??
            json['operatingHours'],
      ),
      operatingHoursLabel: _text(
        json['operating_hours_label'] ?? json['operatingHoursLabel'],
      ),
      breakTime: _text(
        json['break_time'] ??
            json['breakTime'],
      ),
      restDate: _text(
        json['closed_days'] ??
            json['closedDays'] ??
            json['rest_date'] ??
            json['restDate'],
      ),
      feeText: _text(
        json['admission_fee'] ??
            json['admissionFee'] ??
            json['fee_text'] ??
            json['feeText'],
      ),
      parking: _parkingText(
        json['parking'] ??
            json['parking_info'] ??
            json['parkingInfo'] ??
            json['parking_available'] ??
            json['parkingAvailable'],
      ),
      phone: _text(
        json['phone'] ??
            json['telephone'] ??
            json['tel'],
      ),
      homepage: _text(json['homepage']),
      kakaoPlaceUrl: _text(
        json['kakao_place_url'] ??
            json['kakaoPlaceUrl'],
      ),
      representativeMenu: _text(
        json['representative_menu'] ??
            json['representativeMenu'],
      ),
      menuItems: _list(
        json['menu_items'] ??
            json['menuItems'],
      )
          .whereType<Map>()
          .map(
            (item) => MenuItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
      isRestPoint: _boolean(
        json['is_rest_point'] ??
            json['isRestPoint'],
      ),
      eventStartDate: _text(
        json['event_start_date'] ?? json['eventStartDate'] ?? json['eventstartdate'],
      ),
      eventEndDate: _text(
        json['event_end_date'] ?? json['eventEndDate'] ?? json['eventenddate'],
      ),
      eventStartTime: _text(
        json['event_start_time'] ?? json['eventStartTime'],
      ),
      eventEndTime: _text(
        json['event_end_time'] ?? json['eventEndTime'],
      ),
      eventPlace: _text(
        json['event_place'] ?? json['eventPlace'] ?? json['eventplace'],
      ),
      eventTimeType: _text(
        json['event_time_type'] ?? json['eventTimeType'],
        fallback: 'unknown',
      ),
      source: _text(json['source']),
      communityCongestionScore: _doubleOrNull(
        json['community_congestion_score'] ?? json['communityCongestionScore'],
      ),
      communityReportCount: _integer(
        json['community_report_count'] ?? json['communityReportCount'],
        fallback: 0,
      ),
      communityLatestObservedAt: _dateOrNull(
        json['community_latest_observed_at'] ?? json['communityLatestObservedAt'],
      ),
      routingCongestionScore: _doubleOrNull(
        json['routing_congestion_score'] ?? json['routingCongestionScore'],
      ),
    );
  }
}

class MenuItem {
  const MenuItem({
    required this.name,
    required this.price,
    required this.source,
    required this.representative,
  });

  final String name;
  final String price;
  final String source;
  final bool representative;

  factory MenuItem.fromJson(
    Map<String, dynamic> json,
  ) {
    return MenuItem(
      name: _text(
        json['name'],
        fallback: '메뉴',
      ),
      price: _text(json['price']),
      source: _text(
        json['source'],
        fallback: 'unknown',
      ),
      representative: _boolean(
        json['representative'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'source': source,
      'representative': representative,
    };
  }
}


class ContentLink {
  const ContentLink({
    required this.title,
    required this.url,
    required this.type,
  });

  final String title;
  final String url;
  final String type;

  factory ContentLink.fromJson(
    Map<String, dynamic> json,
  ) {
    return ContentLink(
      title: _text(
        json['title'],
        fallback: '관련 콘텐츠',
      ),
      url: _text(
        json['url'] ?? json['link'],
      ),
      type: _text(
        json['type'] ?? json['source'],
        fallback: 'web',
      ),
    );
  }
}


String _eventDateLabel(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 8) return value.trim();
  final month = int.tryParse(digits.substring(4, 6));
  final day = int.tryParse(digits.substring(6, 8));
  if (month == null || day == null) return value.trim();
  return '$month/$day';
}


bool _containsAny(String text, List<String> keywords) {
  for (final keyword in keywords) {
    if (text.contains(keyword.toLowerCase())) return true;
  }
  return false;
}

String _parkingText(dynamic value) {
  if (value == null) return '';
  if (value is bool) return value ? '주차 가능' : '주차 불가';
  if (value is num) return value == 0 ? '주차 불가' : '주차 가능';

  final text = value.toString().trim();
  if (text.isEmpty) return '';

  final lowered = text.toLowerCase();
  if (lowered == 'true' || lowered == 'yes' || lowered == 'y') {
    return '주차 가능';
  }
  if (lowered == 'false' || lowered == 'no' || lowered == 'n') {
    return '주차 불가';
  }
  return text;
}

String _text(
  dynamic value, {
  String fallback = '',
}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

double _number(
  dynamic value, {
  double fallback = 0,
}) {
  if (value is num) return value.toDouble();
  return double.tryParse(
        value?.toString() ?? '',
      ) ??
      fallback;
}

double? _doubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

DateTime? _dateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

int _integer(
  dynamic value, {
  int fallback = 0,
}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(
        value?.toString() ?? '',
      ) ??
      fallback;
}

bool _boolean(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  return const {
    'true',
    '1',
    'yes',
    'y',
  }.contains(
    value?.toString().toLowerCase(),
  );
}

String _assetFromImageKey(dynamic value) {
  final key = value?.toString().trim() ?? '';
  if (key.isEmpty) return '';

  const supported = {
    'bomun',
    'oreung',
    'yangdong',
    'muyeol',
    'woljeong',
    'cheomseong',
  };

  return supported.contains(key)
      ? 'assets/images/$key.png'
      : '';
}

bool _paidValue(Map<String, dynamic> json) {
  final explicitPaid =
      json['isPaid'] ??
      json['is_paid'] ??
      json['paid'];

  if (explicitPaid != null) {
    return _boolean(explicitPaid);
  }

  final freeValue =
      json['isFree'] ??
      json['is_free'];

  if (freeValue != null) {
    return !_boolean(freeValue);
  }

  final fee = _number(
    json['entranceFee'] ??
        json['entrance_fee'],
    fallback: 0,
  );

  return fee > 0;
}

List<dynamic> _list(dynamic value) {
  if (value is List) return value;
  return const [];
}
