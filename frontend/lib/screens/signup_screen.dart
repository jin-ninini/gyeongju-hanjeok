import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import 'consent_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _nicknameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConsentScreen(
          email: _emailController.text.trim(),
          nickname: _nicknameController.text.trim(),
          password: _passwordController.text,
          rememberMe: _rememberMe,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1E8D7),
      appBar: AppBar(
        title: const Text(
          '회원가입',
          style: TextStyle(
            fontFamily: 'MaruBuri',
            color: Color(0xFF4A382C),
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: const Color(0xFFF1E8D7),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF4A382C),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.asset(
                        'assets/images/gh_app_icon.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '경주한적 계정 만들기',
                            style: TextStyle(
                              fontFamily: 'MaruBuri',
                              color: Color(0xFF4A382C),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '여행 기록과 친구 기능을 한 계정에 이어서 저장해요.',
                            style: TextStyle(
                              color: Color(0xFF7C7065),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(15, 17, 15, 16),
                  decoration: _signupCardDecoration(),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _signupInputDecoration(
                          label: '이메일',
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
                        controller: _nicknameController,
                        textInputAction: TextInputAction.next,
                        maxLength: 20,
                        decoration: _signupInputDecoration(
                          label: '닉네임',
                          icon: Icons.person_outline_rounded,
                        ).copyWith(counterText: ''),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 2) {
                            return '닉네임은 2자 이상 입력해 주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.next,
                        decoration: _signupInputDecoration(
                          label: '비밀번호',
                          hint: '영문자 + 숫자 포함 8자 이상',
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
                        validator: (value) {
                          final text = value ?? '';
                          if (text.length < 8) {
                            return '8자 이상 입력해 주세요.';
                          }
                          if (!RegExp(r'[A-Za-z]').hasMatch(text) ||
                              !RegExp(r'[0-9]').hasMatch(text)) {
                            return '영문자와 숫자를 모두 포함해 주세요.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordConfirmController,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _next(),
                        decoration: _signupInputDecoration(
                          label: '비밀번호 확인',
                          icon: Icons.lock_reset_rounded,
                        ),
                        validator: (value) => value != _passwordController.text
                            ? '비밀번호가 일치하지 않습니다.'
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBF3),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: const Color(0xFFD9BF86),
                    ),
                  ),
                  child: CheckboxListTile(
                    value: _rememberMe,
                    onChanged: (value) =>
                        setState(() => _rememberMe = value ?? true),
                    activeColor: const Color(0xFF315E4F),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: const Text(
                      '가입 후 자동 로그인',
                      style: TextStyle(
                        color: Color(0xFF4A382C),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: const Text(
                      '다음에 앱을 실행해도 로그인 상태를 유지해요.',
                      style: TextStyle(
                        color: Color(0xFF8B7E73),
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _next,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF315E4F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      '약관 동의로 이동',
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
        ),
      ),
    );
  }
}

InputDecoration _signupInputDecoration({
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

BoxDecoration _signupCardDecoration() => BoxDecoration(
      color: const Color(0xFFFFFBF3),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFD6B166),
        width: 1.0,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    );
