class AuthUser {
  final String id;
  final String email;
  final String name;
  final bool isGuest;
  final DateTime createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    this.isGuest = false,
    required this.createdAt,
  });

  AuthUser copyWith({
    String? id,
    String? email,
    String? name,
    bool? isGuest,
    DateTime? createdAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'isGuest': isGuest,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String? ?? 'User',
      isGuest: json['isGuest'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

class AuthSession {
  final String token;
  final AuthUser user;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const AuthSession({
    required this.token,
    required this.user,
    required this.createdAt,
    this.expiresAt,
  });

  /// A session is valid as long as an authenticated user is present.
  /// Supabase SDK automatically refreshes expired access tokens using the refresh token.
  bool get isValid => user.id.isNotEmpty;

  /// Checks if the current access token has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
}

class AuthRegistrationResult {
  final AuthUser? user;
  final bool requiresEmailConfirmation;
  final String message;

  const AuthRegistrationResult({
    this.user,
    required this.requiresEmailConfirmation,
    required this.message,
  });
}
