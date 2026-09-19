import '../core/app_env.dart';
import '../models/chat_message.dart';
import 'api_client.dart';

class ChatRepository {
  ChatRepository(this._client);

  final ApiClient _client;

  Future<ChatAnswer> ask(String message, {int topK = 5, List<ChatMessage> history = const []}) async {
    if (AppEnv.isPreview) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return ChatAnswer(
        query: message,
        answer: '답변을 준비하지 못했어요. 잠시 후 다시 시도해주세요.',
        hits: const [],
        grounded: true,
      );
    }

    final data = await _client.post(
      '/chat/ask',
      data: {
        'message': message,
        'top_k': topK,
        'history': _recentHistory(history),
      },
    );
    if (data is! Map) {
      throw const ApiException('답변을 불러오지 못했어요. 잠시 후 다시 시도해주세요.');
    }
    return ChatAnswer.fromJson(Map<String, dynamic>.from(data));
  }

  // 백엔드가 최대 8턴까지만 받아서, 최근 6개(질문·답변 3쌍)만 보낸다.
  // 답변 생성에 실패한 오류 메시지는 대화 맥락이 아니므로 제외한다.
  List<Map<String, String>> _recentHistory(List<ChatMessage> history) {
    final usable = history.where((m) => !m.isError).toList();
    final recent = usable.length > 6 ? usable.sublist(usable.length - 6) : usable;
    return recent
        .map(
          (m) => {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.text.length > 2000 ? m.text.substring(0, 2000) : m.text,
          },
        )
        .toList();
  }
}
