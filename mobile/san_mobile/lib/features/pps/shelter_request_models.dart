class ShelterRequestListResponse {
  final bool ok;
  final String? error;
  final String? message;
  final List<ShelterRequest> requests;

  const ShelterRequestListResponse({
    required this.ok,
    this.error,
    this.message,
    required this.requests,
  });

  factory ShelterRequestListResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['requests'];
    final list = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => ShelterRequest.fromJson(e.cast<String, dynamic>()))
            .toList()
        : <ShelterRequest>[];

    return ShelterRequestListResponse(
      ok: json['ok'] == true || json['success'] == true,
      error: _toNullableString(json['error']),
      message: _toNullableString(json['message']),
      requests: list,
    );
  }
}

class ShelterRequestMutationResponse {
  final bool ok;
  final String? error;
  final String? message;
  final int? requestId;
  final ShelterRequest? request;

  const ShelterRequestMutationResponse({
    required this.ok,
    this.error,
    this.message,
    this.requestId,
    this.request,
  });

  factory ShelterRequestMutationResponse.fromJson(Map<String, dynamic> json) {
    final requestMap = _asMap(json['request']) ?? _asMap(json['data']);
    final parsed = requestMap == null || !_looksLikeShelterRequest(requestMap)
        ? null
        : ShelterRequest.fromJson(requestMap);

    return ShelterRequestMutationResponse(
      ok: json['ok'] == true || json['success'] == true,
      error: _toNullableString(json['error']),
      message: _toNullableString(json['message']),
      requestId: _toInt(json['request_id']) ?? parsed?.requestId,
      request: parsed,
    );
  }
}

bool _looksLikeShelterRequest(Map<String, dynamic> json) {
  return json.containsKey('shelter_id') ||
      json.containsKey('request_id') ||
      json.containsKey('id');
}

class ShelterRequest {
  final int? requestId;
  final int? shelterId;
  final String shelterName;
  final String status;
  final String fullName;
  final String email;
  final String phone;
  final int babiesMale;
  final int babiesFemale;
  final int kidsMale;
  final int kidsFemale;
  final int adultMale;
  final int adultFemale;
  final int totalPeople;
  final String createdAtRaw;
  final bool isDischarged;
  final int dischargedCount;
  final List<DependentRecord> dependents;

  const ShelterRequest({
    this.requestId,
    this.shelterId,
    required this.shelterName,
    required this.status,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.babiesMale,
    required this.babiesFemale,
    required this.kidsMale,
    required this.kidsFemale,
    required this.adultMale,
    required this.adultFemale,
    required this.totalPeople,
    required this.createdAtRaw,
    required this.isDischarged,
    required this.dischargedCount,
    required this.dependents,
  });

  factory ShelterRequest.fromJson(Map<String, dynamic> json) {
    final user = _asMap(json['user']) ??
        _asMap(json['users']) ??
        _asMap(json['public_user']) ??
        _asMap(json['requester']) ??
        const <String, dynamic>{};
    final person = _asMap(json['person']) ??
        _asMap(user['person']) ??
        _asMap(json['requester_person']) ??
        const <String, dynamic>{};

    final babiesMale = _toInt(json['babies_male']) ?? 0;
    final babiesFemale = _toInt(json['babies_female']) ?? 0;
    final kidsMale = _toInt(json['kids_male']) ?? 0;
    final kidsFemale = _toInt(json['kids_female']) ?? 0;
    final adultMale = _toInt(json['adult_male']) ?? 0;
    final adultFemale = _toInt(json['adult_female']) ?? 0;
    final totalPeople = _toInt(json['total_people']) ??
        babiesMale +
            babiesFemale +
            kidsMale +
            kidsFemale +
            adultMale +
            adultFemale;
    final dependents = _parseDependents(json);

    final isDischarged =
        json['is_discharged'] == true ||
        json['is_discharged'] == 1 ||
        json['is_discharged']?.toString() == '1' ||
        json['discharge_status']?.toString().toUpperCase() == 'DISCHARGED';

    final dischargedCount = _toInt(json['discharged_count']) ?? 0;

    return ShelterRequest(
      requestId: _toInt(json['request_id']) ?? _toInt(json['id']),
      shelterId: _toInt(json['shelter_id']),
      shelterName: _toNullableString(json['shelter_name']) ??
          _toNullableString(json['pps_name']) ??
          '',
      status: _toNullableString(json['status']) ??
          _toNullableString(json['request_status']) ??
          'pending',
      fullName: _toNullableString(json['full_name']) ??
          _toNullableString(person['full_name']) ??
          _toNullableString(user['full_name']) ??
          '',
      email: _toNullableString(json['email']) ??
          _toNullableString(person['email']) ??
          _toNullableString(user['email']) ??
          '',
      phone: _toNullableString(json['phone']) ??
          _toNullableString(person['phone']) ??
          _toNullableString(user['phone']) ??
          '',
      babiesMale: babiesMale,
      babiesFemale: babiesFemale,
      kidsMale: kidsMale,
      kidsFemale: kidsFemale,
      adultMale: adultMale,
      adultFemale: adultFemale,
      totalPeople: totalPeople,
      createdAtRaw: _toNullableString(json['created_at']) ??
          _toNullableString(json['requested_at']) ??
          '',
      isDischarged: isDischarged,
      dischargedCount: dischargedCount,
      dependents: dependents,
    );
  }
}

class DependentRecord {
  final int? dependentId;
  final String fullName;
  final String relationshipType;
  final String icOrPassport;
  final String email;
  final String phone;
  final String gender;
  final String dateOfBirth;
  final String addressLine;
  final String city;
  final String state;
  final String postalCode;
  final double? latitude;
  final double? longitude;

