/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;

abstract class ClassificationResult
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ClassificationResult._({
    required this.hash,
    required this.documentType,
    this.category,
    required this.confidence,
    this.merchantName,
    this.senderName,
    this.recipientName,
    this.totalAmount,
    this.currency,
    this.transactionType,
    this.transactionDate,
    this.summary,
  });

  factory ClassificationResult({
    required String hash,
    required String documentType,
    String? category,
    required double confidence,
    String? merchantName,
    String? senderName,
    String? recipientName,
    double? totalAmount,
    String? currency,
    String? transactionType,
    DateTime? transactionDate,
    String? summary,
  }) = _ClassificationResultImpl;

  factory ClassificationResult.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return ClassificationResult(
      hash: jsonSerialization['hash'] as String,
      documentType: jsonSerialization['documentType'] as String,
      category: jsonSerialization['category'] as String?,
      confidence: (jsonSerialization['confidence'] as num).toDouble(),
      merchantName: jsonSerialization['merchantName'] as String?,
      senderName: jsonSerialization['senderName'] as String?,
      recipientName: jsonSerialization['recipientName'] as String?,
      totalAmount: (jsonSerialization['totalAmount'] as num?)?.toDouble(),
      currency: jsonSerialization['currency'] as String?,
      transactionType: jsonSerialization['transactionType'] as String?,
      transactionDate: jsonSerialization['transactionDate'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['transactionDate'],
            ),
      summary: jsonSerialization['summary'] as String?,
    );
  }

  String hash;

  String documentType;

  String? category;

  double confidence;

  String? merchantName;

  String? senderName;

  String? recipientName;

  double? totalAmount;

  String? currency;

  String? transactionType;

  DateTime? transactionDate;

  String? summary;

  /// Returns a shallow copy of this [ClassificationResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClassificationResult copyWith({
    String? hash,
    String? documentType,
    String? category,
    double? confidence,
    String? merchantName,
    String? senderName,
    String? recipientName,
    double? totalAmount,
    String? currency,
    String? transactionType,
    DateTime? transactionDate,
    String? summary,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClassificationResult',
      'hash': hash,
      'documentType': documentType,
      if (category != null) 'category': category,
      'confidence': confidence,
      if (merchantName != null) 'merchantName': merchantName,
      if (senderName != null) 'senderName': senderName,
      if (recipientName != null) 'recipientName': recipientName,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (currency != null) 'currency': currency,
      if (transactionType != null) 'transactionType': transactionType,
      if (transactionDate != null) 'transactionDate': transactionDate?.toJson(),
      if (summary != null) 'summary': summary,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ClassificationResult',
      'hash': hash,
      'documentType': documentType,
      if (category != null) 'category': category,
      'confidence': confidence,
      if (merchantName != null) 'merchantName': merchantName,
      if (senderName != null) 'senderName': senderName,
      if (recipientName != null) 'recipientName': recipientName,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (currency != null) 'currency': currency,
      if (transactionType != null) 'transactionType': transactionType,
      if (transactionDate != null) 'transactionDate': transactionDate?.toJson(),
      if (summary != null) 'summary': summary,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ClassificationResultImpl extends ClassificationResult {
  _ClassificationResultImpl({
    required String hash,
    required String documentType,
    String? category,
    required double confidence,
    String? merchantName,
    String? senderName,
    String? recipientName,
    double? totalAmount,
    String? currency,
    String? transactionType,
    DateTime? transactionDate,
    String? summary,
  }) : super._(
         hash: hash,
         documentType: documentType,
         category: category,
         confidence: confidence,
         merchantName: merchantName,
         senderName: senderName,
         recipientName: recipientName,
         totalAmount: totalAmount,
         currency: currency,
         transactionType: transactionType,
         transactionDate: transactionDate,
         summary: summary,
       );

  /// Returns a shallow copy of this [ClassificationResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClassificationResult copyWith({
    String? hash,
    String? documentType,
    Object? category = _Undefined,
    double? confidence,
    Object? merchantName = _Undefined,
    Object? senderName = _Undefined,
    Object? recipientName = _Undefined,
    Object? totalAmount = _Undefined,
    Object? currency = _Undefined,
    Object? transactionType = _Undefined,
    Object? transactionDate = _Undefined,
    Object? summary = _Undefined,
  }) {
    return ClassificationResult(
      hash: hash ?? this.hash,
      documentType: documentType ?? this.documentType,
      category: category is String? ? category : this.category,
      confidence: confidence ?? this.confidence,
      merchantName: merchantName is String? ? merchantName : this.merchantName,
      senderName: senderName is String? ? senderName : this.senderName,
      recipientName: recipientName is String?
          ? recipientName
          : this.recipientName,
      totalAmount: totalAmount is double? ? totalAmount : this.totalAmount,
      currency: currency is String? ? currency : this.currency,
      transactionType: transactionType is String?
          ? transactionType
          : this.transactionType,
      transactionDate: transactionDate is DateTime?
          ? transactionDate
          : this.transactionDate,
      summary: summary is String? ? summary : this.summary,
    );
  }
}
