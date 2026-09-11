import 'package:dio/dio.dart';
import '../../core/dio_client.dart';

class DashboardApi {
  final Dio _dio = DioClient.create();

  Future<Map<String, dynamic>> fetchPublicDashboard() async {
    final res = await _dio.get('/dashboard/public');
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> fetchNgoDashboard() async {
    final res = await _dio.get('/dashboard/ngo');
    return (res.data as Map).cast<String, dynamic>();
  }
}
