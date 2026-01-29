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
import '../classification/classification_result.dart' as _i2;
import 'package:receipt_backend_client/src/protocol/protocol.dart' as _i3;

abstract class BatchClassificationResponse implements _i1.SerializableModel {
  BatchClassificationResponse._({required this.results});

  factory BatchClassificationResponse({
    required List<_i2.ClassificationResult> results,
  }) = _BatchClassificationResponseImpl;

  factory BatchClassificationResponse.fromJson(
    Map<String, dynamic> jsonSerialization,
  ) {
    return BatchClassificationResponse(
      results: _i3.Protocol().deserialize<List<_i2.ClassificationResult>>(
        jsonSerialization['results'],
      ),
    );
  }

  List<_i2.ClassificationResult> results;

  /// Returns a shallow copy of this [BatchClassificationResponse]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  BatchClassificationResponse copyWith({
    List<_i2.ClassificationResult>? results,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'BatchClassificationResponse',
      'results': results.toJson(valueToJson: (v) => v.toJson()),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _BatchClassificationResponseImpl extends BatchClassificationResponse {
  _BatchClassificationResponseImpl({
    required List<_i2.ClassificationResult> results,
  }) : super._(results: results);

  /// Returns a shallow copy of this [BatchClassificationResponse]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  BatchClassificationResponse copyWith({
    List<_i2.ClassificationResult>? results,
  }) {
    return BatchClassificationResponse(
      results: results ?? this.results.map((e0) => e0.copyWith()).toList(),
    );
  }
}
