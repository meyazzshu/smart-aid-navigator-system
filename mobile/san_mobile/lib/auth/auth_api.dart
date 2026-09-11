import 'package:dio/dio.dart';
import '../core/dio_client.dart';

class AuthApi {
  final Dio _dio = DioClient.create(attachAuthToken: false);

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> registerPublic({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final res = await _dio.post('/auth/register', data: {
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'password': password,
      'is_guest': 0,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return (res.data as Map).cast<String, dynamic>();
  }
}
