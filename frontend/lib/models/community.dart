enum CommunityPostType {
  course,
  live,
  travel;

  String get value => name;

  String get label => switch (this) {
        CommunityPostType.course => '코스 후기',
        CommunityPostType.live => '지금 여기',
        CommunityPostType.travel => '여행 후기',
      };

  static CommunityPostType fromValue(String value) => switch (value) {
        'course' => CommunityPostType.course,
        'live' => CommunityPostType.live,
        _ => CommunityPostType.travel,
      };
}

class CommunityAuthor {
  const CommunityAuthor({
    required this.userId,
    required this.nickname,
    required this.memberCode,
  });

  final String userId;
  final String nickname;
  final String memberCode;

  factory CommunityAuthor.fromJson(Map<String, dynamic> json) {
    return CommunityAuthor(
      userId: (json['user_id'] ?? '').toString(),
      nickname: (json['nickname'] ?? '여행자').toString(),
      memberCode: (json['member_code'] ?? '').toString(),
    );
  }
}

class CrowdBucket {
  const CrowdBucket({
    required this.minPercent,
    required this.maxPercent,
    required this.key,
    required this.label,
    required this.colorKey,
  });

  final int minPercent;
  final int maxPercent;
  final String key;
  final String label;
  final String colorKey;

  factory CrowdBucket.fromJson(Map<String, dynamic> json) {
    return CrowdBucket(
      minPercent: _int(json['min_percent']),
      maxPercent: _int(json['max_percent']),
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      colorKey: (json['color_key'] ?? '').toString(),
    );
  }
}

class CommunityPost {
  const CommunityPost({
    required this.postId,
    required this.postType,
    required this.author,
    required this.title,
    required this.content,
    required this.imageUrls,
    required this.tags,
    required this.relatedPlaceIds,
    required this.recommendationCount,
    required this.commentCount,
    required this.recommendedByMe,
    required this.courseSavedByMe,
    required this.createdAt,
    required this.updatedAt,
    this.courseSnapshot,
    this.sourceJourneyId,
    this.courseRating,
    this.travelDate,
    this.placeId,
    this.placeTitle,
    this.crowdPercent,
    this.crowdBucket,
    this.observedAt,
    this.liveIsRecent = false,
  });

  final String postId;
  final CommunityPostType postType;
  final CommunityAuthor author;
  final String title;
  final String content;
  final List<String> imageUrls;
  final List<String> tags;
  final List<String> relatedPlaceIds;
  final Map<String, dynamic>? courseSnapshot;
  final String? sourceJourneyId;
  final double? courseRating;
  final String? travelDate;
  final String? placeId;
  final String? placeTitle;
  final int? crowdPercent;
  final CrowdBucket? crowdBucket;
  final DateTime? observedAt;
  final bool liveIsRecent;
  final int recommendationCount;
  final int commentCount;
  final bool recommendedByMe;
  final bool courseSavedByMe;
  final DateTime createdAt;
  final DateTime updatedAt;

