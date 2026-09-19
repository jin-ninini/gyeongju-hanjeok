import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/app_theme.dart';
import '../core/legal_documents.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    required this.email,
    required this.nickname,
    required this.password,
    required this.rememberMe,
    super.key,
  });

  final String email;
  final String nickname;
  final String password;
  final bool rememberMe;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _location = false;

  bool get _requiredAccepted => _terms && _privacy;
  bool get _all => _terms && _privacy && _location;

  Future<void> _submit() async {
    if (!_requiredAccepted) return;

    final controller = AppScope.of(context, listen: false);
    final success = await controller.signUp(
      email: widget.email,
      password: widget.password,
      nickname: widget.nickname,
      termsAgreed: _terms,
      privacyAgreed: _privacy,
      locationAgreed: _location,
      rememberMe: widget.rememberMe,
    );

    if (!mounted) return;

    if (success) {
      // 위치 기반 추천에 선택 동의한 경우에만,
      // 회원가입이 성공한 뒤 OS의 실제 위치 권한 창을 요청합니다.
      if (_location) {
        await _requestLocationPermission();
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (controller.authError != null) {
      showAppSnackBar(context, controller.authError!);
    }
  }

  Future<void> _requestLocationPermission() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 위치 권한은 선택 사항입니다.
    // 사용자가 거부하거나 '다시 묻지 않음' 상태여도 회원가입은 그대로 완료합니다.
    if (!mounted) return;

    if (permission == LocationPermission.deniedForever) {
      showAppSnackBar(
        context,
        '위치 권한이 꺼져 있어요. 필요할 때 기기 설정에서 위치 권한을 허용할 수 있어요.',
      );
    }
  }

  void _showDocument(String title, String text) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(text, style: const TextStyle(height: 1.7, color: AppColors.ink)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        title: const Text('약관 및 권한 동의'),
        backgroundColor: const Color(0xFFF1E8D7),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF4A382C),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const Text(
              '마지막 단계예요',
              style: TextStyle(
                fontFamily: 'MaruBuri',
                color: Color(0xFF4A382C),
                fontSize: 23,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '필수 약관에 동의하면 회원가입이 완료됩니다. 위치 기반 추천 활용은 선택할 수 있어요.',
              style: TextStyle(color: Color(0xFF7C7065), height: 1.5),
            ),
            const SizedBox(height: 22),
            _ConsentTile(
              value: _all,
              title: '전체 동의',
              emphasized: true,
              onChanged: (value) => setState(() {
                _terms = value;
                _privacy = value;
                _location = value;
              }),
            ),
            const Divider(height: 26),
            _ConsentTile(
              value: _terms,
              title: '[필수] 서비스 이용약관',
              onChanged: (value) => setState(() => _terms = value),
              onDetail: () => _showDocument('서비스 이용약관', LegalDocuments.serviceTerms),
            ),
            _ConsentTile(
              value: _privacy,
              title: '[필수] 개인정보 수집·이용',
              onChanged: (value) => setState(() => _privacy = value),
              onDetail: () => _showDocument('개인정보 수집·이용', LegalDocuments.privacy),
            ),
            _ConsentTile(
              value: _location,
              title: '[선택] 위치 기반 추천 활용',
              onChanged: (value) => setState(() => _location = value),
              onDetail: () => _showDocument('위치 기반 추천 활용', LegalDocuments.location),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF3),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: const Color(0xFFD9BF86)),
              ),
              child: const Text(
                '위치 기반 추천에 동의하면 회원가입 완료 후 기기의 위치 권한을 요청합니다. 현재 위치는 주변 장소·거리·추천 기능을 위해 기기 내에서 처리되며 경주한적 서버로 전송되지 않습니다. 위치 권한을 허용하지 않아도 다른 기능은 이용할 수 있습니다.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: !_requiredAccepted || controller.isAuthenticating ? null : _submit,
              child: controller.isAuthenticating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('동의하고 가입하기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.value,
    required this.title,
    required this.onChanged,
    this.onDetail,
    this.emphasized = false,
  });

  final bool value;
  final String title;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onDetail;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF3),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: emphasized
              ? const Color(0xFFC79B52)
              : const Color(0xFFE0CDA7),
          width: emphasized ? 1.2 : 1,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (value) => onChanged(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.forest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            color: AppColors.ink,
            fontSize: 13,
          ),
        ),
        secondary: onDetail == null
            ? null
            : TextButton(
          onPressed: onDetail,
          child: const Text('보기'),
        ),
      ),
    );
  }
}
