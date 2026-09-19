import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/chat_message.dart';
import '../services/api_client.dart';
import '../services/chat_repository.dart';

const _suggestedQuestions = [
  '불국사에서 지켜야 할 예절 알려줘',
  '첨성대 야간에 가도 돼?',
  '동궁과 월지 관람시간이 어떻게 돼?',
  '경주 사찰 방문할 때 주의할 점 알려줘',
];

const _botNormalAsset = 'assets/images/chatbot_normal.png';
const _botSadAsset = 'assets/images/chatbot_sad.png';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  late final ChatRepository _repository;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository(ApiClient());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;

    final historyBeforeThisTurn = List<ChatMessage>.from(_messages);

    setState(() {
      _messages.add(ChatMessage.user(text));
      _isSending = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      final answer = await _repository.ask(text, history: historyBeforeThisTurn);
      if (!mounted) return;
      setState(() => _messages.add(ChatMessage.assistant(answer)));
    } catch (error) {
      if (!mounted) return;
      final message =
      error is ApiException ? error.message : '답변을 가져오지 못했어요. 잠시 후 다시 시도해주세요.';
      setState(() => _messages.add(ChatMessage.error(message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _Header(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.line,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.035),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: _messages.isEmpty
                    ? _EmptyChatState(
                  onPickQuestion: (question) => _send(question),
                )
                    : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                  itemCount: _messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _messages.length) {
                      return const _TypingBubble();
                    }
                    return _ChatBubble(message: _messages[index]);
                  },
                ),
              ),
            ),
          ),
          _InputBar(
            controller: _inputController,
            enabled: !_isSending,
            onSend: () => _send(),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '챗봇',
            style: TextStyle(
              fontFamily: 'MaruBuri',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.0,
              color: AppColors.forest,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState({required this.onPickQuestion});

  final ValueChanged<String> onPickQuestion;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(color: AppColors.sage, shape: BoxShape.circle),
          child: const Icon(Icons.emoji_objects_outlined, color: AppColors.forest, size: 28),
        ),
        const SizedBox(height: 18),
        Text('무엇이든 물어보세요', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '경주 관광지에 대해 궁금한 걸 물어보면\n확인된 자료를 바탕으로 답해드려요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedQuestions
              .map(
                (q) => ActionChip(
              backgroundColor: Colors.white,
              side: const BorderSide(color: AppColors.sage),
              label: Text(
                q,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.forest,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => onPickQuestion(q),
            ),
          )
              .toList(),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    final bubbleColor = isUser
        ? AppColors.forest
        : message.isError
        ? const Color(0xFFFCEEEC)
        : Colors.white;
    final textColor = isUser ? Colors.white : AppColors.ink;
    final maxWidth = MediaQuery.of(context).size.width * (isUser ? 0.80 : 0.68);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: isUser ? null : Border.all(color: message.isError ? const Color(0xFFF0C9C2) : AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message.text, style: TextStyle(color: textColor, fontSize: 13.5, height: 1.5)),
          if (!message.grounded && !isUser && !message.isError) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 13, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  '자료가 부족한 답변이에요',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (message.hits.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '참고한 자료',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: message.hits.take(3).map((hit) => _SourceChip(hit: hit)).toList(),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: isUser
            ? [
          Flexible(child: bubble),
        ]
            : [
          _BotAvatar(isSad: message.isError),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.hit});

  final ChatSource hit;

  @override
  Widget build(BuildContext context) {
    final maxChipWidth = MediaQuery.sizeOf(context).width * 0.68;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showSourceDetail(context, hit),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hit.isEtiquette ? AppColors.goldLight.withValues(alpha: 0.55) : AppColors.sage,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hit.isEtiquette ? Icons.info_outline : Icons.place_outlined,
                size: 13,
                color: AppColors.forest,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  hit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourceDetail(BuildContext context, ChatSource hit) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final rows = <(String, String?)>[
          ('주소', hit.address),
          ('운영시간', hit.operatingHours),
          ('휴무일', hit.restDate),
          ('요금', hit.feeText),
          ('주차', hit.parking),
          ('유모차', hit.strollerInfo),
          ('반려동물', hit.petInfo),
          ('홈페이지', hit.homepage),
        ].where((row) => row.$2 != null).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(hit.isEtiquette ? Icons.info_outline : Icons.place_outlined, color: AppColors.forest),
                  const SizedBox(width: 8),
                  Expanded(child: Text(hit.title, style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
              if (hit.overview != null) ...[
                const SizedBox(height: 12),
                Text(
                  hit.overview!,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                ...rows.map(
                      (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            row.$1,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.$2!,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const _BotAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.line),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.forest,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotAvatar extends StatelessWidget {
  const _BotAvatar({
    this.isSad = false,
    this.size = 32,
  });

  final bool isSad;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetPath = isSad ? _botSadAsset : _botNormalAsset;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: isSad ? const Color(0xFFFCEEEC) : AppColors.sage,
            alignment: Alignment.center,
            child: Icon(
              isSad ? Icons.sentiment_dissatisfied_rounded : Icons.smart_toy_rounded,
              size: size * 0.58,
              color: AppColors.forest,
            ),
          );
        },
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.paper,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: '궁금한 점을 물어보세요'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.forest,
              disabledBackgroundColor: AppColors.sage,
            ),
            icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}