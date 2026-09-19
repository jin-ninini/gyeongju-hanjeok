import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../state/app_controller.dart';
import '../widgets/common_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final controller = AppScope.of(context, listen: false);
    final success = await controller.login(
      email: _emailController.text,
      password: _passwordController.text,
      rememberMe: _rememberMe,
    );

    if (!mounted || success) return;
    final message = controller.authError;
    if (message != null) showAppSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AuthBrand(),
                    const SizedBox(height: 28),
                    const Text(
                      '다시 만난 경주,\n한적하게 시작해요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'MaruBuri',
                        color: Color(0xFF4A382C),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        letterSpacing: -1.1,
                      ),
                    ),
                    const SizedBox(height: 9),
                    const Text(
                      '저장한 장소와 여행 기록을 이어서 이용해보세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF7C7065),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      decoration: _authCardDecoration(),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: _authInputDecoration(
                              label: '이메일',
                              hint: 'example@email.com',
                              icon: Icons.mail_outline_rounded,
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (!text.contains('@') || !text.contains('.')) {
                                return '올바른 이메일을 입력해 주세요.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: _authInputDecoration(
                              label: '비밀번호',
                              icon: Icons.lock_outline_rounded,
                            ).copyWith(
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: const Color(0xFF7A685A),
                                ),
                              ),
                            ),
                            validator: (value) => (value ?? '').isEmpty
                                ? '비밀번호를 입력해 주세요.'
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Theme(
                            data: Theme.of(context).copyWith(
                              checkboxTheme: CheckboxThemeData(
                                fillColor: WidgetStateProperty.resolveWith(
                                  (states) => states.contains(WidgetState.selected)
                                      ? const Color(0xFF315E4F)
                                      : Colors.transparent,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFC8AF7A),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                            child: CheckboxListTile(
                              value: _rememberMe,
                              onChanged: controller.isAuthenticating
                                  ? null
                                  : (value) => setState(
                                        () => _rememberMe = value ?? true,
                                      ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text(
                                '자동 로그인',
                                style: TextStyle(
                                  color: Color(0xFF4A382C),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: const Text(
                                '다음 실행에도 로그인 상태를 유지해요.',
                                style: TextStyle(
                                  color: Color(0xFF8B7E73),
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ),
                          if (controller.authError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              controller.authError!,
                              style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed:
                                  controller.isAuthenticating ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF315E4F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: controller.isAuthenticating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      '로그인',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: controller.isAuthenticating
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFFFFFDF8).withValues(alpha: 0.82),
                          foregroundColor: const Color(0xFF315E4F),
                          side: const BorderSide(
                            color: Color(0xFFC79B52),
                            width: 1.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '처음이라면 회원가입',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/gh_app_icon.png',
            width: 66,
            height: 66,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          '경주한적',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: Color(0xFFFFFFFF),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}

InputDecoration _authInputDecoration({
  required String label,
  String? hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(
      color: Color(0xFF78685A),
      fontWeight: FontWeight.w700,
    ),
    hintStyle: const TextStyle(
      color: Color(0xFFAAA095),
      fontSize: 12.5,
    ),
    prefixIcon: Icon(icon, color: const Color(0xFF6C5645), size: 21),
    filled: true,
    fillColor: const Color(0xFFFFFDF8),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFD9BF86)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(
        color: Color(0xFF315E4F),
        width: 1.4,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
    ),
  );
}

BoxDecoration _authCardDecoration() => BoxDecoration(
      color: const Color(0xFFFFFBF3),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFD6B166),
        width: 1.0,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x16000000),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    );
