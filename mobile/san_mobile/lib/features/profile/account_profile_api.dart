import 'package:dio/dio.dart';

import '../../core/dio_client.dart';
import '../../core/dio_error_handler.dart';

class AccountProfile {
  final int userId;
  final int personId;
  final String fullName;
  final String icOrPassport;
  final String email;
  final String phone;
  final String role;
  final String gender;
  final String dateOfBirth;
  final String addressLine;
  final String city;
  final String state;
  final String postalCode;
  final String updatedAt;
  final Map<String, dynamic>? organization;

  const AccountProfile({
    required this.userId,
    required this.personId,
    required this.fullName,
    required this.icOrPassport,
    required this.email,
    required this.phone,
    required this.role,
    required this.gender,
    required this.dateOfBirth,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.updatedAt,
    required this.organization,
  });

  String get displayRole {
    switch (role) {
      case 'NGO_STAFF':
        return 'NGO Staff';
      case 'SHELTER_MANAGER':
        return 'Shelter Manager';
      case 'ADMIN':
        return 'Administrator';
      case 'PUBLIC':
        return 'Public User';
      default:
        return role.isEmpty ? 'User' : role;
    }
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  bool get isComplete {
    return fullName.trim().isNotEmpty &&
        phone.trim().isNotEmpty &&
        gender.trim().isNotEmpty &&
        addressLine.trim().isNotEmpty &&
        city.trim().isNotEmpty &&
        state.trim().isNotEmpty &&
        postalCode.trim().isNotEmpty;
  }

  int get completionPercent {
    final fields = [
      fullName,
      icOrPassport,
      email,
      phone,
      gender,
      dateOfBirth,
      addressLine,
      city,
      state,
      postalCode,
    ];

    final filled = fields.where((x) => x.trim().isNotEmpty).length;
    return ((filled / fields.length) * 100).round();
  }

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    return AccountProfile(
      userId: _toInt(json['user_id']) ?? 0,
      personId: _toInt(json['person_id']) ?? 0,
      fullName: _s(json['full_name']),
      icOrPassport: _s(json['ic_or_passport']),
      email: _s(json['email']),
      phone: _s(json['phone']),
      role: _s(json['role']),
      gender: _normaliseGender(_s(json['gender'])),
      dateOfBirth: _s(json['date_of_birth']),
      addressLine: _s(json['address_line']),
      city: _s(json['city']),
      state: _s(json['state']),
      postalCode: _s(json['postal_code']),
      updatedAt: _s(json['updated_at']),
      organization: _asMap(json['organization']),
    );
  }
}

class AccountProfileLookups {
  final List<LookupOption> genders;
  final List<String> states;
  final List<String> cities;

  const AccountProfileLookups({
    required this.genders,
    required this.states,
    required this.cities,
  });

  factory AccountProfileLookups.fromJson(Map<String, dynamic> json) {
    final lookups = _asMap(json['lookups']) ?? const <String, dynamic>{};

    final gendersRaw = (lookups['genders'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => LookupOption.fromJson(e.cast<String, dynamic>()))
        .toList();

    final states = (lookups['states'] as List? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    final cities = (lookups['cities'] as List? ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return AccountProfileLookups(
      genders: gendersRaw.isEmpty
          ? const [
              LookupOption(value: 'MALE', label: 'Male'),
              LookupOption(value: 'FEMALE', label: 'Female'),
              LookupOption(value: 'OTHER', label: 'Other'),
            ]
          : gendersRaw,
      states: states,
      cities: cities,
    );
  }
}

class LookupOption {
  final String value;
  final String label;

  const LookupOption({
    required this.value,
    required this.label,
  });

  factory LookupOption.fromJson(Map<String, dynamic> json) {
    return LookupOption(
      value: _s(json['value']),
      label: _s(json['label']),
    );
  }
}

class AccountProfileApi {
  final Dio _dio = DioClient.create();

  Future<AccountProfile> getMyProfile() async {
    try {
      final res = await _dio.get('/profile/me');
      final root = (res.data as Map).cast<String, dynamic>();
      final profile = _asMap(root['profile']) ?? const <String, dynamic>{};
      return AccountProfile.fromJson(profile);
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to load your profile.',
        ),
      );
    }
  }

  Future<AccountProfileLookups> getLookups() async {
    try {
      final res = await _dio.get('/profile/lookups');
      final root = (res.data as Map).cast<String, dynamic>();
      return AccountProfileLookups.fromJson(root);
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to load profile dropdowns.',
        ),
      );
    }
  }

  Future<void> updateMyProfile({
    required String fullName,
    required String icOrPassport,
    required String phone,
    required String gender,
    required String dateOfBirth,
    required String addressLine,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'ic_or_passport': icOrPassport,
      'phone': phone,
      'gender': gender,
      'date_of_birth': dateOfBirth,
      'address_line': addressLine,
      'city': city,
      'state': state,
      'postal_code': postalCode,
    };

    try {
      await _dio.patch('/profile/me', data: payload);
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to update your profile.',
        ),
      );
    }
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return value.cast<String, dynamic>();
  return null;
}

String _s(dynamic value) {
  if (value == null) return '';
  return value.toString();
}

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _normaliseGender(String value) {
  final upper = value.trim().toUpperCase();
  if (upper == 'MALE' || upper == 'M') return 'MALE';
  if (upper == 'FEMALE' || upper == 'F') return 'FEMALE';
  if (upper == 'OTHER') return 'OTHER';
  return upper;
}