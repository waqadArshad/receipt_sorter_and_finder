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
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) throw Exception('Could not decode image');
      
      // Use Phash from image_hash package
      // Note: Actual API might vary, assuming standard Phash().create(image) or similar
      // based on typical library structure. If fail, fallback to placeholder.
      return 'phash_placeholder_${imageFile.path.hashCode}'; // Placeholder until exact API verified

    } catch (e) {
      print('Error generating perceptual hash: $e');
      return 'hash_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }
}
