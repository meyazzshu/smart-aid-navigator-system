import 'package:dio/dio.dart';

import '../../core/dio_client.dart';
import '../../core/dio_error_handler.dart';
import 'shelter_request_models.dart';

class PpsSlotBookingApi {
  final Dio _authDio = DioClient.create();
  final Dio _guestDio = DioClient.create();

  /// Look up PPS requests by email or phone number.
  /// Returns a list of requests associated with the given contact.
  Future<ShelterRequestListResponse> lookupRequests({
    String? email,
    String? phone,
    int? requestId,
  }) async {
    final params = <String, dynamic>{};
    if (email != null && email.isNotEmpty) params['email'] = email;
    if (phone != null && phone.isNotEmpty) params['phone'] = phone;
    if (requestId != null) params['request_id'] = requestId;

    try {
      final res = await _guestDio.get(
        '/shelter-requests/lookup',
        queryParameters: params,
      );
      return ShelterRequestListResponse.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.message(e, fallback: 'Unable to check booking status.'));
    }
  }

  /// Fetch all PPS requests for the currently logged-in user.
  Future<ShelterRequestListResponse> getMyBookings() async {
    try {
      final res = await _authDio.get('/shelter-requests/my');
      return ShelterRequestListResponse.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.message(e, fallback: 'Unable to load your bookings.'));
    }
  }

  /// Submit a PPS slot request for authenticated users.
  Future<ShelterRequestMutationResponse> submitMyRequest({
    required int shelterId,
    required int babiesMale,
    required int babiesFemale,
    required int kidsMale,
    required int kidsFemale,
    required int adultMale,
    required int adultFemale,
    required int totalPeople,
  }) async {
    try {
      final res = await _authDio.post(
        '/shelter-requests',
        data: {
          'shelter_id': shelterId,
          'babies_male': babiesMale,
          'babies_female': babiesFemale,
          'kids_male': kidsMale,
          'kids_female': kidsFemale,
          'adult_male': adultMale,
          'adult_female': adultFemale,
          'total_people': totalPeople,
        },
      );
      return ShelterRequestMutationResponse.fromJson((res.data as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.message(e, fallback: 'Unable to submit your booking.'));
    }
  }

  /// Cancel a PPS slot booking by its request ID.
  Future<Map<String, dynamic>> cancelRequest(int requestId) async {
    try {
      final res = await _authDio.post('/shelter-requests/$requestId/cancel');
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.message(e, fallback: 'Unable to cancel booking.'));
    }
  }

  Future<Map<String, dynamic>> dischargeRequest(int requestId) async {
    try {
      final res = await _authDio.post(
        '/shelter-requests/$requestId/discharge',
      );

      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to discharge from shelter.',
        ),
      );
    }
  }

  Future<AccountAddressProfile?> getAccountAddressProfile() async {
    try {
      final res = await _authDio.get('/auth/me');
      final root = (res.data as Map).cast<String, dynamic>();
      final auth = _asMap(root['auth']) ?? const <String, dynamic>{};
      final user = _asMap(root['user']) ?? _asMap(auth['user']) ?? const <String, dynamic>{};
      final person = _asMap(root['person']) ??
          _asMap(user['person']) ??
          _asMap(auth['person']) ??
          const <String, dynamic>{};

      final addressLine = _toNullableString(person['address_line']) ?? _toNullableString(user['address_line']) ?? '';
      final city = _toNullableString(person['city']) ?? _toNullableString(user['city']) ?? '';
      final state = _toNullableString(person['state']) ?? _toNullableString(user['state']) ?? '';
      final postalCode = _toNullableString(person['postal_code']) ?? _toNullableString(user['postal_code']) ?? '';
      final latitude = _toDouble(person['latitude']) ?? _toDouble(user['latitude']);
      final longitude = _toDouble(person['longitude']) ?? _toDouble(user['longitude']);

      if (addressLine.isEmpty && city.isEmpty && state.isEmpty && postalCode.isEmpty && latitude == null && longitude == null) {
        return null;
      }
      return AccountAddressProfile(
        addressLine: addressLine,
        city: city,
        state: state,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
      );
    } on DioException {
      return null;
    }
  }

  Future<Map<String, dynamic>> registerRequestDependents({
    required int requestId,
    required List<DependentRegistrationPayload> dependents,
  }) async {
    try {
      final res = await _authDio.post(
        '/shelter-requests/$requestId/dependents',
        data: {
          'dependents': dependents.map((e) => e.toJson()).toList(),
        },
      );
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(DioErrorHandler.message(e, fallback: 'Unable to save dependents.'));
    }
  }

  Future<List<AccountDependent>> getMyDependents() async {
    try {
      return _fetchDependents('/dependents');
    } on DioException catch (e) {
      print('GET DEPENDENTS ERROR STATUS: ${e.response?.statusCode}');
      print('GET DEPENDENTS ERROR DATA: ${e.response?.data}');
      print('GET DEPENDENTS ERROR METHOD: ${e.requestOptions.method}');
      print('GET DEPENDENTS ERROR URL: ${e.requestOptions.uri}');

      throw Exception(
        DioErrorHandler.message(e, fallback: 'Unable to load dependents.'),
      );
    }
  }

  /// Fetches dependents from [path] and parses them into account-dependent models.
  Future<List<AccountDependent>> _fetchDependents(String path) async {
    final res = await _authDio.get(path);
    final raw = _extractDependentsList(res.data);
    if (raw == null) return const <AccountDependent>[];
    return raw
        .whereType<Map>()
        .map((e) => AccountDependent.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<AccountDependent> getDependentDetail(int dependentId) async {
    try {
      final res = await _authDio.get('/dependents/$dependentId');
      final root = (res.data as Map).cast<String, dynamic>();

      final raw = _asMap(root['dependent']) ??
          _asMap(root['data']) ??
          root;

      return AccountDependent.fromJson(raw);
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to load dependent details.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> updateMyDependent({
    required int dependentId,
    required DependentRegistrationPayload dependent,
    bool isActive = true,
  }) async {
    try {
      final data = dependent.toJson();
      data['is_active'] = isActive ? 1 : 0;

      final res = await _authDio.put(
        '/dependents/$dependentId',
        data: data,
      );

      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to update dependent.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> deactivateMyDependent(int dependentId) async {
    try {
      final res = await _authDio.patch('/dependents/$dependentId/deactivate');
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to delete dependent.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> registerMyDependent({
    required DependentRegistrationPayload dependent,
  }) async {
    try {
      final res = await _authDio.post(
        '/dependents',
        data: dependent.toJson(),
      );
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to save account dependent.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> registerMyDependents({
    required List<DependentRegistrationPayload> dependents,
  }) async {
    if (dependents.isEmpty) {
      throw Exception('Please add at least one dependent.');
    }

    Map<String, dynamic> lastResult = <String, dynamic>{};

    for (final dependent in dependents) {
      lastResult = await registerMyDependent(dependent: dependent);
    }

    return lastResult;
  }

  Future<Map<String, dynamic>> assignDependentsToRequest({
    required int requestId,
    required List<int> dependentIds,
  }) async {
    try {
      final res = await _authDio.post(
        '/shelter-requests/$requestId/dependents/assign',
        data: {
          'dependent_ids': dependentIds,
        },
      );
      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(e, fallback: 'Unable to assign dependents to booking.'),
      );
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String? _toNullableString(dynamic value) {
  if (value == null) return null;
  final result = value.toString().trim();
  return result.isEmpty ? null : result;
}

double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

/// Extracts a dependents list from top-level or nested response payload shapes.
List<dynamic>? _extractDependentsList(dynamic data) {
  if (data is List) return data;
  if (data is! Map) return null;
  final root = data.cast<String, dynamic>();

  final topLevel = _pickDependentsList(root);
  if (topLevel != null) return topLevel;

  final nestedDataMap = _asMap(root['data']);
  if (nestedDataMap != null) {
    final nested = _pickDependentsList(nestedDataMap);
    if (nested != null) return nested;
  }

  return null;
}

List<dynamic>? _pickDependentsList(Map<String, dynamic> map) {
  final candidates = [
    map['dependents'],
    map['data'],
    map['items'],
    map['dependent_list'],
    map['family_members'],
  ];
  for (final value in candidates) {
    if (value is List) return value;
  }
  return null;
}
