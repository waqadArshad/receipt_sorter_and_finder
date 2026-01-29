import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OCRService {
  static final OCRService _instance = OCRService._internal();
  factory OCRService() => _instance;
  OCRService._internal();

  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isClosed = false;

  /// Extracts text from the given image file using Google ML Kit.
  /// Returns the raw string of text found.
  Future<String> extractText(File imageFile) async {
    if (_isClosed) {
      throw StateError('OCRService has been closed');
    }

    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR Error for ${imageFile.path}: $e');
      // Rethrow or return empty depending on strategy. 
      // Rethrowing allows the pipeline to handle the failure status.
      rethrow; 
    }
  }

  /// Closes the underlying ML Kit recognizer to release resources.
  Future<void> close() async {
    await _textRecognizer.close();
    _isClosed = true;
  }
}
