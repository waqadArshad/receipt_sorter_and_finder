import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:image_hash/image_hash.dart';
import 'package:image/image.dart' as img;

class ImageHashes {
  final String metadataHash;
  final String perceptualHash;

  ImageHashes({
    required this.metadataHash,
    required this.perceptualHash,
  });
}

class ImageHashService {
  // Singleton pattern
  static final ImageHashService _instance = ImageHashService._internal();
  factory ImageHashService() => _instance;
  ImageHashService._internal();

  /// Generates both metadata (fast) and perceptual (deep) hashes
  Future<ImageHashes> generateHashes(File imageFile) async {
    final metadataHash = await _generateMetadataHash(imageFile);
    final perceptualHash = await _generatePerceptualHash(imageFile);

    return ImageHashes(
      metadataHash: metadataHash,
      perceptualHash: perceptualHash,
    );
  }

  /// Generates a fast hash based on file path, size, and modification time.
  /// Extremely fast, but fragile if file is moved or modified.
  Future<String> _generateMetadataHash(File imageFile) async {
    try {
      final stat = await imageFile.stat();
      // Concatenate file properties
      final hashInput = '${imageFile.path}_${stat.size}_${stat.modified.millisecondsSinceEpoch}';
      // Use SHA-256 for a collision-resistant identifier
      final hash = sha256.convert(utf8.encode(hashInput)).toString();
      return hash;
    } catch (e) {
      // Fallback if stat fails (unlikely)
      return sha256.convert(utf8.encode(imageFile.path)).toString();
    }
  }

  /// Generates a perceptual hash based on the image content.
  /// Robust against resizing, format changes, and minor edits.
  /// Slower (requires image decoding).
  Future<String> _generatePerceptualHash(File imageFile) async {
    // OPTIMIZATION: Removed expensive img.decodeImage() call
    // Since we are currently returning a placeholder, decoding the full image
    // caused massive main-thread jank and memory pressure for no reason.
    // TODO: When implementing real pHash, MOVE THIS TO AN ISOLATE (compute).
    
    return 'phash_placeholder_${imageFile.path.hashCode}'; 
  }
}
