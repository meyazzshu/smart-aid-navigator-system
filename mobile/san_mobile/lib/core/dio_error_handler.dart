import 'package:dio/dio.dart';

class DioErrorHandler {
  static String message(
    DioException error, {
    String fallback = 'Request failed. Please try again.',
  }) {
    final backendMessage = _extractBackendMessage(error.response?.data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Network timeout. Please check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'Network error. Please check your internet connection and try again.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (backendMessage != null && backendMessage.isNotEmpty) {
          return backendMessage;
        }
        if (status == 400) {
          return 'Bad request. Please check your input and try again.';
        }
        if (status == 401) {
          return 'Unauthorized. Please login again.';
        }
        if (status == 500) {
          return 'Server error. Please try again later.';
        }
        return status != null ? 'Request failed (HTTP $status).' : fallback;
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return backendMessage ?? fallback;
    }
  }

  static String? _extractBackendMessage(dynamic data) {
    if (data is Map) {
      final map = data.cast<String, dynamic>();
      final message = map['message'] ?? map['error'];
      if (message != null) return message.toString();
    }
    if (data is String && data.trim().isNotEmpty) return data;
    return null;
  }
}
