import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config.dart';

class DioClient {
  static const _storage = FlutterSecureStorage();
  static String? _sessionToken;

  static void setSessionToken(String? token) {
    _sessionToken = token;
  }

  static void clearSessionToken() {
    _sessionToken = null;
  }

  static Dio create({bool attachAuthToken = true}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    if (attachAuthToken) {
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            var token = _sessionToken;

            if (token == null || token.isEmpty) {
              token = await _storage.read(key: 'jwt');
            }

            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';

              // TEMP DEBUG
              // print('AUTH DEBUG URL: ${options.uri}');
              // print('AUTH DEBUG TOKEN START: ${token.substring(0, token.length > 25 ? 25 : token.length)}');
              // print('AUTH DEBUG TOKEN LENGTH: ${token.length}');
            } else {
              // print('AUTH DEBUG URL: ${options.uri}');
              // print('AUTH DEBUG NO TOKEN FOUND');
            }

            return handler.next(options);
          },
        ),
      );
    }

    return dio;
  }
}
