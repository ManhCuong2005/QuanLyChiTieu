import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/receipt_result.dart';
import 'receipt_parser.dart';
import 'web_ocr_stub.dart' if (dart.library.html) 'web_ocr.dart' as web_ocr;

/// Runs OCR recognition and receipt heuristic extraction.
class OcrService {
  static Future<ReceiptResult> processReceiptFromPath(String imagePath) async {
    String recognizedText = '';

    if (!kIsWeb) {
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final result = await textRecognizer.processImage(inputImage);
        recognizedText = result.text;
      } catch (error) {
        debugPrint('Google ML Kit error: $error');
        throw Exception('ML Kit không thể đọc ảnh hóa đơn: $error');
      } finally {
        await textRecognizer.close();
      }
    } else {
      recognizedText = await web_ocr.recognizeReceiptImage(imagePath);
    }

    if (recognizedText.trim().isEmpty) {
      throw Exception(
        'Không nhận diện được chữ trong ảnh. Hãy chụp rõ hơn và thử lại.',
      );
    }
    return ReceiptParser.parse(recognizedText);
  }

  static ReceiptResult processReceiptText(String text) {
    return ReceiptParser.parse(text);
  }
}
