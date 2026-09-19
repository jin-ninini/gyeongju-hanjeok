import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/app_theme.dart';
import '../models/friend.dart';
import '../services/kakao_invite_service.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'qr_scanner_screen.dart';
import 'saved_places_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  final _codeController = TextEditingController();
  final _inviteService = KakaoInviteService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context, listen: false).loadFriends();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final user = controller.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1E8D7),
        body: Center(child: Text('로그인이 필요합니다.')),
      );
    }

    final message = controller.friendMessage;
    if (message != null && message.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showAppSnackBar(context, message);
        controller.clearFriendMessage();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        title: const Text(
          '내 정보',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: Color(0xFF4A382C),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFF1E8D7),
        foregroundColor: const Color(0xFF4A382C),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => controller.loadFriends(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
          children: [
            _ProfileCard(
              nickname: user.nickname,
              email: user.email,
              memberCode: user.memberCode,
              qrData: user.friendQrData,
            ),
            const SizedBox(height: 14),
            _MyPageMenuTile(
              icon: Icons.bookmark_outline,
              title: '저장한 장소',
              subtitle: '북마크한 관광지와 맛집 ${controller.savedPlaces.length}곳',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SavedPlacesScreen(),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text('친구 추가', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            _FriendActions(
              onCode: () => _showCodeDialog(controller),
              onScan: () => _scanQr(controller),
              onInvite: (buttonContext) => _shareInvite(buttonContext, controller),
            ),
            if (controller.incomingFriendRequests.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('받은 친구 요청', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...controller.incomingFriendRequests.map(
                (item) => _FriendTile(
                  friendship: item,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filledTonal(
                        tooltip: '수락',
                        onPressed: () => controller.acceptFriend(item.id),
                        icon: const Icon(Icons.check),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: '거절',
                        onPressed: () => controller.removeFriend(item.id),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text('친구 ${controller.friends.length}명', style: Theme.of(context).textTheme.titleMedium),
                ),
                if (controller.isLoadingFriends)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (controller.friends.isEmpty)
              const EmptyState(
                icon: Icons.group_outlined,
                title: '아직 등록된 친구가 없어요',
                description: '회원코드, QR 또는 카카오톡 초대로 여행 친구를 추가해보세요.',
              )
            else
              ...controller.friends.map(
                (item) => _FriendTile(
                  friendship: item,
                  trailing: IconButton(
                    tooltip: '친구 삭제',
                    onPressed: () => _confirmRemove(controller, item),
                    icon: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
            if (controller.outgoingFriendRequests.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('보낸 요청', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...controller.outgoingFriendRequests.map(
                (item) => _FriendTile(
                  friendship: item,
                  subtitle: '수락 대기 중 · ${item.user.memberCode}',
                  trailing: TextButton(
                    onPressed: () => controller.removeFriend(item.id),
                    child: const Text('취소'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFFFFFBF3),
                foregroundColor: const Color(0xFF8A4D42),
                side: const BorderSide(color: Color(0xFFD7B7A7)),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await controller.logout();
              },
              icon: const Icon(Icons.logout),
              label: const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCodeDialog(AppController controller) async {
    _codeController.clear();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('회원코드로 친구 추가'),
        content: TextField(
          controller: _codeController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: '예: GJ-7K4P2Q',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_codeController.text),
            child: const Text('친구 요청'),
          ),
        ],
      ),
    );

    if (code == null || code.trim().isEmpty) return;
    await controller.requestFriendByCode(code);
  }

  Future<void> _scanQr(AppController controller) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (code == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('친구 요청을 보낼까요?'),
        content: Text('인식한 회원코드\n$code'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('요청 보내기')),
        ],
      ),
    );
    if (confirmed == true) await controller.requestFriendByCode(code);
  }

  Future<void> _shareInvite(BuildContext buttonContext, AppController controller) async {
    final invite = await controller.createFriendInvite();
    final user = controller.currentUser;
    if (invite == null || user == null || !mounted) return;

    final box = buttonContext.findRenderObject() as RenderBox?;
    await _inviteService.share(
      invite: invite,
      inviterNickname: user.nickname,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
  }

  Future<void> _confirmRemove(AppController controller, Friendship friendship) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('친구를 삭제할까요?'),
        content: Text('${friendship.user.nickname}님을 친구 목록에서 삭제합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('삭제')),
        ],
      ),
    );
    if (remove == true) await controller.removeFriend(friendship.id);
  }
}


class _MyPageMenuTile extends StatelessWidget {
  const _MyPageMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFBF3),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 14,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7D9BA),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: AppColors.forest,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.nickname,
    required this.email,
    required this.memberCode,
    required this.qrData,
  });

  final String nickname;
  final String email;
  final String memberCode;
  final String qrData;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD6B166),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFE7D9BA),
            foregroundColor: const Color(0xFF315E4F),
            child: Text(
              nickname.isEmpty ? '?' : nickname.substring(0, 1),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 10),
          Text(nickname, style: Theme.of(context).textTheme.titleLarge),
          Text(email, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE0CDA7)),
            ),
            child: QrImageView(
              data: qrData,
              size: 180,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text('내 회원코드', style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SelectableText(
                memberCode,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              IconButton(
                tooltip: '회원코드 복사',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: memberCode));
                  if (!context.mounted) return;
                  showAppSnackBar(context, '회원코드를 복사했어요.');
                },
                icon: const Icon(Icons.copy_rounded, size: 19),
              ),
            ],
          ),
          const Text('이 QR과 회원코드는 친구 추가용 공개 정보예요. 로그인 토큰이나 내부 UUID는 포함하지 않아요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: AppColors.muted, height: 1.45)),
        ],
      ),
    );
  }
}

class _FriendActions extends StatelessWidget {
  const _FriendActions({required this.onCode, required this.onScan, required this.onInvite});

  final VoidCallback onCode;
  final VoidCallback onScan;
  final void Function(BuildContext context) onInvite;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: onCode, icon: const Icon(Icons.badge_outlined), label: const Text('회원코드'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: onScan, icon: const Icon(Icons.qr_code_scanner), label: const Text('QR 스캔'))),
          ],
        ),
        const SizedBox(height: 8),
        Builder(
          builder: (buttonContext) => SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onInvite(buttonContext),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('카카오톡으로 초대'),
            ),
          ),
        ),
      ],
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friendship, required this.trailing, this.subtitle});
  final Friendship friendship;
  final Widget trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE0CDA7)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7D9BA),
          foregroundColor: const Color(0xFF315E4F),
          child: Text(friendship.user.nickname.isEmpty ? '?' : friendship.user.nickname.substring(0, 1)),
        ),
        title: Text(friendship.user.nickname, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle ?? friendship.user.memberCode),
        trailing: trailing,
      ),
    );
  }
}
