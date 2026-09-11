import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_api.dart';
import 'auth_state.dart';
import '../core/dio_client.dart';

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(AuthApi());
});

class AuthController extends StateNotifier<AuthState> {
  final AuthApi _api;
  static const _storage = FlutterSecureStorage();

  AuthController(this._api) : super(AuthState.initial());

  Future<void> restoreSession() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final token = await _storage.read(key: 'jwt');
      if (token == null || token.isEmpty) {
        DioClient.clearSessionToken();
        state = state.copyWith(isLoading: false, clearToken: true, clearUser: true);
        return;
      }

      DioClient.setSessionToken(token);

      final me = await _api.me();
      final auth = _asMap(me['auth']) ?? const <String, dynamic>{};
      final userMap =
          _asMap(me['user']) ?? _asMap(auth['user']) ?? const <String, dynamic>{};
      final personMap = _asMap(me['person']) ??
          _asMap(userMap['person']) ??
          _asMap(auth['person']) ??
          const <String, dynamic>{};

      final role = _toStringOrEmpty(auth['role'], fallback: userMap['role']);
      final email = _toStringOrEmpty(
        auth['email'],
        fallback: _toStringOrEmpty(
          userMap['email'],
          fallback: personMap['email'],
        ),
      );
      final userId = _toInt(auth['user_id']) ?? _toInt(userMap['user_id']);
      if (userId == null) {
        throw Exception('Missing user_id in /auth/me response');
      }

      final storedName = await _storage.read(key: 'full_name') ?? '';
      final storedPhone = await _storage.read(key: 'phone') ?? '';

      final user = AuthUser(
        userId: userId,
        fullName: _toStringOrEmpty(
          userMap['full_name'],
          fallback: _toStringOrEmpty(personMap['full_name'], fallback: storedName),
        ),
        email: email,
        role: role,
        phone: _toStringOrEmpty(
          userMap['phone'],
          fallback: _toStringOrEmpty(personMap['phone'], fallback: storedPhone),
        ),
      );

      state = state.copyWith(isLoading: false, token: token, user: user, clearError: true);
    } catch (e) {
      await logout();
      state = state.copyWith(isLoading: false, error: 'Session expired. Please login again.');
    }
  }

  Future<void> login(String email, String password, {bool rememberMe = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.login(email: email, password: password);

      if (data['ok'] != true) {
        state = state.copyWith(isLoading: false, error: (data['error'] ?? 'Login failed').toString());
        return;
      }

      final token = (data['token'] ?? '').toString();

      if (token.isEmpty) {
        throw Exception('Login response did not return token');
      }

      final userJson = _asMap(data['user']) ??
          _asMap(_asMap(data['auth'])?['user']) ??
          const <String, dynamic>{};

      if (userJson.isEmpty) {
        throw Exception('Missing user payload in login response');
      }

      final user = AuthUser.fromJson(userJson);

      // clear old token
      await _storage.delete(key: 'jwt');
      await _storage.delete(key: 'full_name');
      await _storage.delete(key: 'phone');

      // save new token
      await _storage.write(key: 'jwt', value: token);
      await _storage.write(key: 'full_name', value: user.fullName);
      await _storage.write(key: 'phone', value: user.phone);

      // set current memory token
      DioClient.setSessionToken(token);

      state = state.copyWith(
        isLoading: false,
        token: token,
        user: user,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Login error: $e');
    }
  }

  Future<void> registerPublic({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await _api.registerPublic(
        fullName: fullName,
        email: email,
        phone: phone,
        password: password,
      );

      final registerOk = data['ok'] == true ||
          data['success'] == true ||
          data['updated'] == true ||
          data['merged'] == true;
      if (!registerOk) {
        state = state.copyWith(isLoading: false, error: (data['error'] ?? 'Register failed').toString());
        return;
      }

      // After successful register, auto login
      await login(email, password, rememberMe: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Register error: $e');
    }
  }

  Future<void> logout() async {
    DioClient.clearSessionToken();
    await _storage.delete(key: 'jwt');
    await _storage.delete(key: 'full_name');
    await _storage.delete(key: 'phone');
    state = AuthState.initial();
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _toStringOrEmpty(dynamic value, {dynamic fallback}) {
  final raw = value ?? fallback;
  if (raw == null) return '';
  return raw.toString();
}
