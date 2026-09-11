import 'package:dio/dio.dart';

import '../../core/dio_client.dart';
import '../../core/dio_error_handler.dart';

class BeneficiaryNeedsApi {
  final Dio _dio = DioClient.create();

  Future<BeneficiaryStatusResult> getMyBeneficiaryStatus() async {
    try {
      final res = await _dio.get('/beneficiary-needs/my-status');
      return BeneficiaryStatusResult.fromJson(
        (res.data as Map).cast<String, dynamic>(),
      );
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to check beneficiary status.',
        ),
      );
    }
  }

  Future<List<BeneficiaryNeedRequest>> getMyNeeds() async {
    try {
      final res = await _dio.get('/beneficiary-needs/my');
      final root = (res.data as Map).cast<String, dynamic>();

      final raw = root['needs'];
      if (raw is! List) return [];

      return raw
          .whereType<Map>()
          .map((e) => BeneficiaryNeedRequest.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to load your aid requests.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> submitNeed({
    required int itemId,
    required int requiredQuantity,
    required String priority,
    String? notes,
  }) async {
    try {
      final res = await _dio.post(
        '/beneficiary-needs',
        data: {
          'item_id': itemId,
          'required_quantity': requiredQuantity,
          'priority': priority,
          'notes': notes ?? '',
        },
      );

      return (res.data as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to submit aid request.',
        ),
      );
    }
  }

  Future<List<AidItemOption>> getAidItems() async {
    try {
      final res = await _dio.get('/items');
      final root = (res.data as Map).cast<String, dynamic>();

      final raw = root['items'];
      if (raw is! List) return [];

      return raw
          .whereType<Map>()
          .map((e) => AidItemOption.fromJson(e.cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw Exception(
        DioErrorHandler.message(
          e,
          fallback: 'Unable to load aid items.',
        ),
      );
    }
  }
}

class BeneficiaryStatusResult {
  final bool ok;
  final bool isBeneficiary;
  final ActiveBeneficiary? beneficiary;
  final String? error;

  const BeneficiaryStatusResult({
    required this.ok,
    required this.isBeneficiary,
    this.beneficiary,
    this.error,
  });

  factory BeneficiaryStatusResult.fromJson(Map<String, dynamic> json) {
    final beneficiaryMap = _asMap(json['beneficiary']);

    return BeneficiaryStatusResult(
      ok: json['ok'] == true,
      isBeneficiary: json['is_beneficiary'] == true,
      beneficiary: beneficiaryMap == null
          ? null
          : ActiveBeneficiary.fromJson(beneficiaryMap),
      error: _toNullableString(json['error']),
    );
  }
}

class ActiveBeneficiary {
  final int beneficiaryId;
  final int shelterId;
  final String fullName;
  final String shelterName;

  const ActiveBeneficiary({
    required this.beneficiaryId,
    required this.shelterId,
    required this.fullName,
    required this.shelterName,
  });

  factory ActiveBeneficiary.fromJson(Map<String, dynamic> json) {
    return ActiveBeneficiary(
      beneficiaryId: _toInt(json['beneficiary_id']) ?? 0,
      shelterId: _toInt(json['shelter_id']) ?? 0,
      fullName: _toNullableString(json['full_name']) ?? '',
      shelterName: _toNullableString(json['shelter_name']) ?? '',
    );
  }
}

class BeneficiaryNeedRequest {
  final int needId;
  final int itemId;
  final String itemName;
  final String unit;
  final String categoryName;
  final int requiredQuantity;
  final String priority;
  final String requestStatus;
  final String notes;
  final String rejectionReason;
  final String createdAt;
  final String reviewedAt;
  final String fulfilledAt;
  final String shelterName;

  const BeneficiaryNeedRequest({
    required this.needId,
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.categoryName,
    required this.requiredQuantity,
    required this.priority,
    required this.requestStatus,
    required this.notes,
    required this.rejectionReason,
    required this.createdAt,
    required this.reviewedAt,
    required this.fulfilledAt,
    required this.shelterName,
  });

  factory BeneficiaryNeedRequest.fromJson(Map<String, dynamic> json) {
    return BeneficiaryNeedRequest(
      needId: _toInt(json['need_id']) ?? 0,
      itemId: _toInt(json['item_id']) ?? 0,
      itemName: _toNullableString(json['item_name']) ?? '',
      unit: _toNullableString(json['unit']) ?? '',
      categoryName: _toNullableString(json['category_name']) ?? '',
      requiredQuantity: _toInt(json['required_quantity']) ?? 0,
      priority: _toNullableString(json['priority']) ?? 'MEDIUM',
      requestStatus: _toNullableString(json['request_status']) ?? 'SUBMITTED',
      notes: _toNullableString(json['notes']) ?? '',
      rejectionReason: _toNullableString(json['rejection_reason']) ?? '',
      createdAt: _toNullableString(json['created_at']) ?? '',
      reviewedAt: _toNullableString(json['reviewed_at']) ?? '',
      fulfilledAt: _toNullableString(json['fulfilled_at']) ?? '',
      shelterName: _toNullableString(json['shelter_name']) ?? '',
    );
  }
}

class AidItemOption {
  final int itemId;
  final String itemName;
  final String unit;
  final String categoryName;

  const AidItemOption({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.categoryName,
  });

  factory AidItemOption.fromJson(Map<String, dynamic> json) {
    return AidItemOption(
      itemId: _toInt(json['item_id']) ?? 0,
      itemName: _toNullableString(json['item_name']) ?? '',
      unit: _toNullableString(json['unit']) ?? '',
      categoryName: _toNullableString(json['category_name']) ?? '',
    );
  }

  String get label => '$itemName ($unit)';
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