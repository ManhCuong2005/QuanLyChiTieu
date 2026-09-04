import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'receipt_parser.dart';
import '../models/receipt_result.dart';
import 'web_ocr_stub.dart' if (dart.library.html) 'web_ocr.dart' as web_ocr;

/// Service responsible for running OCR recognition and receipt heuristic extraction.
/// Uses Google ML Kit Text Recognition for on-device offline parsing on Mobile,
/// with cross-platform fallback for Web Live Demo.
class OcrService {
  /// Recognize text from an image file path and extract receipt data
  static Future<ReceiptResult> processReceiptFromPath(String imagePath) async {
    String recognizedText = '';

    if (!kIsWeb) {
      // 1. Mobile (Android/iOS): Use Google ML Kit Text Recognition
      final textRecognizer = TextRecognizer(
        script: TextRecognitionScript.latin,
      );
      try {
        final inputImage = InputImage.fromFilePath(imagePath);
        final RecognizedText mlKitResult = await textRecognizer.processImage(
          inputImage,
        );
        recognizedText = mlKitResult.text;
      } catch (e) {
        debugPrint('Google ML Kit error: $e');
        throw Exception('ML Kit không thể đọc ảnh hóa đơn: $e');
      } finally {
        await textRecognizer.close();
      }
    } else {
      // 2. Web/PWA: run Tesseract WebAssembly locally in the browser.
      recognizedText = await web_ocr.recognizeReceiptImage(imagePath);
    }

    if (recognizedText.trim().isEmpty) {
      throw Exception(
        'Không nhận diện được chữ trong ảnh. Hãy chụp rõ hơn và thử lại.',
      );
    }

    // Run Regex Heuristic Engine
    return ReceiptParser.parse(recognizedText);
  }

  /// Process receipt directly from pre-defined or custom text
  static ReceiptResult processReceiptText(String text) {
    return ReceiptParser.parse(text);
  }

  /// Pre-built sample receipts for testing and presentation
  static final List<Map<String, String>> sampleReceipts = [
    {
      'title': 'Highlands Coffee (Đồ uống & Bánh)',
      'store': 'Highlands Coffee',
      'text': '''
HIGHLANDS COFFEE
Dia chi: Vincom Dong Khoi, Q.1
Ngay: 28/02/2025 15:30
Hoa don: #HL8392

1 Freeze Tra Xanh (L)    55.000
1 Phin Sua Da (M)        35.000
1 Banh Pho Mai Ca Phe    29.000

Tong tien:              119.000 đ
Khach phai tra:         119.000 đ
Tien mat:               200.000 đ
Tien thoi:               81.000 đ
''',
    },
    {
      'title': 'WinMart+ (Siêu thị tiêu dùng)',
      'store': 'WinMart+',
      'text': '''
SIEU THI WINMART+
Cty CP Thuong Mai VinCommerce
Ngay GD: 01/03/2025 19:20
So HD: #WM49201

Sua tuoi TH True Milk 1L     36.000
Banh mi sandwich             22.000
Nuoc ngot Coca Cola 1.5L     20.000
Tao Envy My 1kg              95.000

Tong cong:                  173.000 VND
Thanh toan the:             173.000 VND
Cam on Quy khach!
''',
    },
    {
      'title': 'Circle K (Cửa hàng tiện lợi)',
      'store': 'Circle K',
      'text': '''
CIRCLE K VIET NAM
Cua hang: Tran Hung Dao
Date: 02/03/2025 21:40

Mi tron trung xuc xich       32.000
Nuoc khoang Lavie 500ml       8.000

Total:                       40.000 VND
Cash:                        50.000 VND
Change:                      10.000 VND
''',
    },
    {
      'title': 'Nha Thuoc Pharmacity (Y tế / Sức khỏe)',
      'store': 'Pharmacity',
      'text': '''
NHA THUOC PHARMACITY
Dia chi: 45 Le Loi, Q.1
Ngay: 25/02/2025 11:15

Panadol Extra (Vi 10v)       28.000
Khau trang y te 4D           45.000
Nuoc muoi sinh ly 500ml      12.000

Tong tien:                   85.000 đ
Thanh toan MoMo:             85.000 đ
''',
    },
    {
      'title': 'Nha Sach Fahasa (Học tập & Sách)',
      'store': 'Fahasa',
      'text': '''
NHA SACH FAHASA
Chi nhanh Nguyen Hue
Ngay: 20/02/2025 16:50

Sach Dac Nhan Tam            86.000
So tay ghi chep A5           45.000
But gel bi xanh (Hop 12c)    60.000

Tong thanh toan:            191.000 VND
Thuc tra:                   191.000 VND
''',
    },
  ];
}
