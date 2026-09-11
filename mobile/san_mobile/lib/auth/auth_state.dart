class AuthUser {
  final int userId;
  final String fullName;
  final String email;
  final String role;
  final String phone;

  const AuthUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    this.phone = '',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final person = _asMap(json['person']) ?? const <String, dynamic>{};
    final userId = _toInt(json['user_id']) ?? _toInt(json['id']) ?? 0;
    return AuthUser(
      userId: userId,
      fullName: _toStringOrEmpty(json['full_name'], fallback: person['full_name']),
      email: _toStringOrEmpty(json['email'], fallback: person['email']),
      role: (json['role'] ?? '') as String,
      phone: _toStringOrEmpty(json['phone'], fallback: person['phone']),
    );
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String _toStringOrEmpty(dynamic value, {dynamic fallback}) {
  final raw = value ?? fallback;
  if (raw == null) return '';
  return raw.toString();
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class AuthState {
  final bool isLoading;
  final String? token;
  final AuthUser? user;
  final String? error;

  const AuthState({
    required this.isLoading,
    required this.token,
    required this.user,
    required this.error,
  });

  factory AuthState.initial() => const AuthState(
        isLoading: false,
        token: null,
        user: null,
        error: null,
      );

  AuthState copyWith({
    bool? isLoading,
    String? token,
    AuthUser? user,
    String? error,
    bool clearError = false,
    bool clearUser = false,
    bool clearToken = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      token: clearToken ? null : (token ?? this.token),
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
    );
  }
}