  const DependentRecord({
    this.dependentId,
    required this.fullName,
    required this.relationshipType,
    required this.icOrPassport,
    required this.email,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.postalCode,
    this.latitude,
    this.longitude,
  });

  factory DependentRecord.fromJson(Map<String, dynamic> json) {
    final person = _asMap(json['person']) ?? const <String, dynamic>{};
    return DependentRecord(
      dependentId: _toInt(json['dependent_id']) ?? _toInt(json['person_id']) ?? _toInt(json['id']),
      fullName: _toNullableString(json['full_name']) ?? _toNullableString(person['full_name']) ?? '',
      relationshipType: _toNullableString(json['relationship_type']) ??
          _toNullableString(json['relationship']) ??
          'DEPENDENT',
      icOrPassport: _toNullableString(json['ic_or_passport']) ??
          _toNullableString(person['ic_or_passport']) ??
          '',
      email: _toNullableString(json['email']) ?? _toNullableString(person['email']) ?? '',
      phone: _toNullableString(json['phone']) ?? _toNullableString(person['phone']) ?? '',
      gender: _toNullableString(json['gender']) ?? _toNullableString(person['gender']) ?? '',
      dateOfBirth: _toNullableString(json['date_of_birth']) ??
          _toNullableString(person['date_of_birth']) ??
          '',
      addressLine: _toNullableString(json['address_line']) ??
          _toNullableString(person['address_line']) ??
          '',
      city: _toNullableString(json['city']) ?? _toNullableString(person['city']) ?? '',
      state: _toNullableString(json['state']) ?? _toNullableString(person['state']) ?? '',
      postalCode: _toNullableString(json['postal_code']) ?? _toNullableString(person['postal_code']) ?? '',
      latitude: _toDouble(json['latitude']) ?? _toDouble(person['latitude']),
      longitude: _toDouble(json['longitude']) ?? _toDouble(person['longitude']),
    );
  }
}

class DependentRegistrationPayload {
  final String fullName;
  final String relationshipType;
  final String icOrPassport;
  final String email;
  final String phone;
  final String gender;
  final String dateOfBirth;
  final String addressLine;
  final String city;
  final String state;
  final String postalCode;
  final double latitude;
  final double longitude;

  const DependentRegistrationPayload({
    required this.fullName,
    required this.relationshipType,
    required this.icOrPassport,
    required this.email,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'relationship_type': relationshipType,
        'ic_or_passport': icOrPassport,
        'email': email,
        'phone': phone,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'address_line': addressLine,
        'city': city,
        'state': state,
        'postal_code': postalCode,
        'latitude': latitude,
        'longitude': longitude,
      };
}

class AccountAddressProfile {
  final String addressLine;
  final String city;
  final String state;
  final String postalCode;
  final double? latitude;
  final double? longitude;

  const AccountAddressProfile({
    required this.addressLine,
    required this.city,
    required this.state,
    required this.postalCode,
    this.latitude,
    this.longitude,
  });

  bool get hasAddress =>
      addressLine.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      state.trim().isNotEmpty &&
      postalCode.trim().isNotEmpty;
}

class AccountDependent {
  final int? dependentId;
  final String fullName;
  final String relationshipType;
  final String icOrPassport;
  final String email;
  final String phone;
  final String gender;
  final String dateOfBirth;
  final String addressLine;
  final String city;
  final String state;
  final String postalCode;
  final double? latitude;
  final double? longitude;

  const AccountDependent({
    this.dependentId,
    required this.fullName,
    required this.relationshipType,
    required this.icOrPassport,
    required this.email,
    required this.phone,
    required this.gender,
    required this.dateOfBirth,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.postalCode,
    this.latitude,
    this.longitude,
  });

  factory AccountDependent.fromJson(Map<String, dynamic> json) {
    final person = _asMap(json['person']) ?? const <String, dynamic>{};
    return AccountDependent(
      dependentId:
          _toInt(json['relationship_id']) ??
          _toInt(json['dependent_id']) ??
          _toInt(json['id']) ??
          _toInt(json['person_id']),
      fullName: _toNullableString(json['full_name']) ?? _toNullableString(person['full_name']) ?? '',
      relationshipType: _toNullableString(json['relationship_type']) ??
          _toNullableString(json['relationship']) ??
          'DEPENDENT',
      icOrPassport: _toNullableString(json['ic_or_passport']) ??
          _toNullableString(person['ic_or_passport']) ??
          '',
      email: _toNullableString(json['email']) ?? _toNullableString(person['email']) ?? '',
      phone: _toNullableString(json['phone']) ?? _toNullableString(person['phone']) ?? '',
      gender: _toNullableString(json['gender']) ?? _toNullableString(person['gender']) ?? '',
      dateOfBirth: _toNullableString(json['date_of_birth']) ??
          _toNullableString(person['date_of_birth']) ??
          '',
      addressLine: _toNullableString(json['address_line']) ?? _toNullableString(person['address_line']) ?? '',
      city: _toNullableString(json['city']) ?? _toNullableString(person['city']) ?? '',
      state: _toNullableString(json['state']) ?? _toNullableString(person['state']) ?? '',
      postalCode: _toNullableString(json['postal_code']) ?? _toNullableString(person['postal_code']) ?? '',
      latitude: _toDouble(json['latitude']) ?? _toDouble(person['latitude']),
      longitude: _toDouble(json['longitude']) ?? _toDouble(person['longitude']),
    );
  }
}

List<DependentRecord> _parseDependents(Map<String, dynamic> json) {
  final raw = json['dependents'] ?? json['dependent_list'] ?? json['family_members'];
  if (raw is! List) return const <DependentRecord>[];
  return raw
      .whereType<Map>()
      .map((e) => DependentRecord.fromJson(e.cast<String, dynamic>()))
      .toList();
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