  CommunityPost copyWith({
    int? recommendationCount,
    int? commentCount,
    bool? recommendedByMe,
    bool? courseSavedByMe,
  }) {
    return CommunityPost(
      postId: postId,
      postType: postType,
      author: author,
      title: title,
      content: content,
      imageUrls: imageUrls,
      tags: tags,
      relatedPlaceIds: relatedPlaceIds,
      courseSnapshot: courseSnapshot,
      sourceJourneyId: sourceJourneyId,
      courseRating: courseRating,
      travelDate: travelDate,
      placeId: placeId,
      placeTitle: placeTitle,
      crowdPercent: crowdPercent,
      crowdBucket: crowdBucket,
      observedAt: observedAt,
      liveIsRecent: liveIsRecent,
      recommendationCount: recommendationCount ?? this.recommendationCount,
      commentCount: commentCount ?? this.commentCount,
      recommendedByMe: recommendedByMe ?? this.recommendedByMe,
      courseSavedByMe: courseSavedByMe ?? this.courseSavedByMe,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : const <String, dynamic>{};
    final bucketJson = json['crowd_bucket'] is Map
        ? Map<String, dynamic>.from(json['crowd_bucket'] as Map)
        : null;
    final snapshot = json['course_snapshot'] is Map
        ? Map<String, dynamic>.from(json['course_snapshot'] as Map)
        : null;

    return CommunityPost(
      postId: (json['post_id'] ?? '').toString(),
      postType: CommunityPostType.fromValue((json['post_type'] ?? '').toString()),
      author: CommunityAuthor.fromJson(authorJson),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      imageUrls: _strings(json['image_urls']),
      tags: _strings(json['tags']),
      relatedPlaceIds: _strings(json['related_place_ids']),
      courseSnapshot: snapshot,
      sourceJourneyId: _nullableString(json['source_journey_id']),
      courseRating: _doubleOrNull(json['course_rating']),
      travelDate: _nullableString(json['travel_date']),
      placeId: _nullableString(json['place_id']),
      placeTitle: _nullableString(json['place_title']),
      crowdPercent: _intOrNull(json['crowd_percent']),
      crowdBucket: bucketJson == null ? null : CrowdBucket.fromJson(bucketJson),
      observedAt: _dateOrNull(json['observed_at']),
      liveIsRecent: json['live_is_recent'] == true,
      recommendationCount: _int(json['recommendation_count']),
      commentCount: _int(json['comment_count']),
      recommendedByMe: json['recommended_by_me'] == true,
      courseSavedByMe: json['course_saved_by_me'] == true,
      createdAt: _dateOrNull(json['created_at']) ?? DateTime.now(),
      updatedAt: _dateOrNull(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.commentId,
    required this.postId,
    required this.author,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String commentId;
  final String postId;
  final CommunityAuthor author;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : const <String, dynamic>{};
    return CommunityComment(
      commentId: (json['comment_id'] ?? '').toString(),
      postId: (json['post_id'] ?? '').toString(),
      author: CommunityAuthor.fromJson(authorJson),
      content: (json['content'] ?? '').toString(),
      createdAt: _dateOrNull(json['created_at']) ?? DateTime.now(),
      updatedAt: _dateOrNull(json['updated_at']) ?? DateTime.now(),
    );
  }
}

class CommunityCourseCopy {
  const CommunityCourseCopy({
    required this.sourcePostId,
    required this.sourceAuthorNickname,
    required this.courseSnapshot,
    required this.placeIds,
    required this.sourcePlaceNames,
    required this.missingPlaceIds,
    required this.includeFood,
    required this.includeCafe,
    required this.suggestedAvailableMinutes,
    required this.sameCourseRequestPatch,
    required this.requiresLiveRefresh,
    required this.message,
  });

  final String sourcePostId;
  final String sourceAuthorNickname;
  final Map<String, dynamic> courseSnapshot;
  final List<String> placeIds;
  final List<String> sourcePlaceNames;
  final List<String> missingPlaceIds;
  final bool includeFood;
  final bool includeCafe;
  final int? suggestedAvailableMinutes;
  final Map<String, dynamic> sameCourseRequestPatch;
  final bool requiresLiveRefresh;
  final String message;

  factory CommunityCourseCopy.fromJson(Map<String, dynamic> json) {
    return CommunityCourseCopy(
      sourcePostId: (json['source_post_id'] ?? '').toString(),
      sourceAuthorNickname: (json['source_author_nickname'] ?? '').toString(),
      courseSnapshot: json['course_snapshot'] is Map
          ? Map<String, dynamic>.from(json['course_snapshot'] as Map)
          : const <String, dynamic>{},
      placeIds: _strings(json['place_ids']),
      sourcePlaceNames: _strings(json['source_place_names']),
      missingPlaceIds: _strings(json['missing_place_ids']),
      includeFood: json['include_food'] == true,
      includeCafe: json['include_cafe'] == true,
      suggestedAvailableMinutes: _intOrNull(json['suggested_available_minutes']),
      sameCourseRequestPatch: json['same_course_request_patch'] is Map
          ? Map<String, dynamic>.from(json['same_course_request_patch'] as Map)
          : const <String, dynamic>{},
      requiresLiveRefresh: json['requires_live_refresh'] != false,
      message: (json['message'] ?? '').toString(),
    );
  }
}

int _int(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;
int? _intOrNull(dynamic value) => value == null ? null : int.tryParse(value.toString());
double? _doubleOrNull(dynamic value) => value == null ? null : double.tryParse(value.toString());
String? _nullableString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
DateTime? _dateOrNull(dynamic value) => DateTime.tryParse(value?.toString() ?? '');
List<String> _strings(dynamic value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
}
