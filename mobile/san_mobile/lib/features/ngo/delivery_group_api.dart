import 'package:dio/dio.dart';

import '../../core/dio_client.dart';

class DeliveryGroupApi {
  final Dio _dio = DioClient.create();

  Future<List<Map<String, dynamic>>> getGroups() async {
    final res = await _dio.get(
      '/deliveries/groups',
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    final data = (res.data as Map).cast<String, dynamic>();

    if (res.statusCode != null && res.statusCode! >= 400) {
      throw Exception(
        '${data['error'] ?? 'Failed to load delivery groups'}\nDetails: ${data['details'] ?? data['hint'] ?? '-'}',
      );
    }

    final list = (data['groups'] as List? ?? []).cast<dynamic>();
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> getDetail(int groupId) async {
    final res = await _dio.get(
      '/deliveries/groups/$groupId',
      options: Options(
        validateStatus: (status) => status != null && status < 600,
      ),
    );

    final data = (res.data as Map).cast<String, dynamic>();

    if (res.statusCode != null && res.statusCode! >= 400) {
      throw Exception(
        '${data['error'] ?? 'Failed to load delivery group'}\nDetails: ${data['details'] ?? data['hint'] ?? '-'}',
      );
    }

    return data;
  }

  Future<Map<String, dynamic>> optimize({
    required int groupId,
    required double currentLat,
    required double currentLng,
  }) async {
    try {
      final res = await _dio.post(
        '/deliveries/groups/$groupId/optimize',
        data: {
          'current_lat': currentLat,
          'current_lng': currentLng,
        },
        options: Options(
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      final rawData = res.data;

      if (rawData is! Map) {
        throw Exception('Unexpected API response: $rawData');
      }

      final data = rawData.cast<String, dynamic>();

      if (res.statusCode != null && res.statusCode! >= 400) {
        throw Exception(
          '${data['error'] ?? 'Failed to optimize route'}\n'
          'Details: ${data['details'] ?? '-'}\n'
          'Hint: ${data['hint'] ?? '-'}',
        );
      }

      if (data['ok'] != true) {
        throw Exception(data['error'] ?? 'Failed to optimize route');
      }

      return data;
    } on DioException catch (e) {
      final responseData = e.response?.data;

      throw Exception(
        'Dio failed during optimize.\n'
        'Status: ${e.response?.statusCode}\n'
        'Response: $responseData\n'
        'Message: ${e.message}',
      );
    }
  }
}