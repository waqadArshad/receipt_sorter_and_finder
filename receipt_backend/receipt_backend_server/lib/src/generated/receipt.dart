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

abstract class Receipt
    implements _i1.TableRow<int?>, _i1.ProtocolSerialization {
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

  static final t = ReceiptTable();

  static const db = ReceiptRepository._();

  @override
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

  @override
  _i1.Table<int?> get table => t;

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
  Map<String, dynamic> toJsonForProtocol() {
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

  static ReceiptInclude include() {
    return ReceiptInclude._();
  }

  static ReceiptIncludeList includeList({
    _i1.WhereExpressionBuilder<ReceiptTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ReceiptTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ReceiptTable>? orderByList,
    ReceiptInclude? include,
  }) {
    return ReceiptIncludeList._(
      where: where,
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Receipt.t),
      orderDescending: orderDescending,
      orderByList: orderByList?.call(Receipt.t),
      include: include,
    );
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

class ReceiptUpdateTable extends _i1.UpdateTable<ReceiptTable> {
  ReceiptUpdateTable(super.table);

  _i1.ColumnValue<int, int> userId(int? value) => _i1.ColumnValue(
    table.userId,
    value,
  );

  _i1.ColumnValue<String, String> filePath(String value) => _i1.ColumnValue(
    table.filePath,
    value,
  );

  _i1.ColumnValue<String, String> metadataHash(String value) => _i1.ColumnValue(
    table.metadataHash,
    value,
  );

  _i1.ColumnValue<String, String> assetId(String? value) => _i1.ColumnValue(
    table.assetId,
    value,
  );

  _i1.ColumnValue<String, String> ocrText(String? value) => _i1.ColumnValue(
    table.ocrText,
    value,
  );

  _i1.ColumnValue<String, String> documentType(String? value) =>
      _i1.ColumnValue(
        table.documentType,
        value,
      );

  _i1.ColumnValue<String, String> category(String? value) => _i1.ColumnValue(
    table.category,
    value,
  );

  _i1.ColumnValue<String, String> merchantName(String? value) =>
      _i1.ColumnValue(
        table.merchantName,
        value,
      );

  _i1.ColumnValue<String, String> senderName(String? value) => _i1.ColumnValue(
    table.senderName,
    value,
  );

  _i1.ColumnValue<String, String> recipientName(String? value) =>
      _i1.ColumnValue(
        table.recipientName,
        value,
      );

  _i1.ColumnValue<double, double> totalAmount(double? value) => _i1.ColumnValue(
    table.totalAmount,
    value,
  );

  _i1.ColumnValue<String, String> currency(String? value) => _i1.ColumnValue(
    table.currency,
    value,
  );

  _i1.ColumnValue<String, String> transactionType(String? value) =>
      _i1.ColumnValue(
        table.transactionType,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> transactionDate(DateTime? value) =>
      _i1.ColumnValue(
        table.transactionDate,
        value,
      );

  _i1.ColumnValue<DateTime, DateTime> processedAt(DateTime value) =>
      _i1.ColumnValue(
        table.processedAt,
        value,
      );

  _i1.ColumnValue<String, String> processingStatus(String value) =>
      _i1.ColumnValue(
        table.processingStatus,
        value,
      );
}

class ReceiptTable extends _i1.Table<int?> {
  ReceiptTable({super.tableRelation}) : super(tableName: 'receipts') {
    updateTable = ReceiptUpdateTable(this);
    userId = _i1.ColumnInt(
      'userId',
      this,
    );
    filePath = _i1.ColumnString(
      'filePath',
      this,
    );
    metadataHash = _i1.ColumnString(
      'metadataHash',
      this,
    );
    assetId = _i1.ColumnString(
      'assetId',
      this,
    );
    ocrText = _i1.ColumnString(
      'ocrText',
      this,
    );
    documentType = _i1.ColumnString(
      'documentType',
      this,
    );
    category = _i1.ColumnString(
      'category',
      this,
    );
    merchantName = _i1.ColumnString(
      'merchantName',
      this,
    );
    senderName = _i1.ColumnString(
      'senderName',
      this,
    );
    recipientName = _i1.ColumnString(
      'recipientName',
      this,
    );
    totalAmount = _i1.ColumnDouble(
      'totalAmount',
      this,
    );
    currency = _i1.ColumnString(
      'currency',
      this,
    );
    transactionType = _i1.ColumnString(
      'transactionType',
      this,
    );
    transactionDate = _i1.ColumnDateTime(
      'transactionDate',
      this,
    );
    processedAt = _i1.ColumnDateTime(
      'processedAt',
      this,
    );
    processingStatus = _i1.ColumnString(
      'processingStatus',
      this,
    );
  }

  late final ReceiptUpdateTable updateTable;

  late final _i1.ColumnInt userId;

  late final _i1.ColumnString filePath;

  late final _i1.ColumnString metadataHash;

  late final _i1.ColumnString assetId;

  late final _i1.ColumnString ocrText;

  late final _i1.ColumnString documentType;

  late final _i1.ColumnString category;

  late final _i1.ColumnString merchantName;

  late final _i1.ColumnString senderName;

  late final _i1.ColumnString recipientName;

  late final _i1.ColumnDouble totalAmount;

  late final _i1.ColumnString currency;

  late final _i1.ColumnString transactionType;

  late final _i1.ColumnDateTime transactionDate;

  late final _i1.ColumnDateTime processedAt;

  late final _i1.ColumnString processingStatus;

  @override
  List<_i1.Column> get columns => [
    id,
    userId,
    filePath,
    metadataHash,
    assetId,
    ocrText,
    documentType,
    category,
    merchantName,
    senderName,
    recipientName,
    totalAmount,
    currency,
    transactionType,
    transactionDate,
    processedAt,
    processingStatus,
  ];
}

class ReceiptInclude extends _i1.IncludeObject {
  ReceiptInclude._();

  @override
  Map<String, _i1.Include?> get includes => {};

  @override
  _i1.Table<int?> get table => Receipt.t;
}

class ReceiptIncludeList extends _i1.IncludeList {
  ReceiptIncludeList._({
    _i1.WhereExpressionBuilder<ReceiptTable>? where,
    super.limit,
    super.offset,
    super.orderBy,
    super.orderDescending,
    super.orderByList,
    super.include,
  }) {
    super.where = where?.call(Receipt.t);
  }

  @override
  Map<String, _i1.Include?> get includes => include?.includes ?? {};

  @override
  _i1.Table<int?> get table => Receipt.t;
}

class ReceiptRepository {
  const ReceiptRepository._();

  /// Returns a list of [Receipt]s matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order of the items use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// The maximum number of items can be set by [limit]. If no limit is set,
  /// all items matching the query will be returned.
  ///
  /// [offset] defines how many items to skip, after which [limit] (or all)
  /// items are read from the database.
  ///
  /// ```dart
  /// var persons = await Persons.db.find(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.firstName,
  ///   limit: 100,
  /// );
  /// ```
  Future<List<Receipt>> find(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ReceiptTable>? where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ReceiptTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ReceiptTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.find<Receipt>(
      where: where?.call(Receipt.t),
      orderBy: orderBy?.call(Receipt.t),
      orderByList: orderByList?.call(Receipt.t),
      orderDescending: orderDescending,
      limit: limit,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Returns the first matching [Receipt] matching the given query parameters.
  ///
  /// Use [where] to specify which items to include in the return value.
  /// If none is specified, all items will be returned.
  ///
  /// To specify the order use [orderBy] or [orderByList]
  /// when sorting by multiple columns.
  ///
  /// [offset] defines how many items to skip, after which the next one will be picked.
  ///
  /// ```dart
  /// var youngestPerson = await Persons.db.findFirstRow(
  ///   session,
  ///   where: (t) => t.lastName.equals('Jones'),
  ///   orderBy: (t) => t.age,
  /// );
  /// ```
  Future<Receipt?> findFirstRow(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ReceiptTable>? where,
    int? offset,
    _i1.OrderByBuilder<ReceiptTable>? orderBy,
    bool orderDescending = false,
    _i1.OrderByListBuilder<ReceiptTable>? orderByList,
    _i1.Transaction? transaction,
  }) async {
    return session.db.findFirstRow<Receipt>(
      where: where?.call(Receipt.t),
      orderBy: orderBy?.call(Receipt.t),
      orderByList: orderByList?.call(Receipt.t),
      orderDescending: orderDescending,
      offset: offset,
      transaction: transaction,
    );
  }

  /// Finds a single [Receipt] by its [id] or null if no such row exists.
  Future<Receipt?> findById(
    _i1.Session session,
    int id, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.findById<Receipt>(
      id,
      transaction: transaction,
    );
  }

  /// Inserts all [Receipt]s in the list and returns the inserted rows.
  ///
  /// The returned [Receipt]s will have their `id` fields set.
  ///
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// insert, none of the rows will be inserted.
  Future<List<Receipt>> insert(
    _i1.Session session,
    List<Receipt> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insert<Receipt>(
      rows,
      transaction: transaction,
    );
  }

  /// Inserts a single [Receipt] and returns the inserted row.
  ///
  /// The returned [Receipt] will have its `id` field set.
  Future<Receipt> insertRow(
    _i1.Session session,
    Receipt row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.insertRow<Receipt>(
      row,
      transaction: transaction,
    );
  }

  /// Updates all [Receipt]s in the list and returns the updated rows. If
  /// [columns] is provided, only those columns will be updated. Defaults to
  /// all columns.
  /// This is an atomic operation, meaning that if one of the rows fails to
  /// update, none of the rows will be updated.
  Future<List<Receipt>> update(
    _i1.Session session,
    List<Receipt> rows, {
    _i1.ColumnSelections<ReceiptTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.update<Receipt>(
      rows,
      columns: columns?.call(Receipt.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Receipt]. The row needs to have its id set.
  /// Optionally, a list of [columns] can be provided to only update those
  /// columns. Defaults to all columns.
  Future<Receipt> updateRow(
    _i1.Session session,
    Receipt row, {
    _i1.ColumnSelections<ReceiptTable>? columns,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateRow<Receipt>(
      row,
      columns: columns?.call(Receipt.t),
      transaction: transaction,
    );
  }

  /// Updates a single [Receipt] by its [id] with the specified [columnValues].
  /// Returns the updated row or null if no row with the given id exists.
  Future<Receipt?> updateById(
    _i1.Session session,
    int id, {
    required _i1.ColumnValueListBuilder<ReceiptUpdateTable> columnValues,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateById<Receipt>(
      id,
      columnValues: columnValues(Receipt.t.updateTable),
      transaction: transaction,
    );
  }

  /// Updates all [Receipt]s matching the [where] expression with the specified [columnValues].
  /// Returns the list of updated rows.
  Future<List<Receipt>> updateWhere(
    _i1.Session session, {
    required _i1.ColumnValueListBuilder<ReceiptUpdateTable> columnValues,
    required _i1.WhereExpressionBuilder<ReceiptTable> where,
    int? limit,
    int? offset,
    _i1.OrderByBuilder<ReceiptTable>? orderBy,
    _i1.OrderByListBuilder<ReceiptTable>? orderByList,
    bool orderDescending = false,
    _i1.Transaction? transaction,
  }) async {
    return session.db.updateWhere<Receipt>(
      columnValues: columnValues(Receipt.t.updateTable),
      where: where(Receipt.t),
      limit: limit,
      offset: offset,
      orderBy: orderBy?.call(Receipt.t),
      orderByList: orderByList?.call(Receipt.t),
      orderDescending: orderDescending,
      transaction: transaction,
    );
  }

  /// Deletes all [Receipt]s in the list and returns the deleted rows.
  /// This is an atomic operation, meaning that if one of the rows fail to
  /// be deleted, none of the rows will be deleted.
  Future<List<Receipt>> delete(
    _i1.Session session,
    List<Receipt> rows, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.delete<Receipt>(
      rows,
      transaction: transaction,
    );
  }

  /// Deletes a single [Receipt].
  Future<Receipt> deleteRow(
    _i1.Session session,
    Receipt row, {
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteRow<Receipt>(
      row,
      transaction: transaction,
    );
  }

  /// Deletes all rows matching the [where] expression.
  Future<List<Receipt>> deleteWhere(
    _i1.Session session, {
    required _i1.WhereExpressionBuilder<ReceiptTable> where,
    _i1.Transaction? transaction,
  }) async {
    return session.db.deleteWhere<Receipt>(
      where: where(Receipt.t),
      transaction: transaction,
    );
  }

  /// Counts the number of rows matching the [where] expression. If omitted,
  /// will return the count of all rows in the table.
  Future<int> count(
    _i1.Session session, {
    _i1.WhereExpressionBuilder<ReceiptTable>? where,
    int? limit,
    _i1.Transaction? transaction,
  }) async {
    return session.db.count<Receipt>(
      where: where?.call(Receipt.t),
      limit: limit,
      transaction: transaction,
    );
  }
}
