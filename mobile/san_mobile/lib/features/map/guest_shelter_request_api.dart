import 'package:dio/dio.dart';

import '../../core/dio_client.dart';
import '../../core/dio_error_handler.dart';
import '../pps/shelter_request_models.dart';

class GuestShelterRequestApi {
  final Dio _authDio = DioClient.create();
  final Dio _guestDio = DioClient.create();

  Future<ShelterRequestMutationResponse> submitGuestRequest({
    required int shelterId,
    required String fullName,
    required String email,
    required String phone,
    required int babiesMale,
    required int babiesFemale,
    required int kidsMale,
    required int kidsFemale,
    required int adultMale,
    required int adultFemale,
    required int totalPeople,
  }) async {
    try {
      final res = await _guestDio.post('/shelter-requests/guest', data: {
        'shelter_id': shelterId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'babies_male': babiesMale,
        'babies_female': babiesFemale,
        'kids_male': kidsMale,
        'kids_female': kidsFemale,
        'adult_male': adultMale,
        'adult_female': adultFemale,
        'total_people': totalPeople,
      });
      return ShelterRequestMutationResponse.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.message(e, fallback: 'Unable to submit guest booking.'));
    }
  }

  Future<Map<String, dynamic>> claimGuestRequest({
    int? requestId,
    required String email,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
    };
    if (requestId != null) {
      payload['request_id'] = requestId;
    }
    try {
      final res = await _authDio.post('/shelter-requests/claim', data: payload);
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.message(e, fallback: 'Unable to confirm guest request.'));
    }
  }
}
