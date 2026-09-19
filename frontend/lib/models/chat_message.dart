class ChatSource {
  const ChatSource({
    required this.sourceType,
    required this.placeId,
    required this.title,
    required this.category,
    required this.similarity,
    this.overview,
    this.address,
    this.operatingHours,
    this.restDate,
    this.feeText,
    this.parking,
    this.strollerInfo,
    this.petInfo,
    this.homepage,
  });

  final String sourceType;
  final String placeId;
  final String title;
  final String category;
  final double similarity;
  final String? overview;
  final String? address;
  final String? operatingHours;
  final String? restDate;
  final String? feeText;
  final String? parking;
  final String? strollerInfo;
  final String? petInfo;
  final String? homepage;

  bool get isEtiquette => sourceType == 'etiquette';

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      sourceType: (json['source_type'] ?? 'place').toString(),
      placeId: (json['place_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      similarity: double.tryParse(json['similarity']?.toString() ?? '') ?? 0,
      overview: _nullableText(json['overview']),
      address: _nullableText(json['address']),
      operatingHours: _nullableText(json['operating_hours']),
      restDate: _nullableText(json['rest_date']),
      feeText: _nullableText(json['fee_text']),
      parking: _nullableText(json['parking']),
      strollerInfo: _nullableText(json['stroller_info']),
      petInfo: _nullableText(json['pet_info']),
      homepage: _nullableText(json['homepage']),
    );
  }
}

class ChatAnswer {
  const ChatAnswer({
    required this.query,
    required this.answer,
    required this.hits,
    required this.grounded,
  });

  final String query;
  final String answer;
  final List<ChatSource> hits;
  final bool grounded;

  factory ChatAnswer.fromJson(Map<String, dynamic> json) {
    final rawHits = json['hits'];
    return ChatAnswer(
      query: (json['query'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      hits: rawHits is List
          ? rawHits
              .whereType<Map>()
              .map((e) => ChatSource.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      grounded: json['grounded'] is bool ? json['grounded'] as bool : true,
    );
  }
}

enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.hits = const [],
    this.grounded = true,
    this.isError = false,
  });

  final ChatRole role;
  final String text;
  final List<ChatSource> hits;
  final bool grounded;
  final bool isError;

  factory ChatMessage.user(String text) => ChatMessage(role: ChatRole.user, text: text);

  factory ChatMessage.assistant(ChatAnswer answer) => ChatMessage(
        role: ChatRole.assistant,
        text: answer.answer,
        hits: answer.hits,
        grounded: answer.grounded,
      );

  factory ChatMessage.error(String text) => ChatMessage(role: ChatRole.assistant, text: text, isError: true);
}

String? _nullableText(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
