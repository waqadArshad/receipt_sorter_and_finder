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

abstract class ClassificationTask
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  ClassificationTask._({
    required this.hash,
    required this.ocrText,
  });

  factory ClassificationTask({
    required String hash,
    required String ocrText,
  }) = _ClassificationTaskImpl;

  factory ClassificationTask.fromJson(Map<String, dynamic> jsonSerialization) {
    return ClassificationTask(
      hash: jsonSerialization['hash'] as String,
      ocrText: jsonSerialization['ocrText'] as String,
    );
  }

  String hash;

  String ocrText;

  /// Returns a shallow copy of this [ClassificationTask]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  ClassificationTask copyWith({
    String? hash,
    String? ocrText,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'ClassificationTask',
      'hash': hash,
      'ocrText': ocrText,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'ClassificationTask',
      'hash': hash,
      'ocrText': ocrText,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _ClassificationTaskImpl extends ClassificationTask {
  _ClassificationTaskImpl({
    required String hash,
    required String ocrText,
  }) : super._(
         hash: hash,
         ocrText: ocrText,
       );

  /// Returns a shallow copy of this [ClassificationTask]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  ClassificationTask copyWith({
    String? hash,
    String? ocrText,
  }) {
    return ClassificationTask(
      hash: hash ?? this.hash,
      ocrText: ocrText ?? this.ocrText,
    );
  }
}
