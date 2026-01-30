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
import 'package:serverpod_client/serverpod_client.dart' as _i1;

abstract class Receipt implements _i1.SerializableModel {
  Receipt._({
    this.id,
    this.userId,
    required this.filePath,
    required this.metadataHash,
    this.assetId,
    this.ocrText,
    this.documentType,
    this.category,
    this.merchantName,
    this.senderName,
    this.recipientName,
    this.totalAmount,
    this.currency,
    this.transactionType,
    this.transactionDate,
    required this.processedAt,
    required this.processingStatus,
  });

  factory Receipt({
    int? id,
    int? userId,
    required String filePath,
    required String metadataHash,
    String? assetId,
    String? ocrText,
    String? documentType,
    String? category,
    String? merchantName,
    String? senderName,
    String? recipientName,
    double? totalAmount,
    String? currency,
    String? transactionType,
    DateTime? transactionDate,
    required DateTime processedAt,
    required String processingStatus,
  }) = _ReceiptImpl;

  factory Receipt.fromJson(Map<String, dynamic> jsonSerialization) {
    return Receipt(
      id: jsonSerialization['id'] as int?,
      userId: jsonSerialization['userId'] as int?,
      filePath: jsonSerialization['filePath'] as String,
      metadataHash: jsonSerialization['metadataHash'] as String,
      assetId: jsonSerialization['assetId'] as String?,
      ocrText: jsonSerialization['ocrText'] as String?,
      documentType: jsonSerialization['documentType'] as String?,
      category: jsonSerialization['category'] as String?,
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
      processedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['processedAt'],
      ),
      processingStatus: jsonSerialization['processingStatus'] as String,
    );
  }

  /// The database id, set if the object has been inserted into the
  /// database or if it has been fetched from the database. Otherwise,
  /// the id will be null.
  int? id;

  int? userId;

  String filePath;

  String metadataHash;

  String? assetId;

  String? ocrText;

  String? documentType;

  String? category;

  String? merchantName;

  String? senderName;

  String? recipientName;

  double? totalAmount;

  String? currency;

  String? transactionType;

  DateTime? transactionDate;

  DateTime processedAt;

  String processingStatus;

  /// Returns a shallow copy of this [Receipt]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  Receipt copyWith({
    int? id,
    int? userId,
    String? filePath,
    String? metadataHash,
    String? assetId,
    String? ocrText,
    String? documentType,
    String? category,
    String? merchantName,
    String? senderName,
    String? recipientName,
    double? totalAmount,
    String? currency,
    String? transactionType,
    DateTime? transactionDate,
    DateTime? processedAt,
    String? processingStatus,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'Receipt',
      if (id != null) 'id': id,
      if (userId != null) 'userId': userId,
      'filePath': filePath,
      'metadataHash': metadataHash,
      if (assetId != null) 'assetId': assetId,
      if (ocrText != null) 'ocrText': ocrText,
      if (documentType != null) 'documentType': documentType,
      if (category != null) 'category': category,
      if (merchantName != null) 'merchantName': merchantName,
      if (senderName != null) 'senderName': senderName,
      if (recipientName != null) 'recipientName': recipientName,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (currency != null) 'currency': currency,
      if (transactionType != null) 'transactionType': transactionType,
      if (transactionDate != null) 'transactionDate': transactionDate?.toJson(),
      'processedAt': processedAt.toJson(),
      'processingStatus': processingStatus,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _ReceiptImpl extends Receipt {
  _ReceiptImpl({
    int? id,
    int? userId,
    required String filePath,
    required String metadataHash,
    String? assetId,
    String? ocrText,
    String? documentType,
    String? category,
    String? merchantName,
    String? senderName,
    String? recipientName,
    double? totalAmount,
    String? currency,
    String? transactionType,
    DateTime? transactionDate,
    required DateTime processedAt,
    required String processingStatus,
  }) : super._(
         id: id,
         userId: userId,
         filePath: filePath,
         metadataHash: metadataHash,
         assetId: assetId,
         ocrText: ocrText,
         documentType: documentType,
         category: category,
         merchantName: merchantName,
         senderName: senderName,
         recipientName: recipientName,
         totalAmount: totalAmount,
         currency: currency,
         transactionType: transactionType,
         transactionDate: transactionDate,
         processedAt: processedAt,
         processingStatus: processingStatus,
       );

  /// Returns a shallow copy of this [Receipt]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  Receipt copyWith({
    Object? id = _Undefined,
    Object? userId = _Undefined,
    String? filePath,
    String? metadataHash,
    Object? assetId = _Undefined,
    Object? ocrText = _Undefined,
    Object? documentType = _Undefined,
    Object? category = _Undefined,
    Object? merchantName = _Undefined,
    Object? senderName = _Undefined,
    Object? recipientName = _Undefined,
    Object? totalAmount = _Undefined,
    Object? currency = _Undefined,
    Object? transactionType = _Undefined,
    Object? transactionDate = _Undefined,
    DateTime? processedAt,
    String? processingStatus,
  }) {
    return Receipt(
      id: id is int? ? id : this.id,
      userId: userId is int? ? userId : this.userId,
      filePath: filePath ?? this.filePath,
      metadataHash: metadataHash ?? this.metadataHash,
      assetId: assetId is String? ? assetId : this.assetId,
      ocrText: ocrText is String? ? ocrText : this.ocrText,
      documentType: documentType is String? ? documentType : this.documentType,
      category: category is String? ? category : this.category,
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
      processedAt: processedAt ?? this.processedAt,
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }
}
