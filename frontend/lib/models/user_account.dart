class UserConsentState {
  const UserConsentState({
    required this.termsAgreed,
    required this.privacyAgreed,
    required this.locationAgreed,
    required this.termsVersion,
    required this.privacyVersion,
    required this.locationVersion,
  });

  final bool termsAgreed;
  final bool privacyAgreed;
  final bool locationAgreed;
  final String termsVersion;
  final String privacyVersion;
  final String locationVersion;

  factory UserConsentState.fromJson(Map<String, dynamic> json) {
    return UserConsentState(
      termsAgreed: json['terms_agreed'] == true,
      privacyAgreed: json['privacy_agreed'] == true,
      locationAgreed: json['location_agreed'] == true,
      termsVersion: (json['terms_version'] ?? '').toString(),
      privacyVersion: (json['privacy_version'] ?? '').toString(),
      locationVersion: (json['location_version'] ?? '').toString(),
    );
  }
}

class UserAccount {
  const UserAccount({
    required this.id,
    required this.memberCode,
    required this.email,
    required this.nickname,
    required this.createdAt,
    required this.consents,
  });

  final String id;
  final String memberCode;
  final String email;

  String get friendQrData => 'gyeongjuhanjeok://friend/$memberCode';
  final String nickname;
  final DateTime? createdAt;
  final UserConsentState consents;

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    final consentJson = json['consents'] is Map
        ? Map<String, dynamic>.from(json['consents'] as Map)
        : const <String, dynamic>{};

    return UserAccount(
      id: (json['user_id'] ?? json['id'] ?? '').toString(),
      memberCode: (json['member_code'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      nickname: (json['nickname'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      consents: UserConsentState.fromJson(consentJson),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  final String accessToken;
  final DateTime? expiresAt;
  final UserAccount user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};

    return AuthSession(
      accessToken: (json['access_token'] ?? '').toString(),
      expiresAt: DateTime.tryParse((json['expires_at'] ?? '').toString()),
      user: UserAccount.fromJson(userJson),
    );
  }
}
