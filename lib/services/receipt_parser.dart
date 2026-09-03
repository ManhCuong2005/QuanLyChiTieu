import '../models/receipt_result.dart';
import '../models/category.dart';

/// Heuristic Regex Engine for parsing raw OCR text from receipts.
/// Implements Learning Objective 3:
/// Extract monetary totals, merchant names, and transaction dates.
class ReceiptParser {
  /// Parse raw OCR text into a structured [ReceiptResult]
  static ReceiptResult parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const ReceiptResult(rawText: '', lines: []);
    }

    final rawLines = rawText.split(RegExp(r'\r?\n'));
    final cleanedLines = rawLines
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final merchantName = _extractMerchant(cleanedLines);
    final transactionDate = _extractDate(cleanedLines);
    final totalAmount = _extractTotalAmount(cleanedLines);
    final suggestedCategory = _suggestCategory(merchantName, cleanedLines);

    double confidence = 0.4;
    if (merchantName != null) confidence += 0.2;
    if (transactionDate != null) confidence += 0.2;
    if (totalAmount != null && totalAmount > 0) confidence += 0.2;

    return ReceiptResult(
      totalAmount: totalAmount,
      merchantName: merchantName,
      transactionDate: transactionDate,
      suggestedCategory: suggestedCategory,
      rawText: rawText,
      lines: cleanedLines,
      confidenceScore: confidence.clamp(0.0, 1.0),
    );
  }

  /// 1. Extract Merchant / Store Name using Heuristics
  static String? _extractMerchant(List<String> lines) {
    // Known brands / chain stores database for high accuracy matching
    final knownChains = [
      'Highlands Coffee',
      'The Coffee House',
      'Phúc Long',
      'Starbucks',
      'Trung Nguyên',
      'WinMart+',
      'WinMart',
      'Circle K',
      'FamilyMart',
      '7-Eleven',
      'Bách Hóa Xanh',
      'Co.opmart',
      'Big C',
      'GO!',
      'Lotte Mart',
      'Aeon Mall',
      'KFC',
      'Lotteria',
      'Jollibee',
      'McDonald\'s',
      'Pizza Hut',
      'The Pizza Company',
      'Domino\'s Pizza',
      'Pharmacity',
      'Nhà Thuốc Long Châu',
      'Fahasa',
      'Nhà Sách Phương Nam',
      'Petrolimex',
    ];

    // Check first 8 lines for exact or substring matches of known chains
    final checkLimit = lines.length > 8 ? 8 : lines.length;
    for (int i = 0; i < checkLimit; i++) {
      final line = lines[i];
      for (final chain in knownChains) {
        if (line.toLowerCase().contains(chain.toLowerCase())) {
          return chain;
        }
      }
    }

    // Heuristic: Search for lines containing store prefix keywords
    final storePrefixes = [
      RegExp(r'^(công ty|cty|doanh nghiệp|cửa hàng|siêu thị|quán|nhà hàng|tiệm|store|coffee|cafe|mart|shop)\s*[:\-]?\s*(.+)', caseSensitive: false),
    ];

    for (int i = 0; i < checkLimit; i++) {
      final line = lines[i];
      for (final prefix in storePrefixes) {
        final match = prefix.firstMatch(line);
        if (match != null && match.group(2) != null) {
          final candidate = match.group(2)!.trim();
          if (candidate.length > 2) return candidate;
        }
      }
    }

    // Filter out common header meta lines (Tax code, invoice title, address, phone)
    final ignoreKeywords = [
      'hóa đơn', 'hoa don', 'receipt', 'invoice', 'phiếu', 'thanh toán',
      'vat', 'mst', 'mã số thuế', 'địa chỉ', 'address', 'tel', 'phone',
      'sđt', 'hotline', 'wifi', 'welcome', 'xin chào', 'cảm ơn', 'thank you',
      'bàn:', 'thu ngân:', 'order:', 'khách hàng:'
    ];

    for (int i = 0; i < checkLimit; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      bool shouldIgnore = false;
      for (final kw in ignoreKeywords) {
        if (lower.contains(kw)) {
          shouldIgnore = true;
          break;
        }
      }

      // Must have letters and at least 3 chars
      if (!shouldIgnore && RegExp(r'[a-zA-ZÀ-ỹ]{3,}').hasMatch(line)) {
        // Clean special chars at beginning or end
        final cleaned = line.replaceAll(RegExp(r'^[\s\*\-\#\:\.]+|[\s\*\-\#\:\.]+$'), '');
        if (cleaned.length >= 3 && cleaned.length <= 45) {
          return cleaned;
        }
      }
    }

    return null;
  }

  /// 2. Extract Transaction Date & Time using Regex
  static DateTime? _extractDate(List<String> lines) {
    // Regex formats:
    // dd/MM/yyyy, dd-MM-yyyy, dd.MM.yyyy, yyyy-MM-dd, yyyy/MM/dd, dd/MM/yy
    final datePatterns = [
      // 24/12/2024 or 24-12-2024 or 24.12.2024 (optional time HH:mm)
      RegExp(r'\b(?<day>[0-3]?[0-9])[\/\-\.](?<month>[0-1]?[0-9])[\/\-\.](?<year>20\d{2}|\d{2})\b'),
      // 2024-12-24 or 2024/12/24
      RegExp(r'\b(?<year>20\d{2})[\/\-\.](?<month>[0-1]?[0-9])[\/\-\.](?<day>[0-3]?[0-9])\b'),
    ];

    for (final line in lines) {
      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          try {
            int day = int.parse(match.namedGroup('day')!);
            int month = int.parse(match.namedGroup('month')!);
            int year = int.parse(match.namedGroup('year')!);

            // Handle 2-digit years (e.g., 24 -> 2024)
            if (year < 100) year += 2000;

            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              // Try to find accompanying time (e.g., 14:30:00 or 14:30)
              final timeMatch = RegExp(r'\b(?<hour>[0-2]?[0-9]):(?<minute>[0-5][0-9])(?::(?<second>[0-5][0-9]))?\b')
                  .firstMatch(line);

              int hour = 12;
              int minute = 0;
              int second = 0;

              if (timeMatch != null) {
                hour = int.parse(timeMatch.namedGroup('hour')!).clamp(0, 23);
                minute = int.parse(timeMatch.namedGroup('minute')!).clamp(0, 59);
                if (timeMatch.namedGroup('second') != null) {
                  second = int.parse(timeMatch.namedGroup('second')!).clamp(0, 59);
                }
              }

              return DateTime(year, month, day, hour, minute, second);
            }
          } catch (_) {
            // Continue search if parsing fails
          }
        }
      }
    }

    return null;
  }

  /// 3. Extract Monetary Total using Heuristic Scoring & Regex
  static double? _extractTotalAmount(List<String> lines) {
    // Regex identifying numbers with thousand separators and possible currency
    // e.g. 125,000 | 125.000 | 125000 | 1,250,000 VND | 50.000 đ
    final amountPattern = RegExp(
      r'(?:(?:\b|\$|đ|₫|vnd|vnđ)\s*)?(?<num>\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d{4,9})(?:\s*(?:đ|₫|vnd|vnđ|k|\$))?\b',
      caseSensitive: false,
    );

    // High confidence keywords for grand total
    final totalKeywords = [
      'tổng cộng', 'tong cong', 'tổng tiền', 'tong tien', 'thành tiền', 'thanh tien',
      'thanh toán', 'thanh toan', 'thực trả', 'thuc tra', 'khách phải trả',
      'cộng tiền hàng', 'tổng thanh toán', 'total', 'grand total', 'amount due',
      'balance due', 'net amount', 'total bill'
    ];

    // Penalty keywords (discounts, tax, cash tendered, change returned)
    final penaltyKeywords = [
      'tiền khách đưa', 'khách đưa', 'tien khach dua', 'tiền mặt', 'cash',
      'tiền thối', 'tiền thừa', 'tien thoi', 'tien thua', 'change',
      'vat', 'thuế', 'thue', 'chiết khấu', 'chiet khau', 'giảm giá', 'discount',
      'điểm tích lũy', 'phí dịch vụ'
    ];

    double bestAmount = 0.0;
    int bestScore = -1;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lowerLine = line.toLowerCase();

      // Check if line contains total keywords
      bool isTotalLine = false;
      for (final kw in totalKeywords) {
        if (lowerLine.contains(kw)) {
          isTotalLine = true;
          break;
        }
      }

      // Check if line contains penalty keywords
      bool isPenaltyLine = false;
      for (final kw in penaltyKeywords) {
        if (lowerLine.contains(kw)) {
          isPenaltyLine = true;
          break;
        }
      }

      // Look for amount matches in this line, and if none, in the immediate next line
      final matches = amountPattern.allMatches(line).toList();
      List<RegExpMatch> candidateMatches = matches;
      bool isNextLine = false;

      if (matches.isEmpty && isTotalLine && i + 1 < lines.length) {
        // Value might be on the next line
        candidateMatches = amountPattern.allMatches(lines[i + 1]).toList();
        isNextLine = true;
      }

      for (final m in candidateMatches) {
        final numStr = m.namedGroup('num');
        if (numStr == null) continue;

        final parsed = _parseNumber(numStr);
        if (parsed == null || parsed < 1000) continue; // Minimum reasonable expense

        int score = 10;
        if (isTotalLine) score += 100;
        if (isNextLine) score += 40;
        if (isPenaltyLine) score -= 80;

        // Position bias: total is usually in the second half of the receipt
        if (i > lines.length * 0.4) score += 25;

        // Realistic currency ranges (10k to 50 million VND)
        if (parsed >= 10000 && parsed <= 50000000) score += 15;

        if (score > bestScore) {
          bestScore = score;
          bestAmount = parsed;
        } else if (score == bestScore && parsed > bestAmount) {
          // In tie cases, total is usually the largest number on total lines
          bestAmount = parsed;
        }
      }
    }

    if (bestAmount > 0) return bestAmount;

    // Fallback: If no keyword lines found, pick largest plausible number on bottom half
    double fallbackMax = 0;
    for (int i = (lines.length / 2).floor(); i < lines.length; i++) {
      for (final m in amountPattern.allMatches(lines[i])) {
        final numStr = m.namedGroup('num');
        if (numStr != null) {
          final parsed = _parseNumber(numStr);
          if (parsed != null && parsed >= 5000 && parsed > fallbackMax && parsed < 100000000) {
            fallbackMax = parsed;
          }
        }
      }
    }

    return fallbackMax > 0 ? fallbackMax : null;
  }

  /// Clean number string and convert to double
  static double? _parseNumber(String raw) {
    try {
      // Remove all currency symbols and letters
      String cleaned = raw.replaceAll(RegExp(r'[^0-9.,]'), '');

      // Check if dots and commas are present
      final dotCount = '.'.allMatches(cleaned).length;
      final commaCount = ','.allMatches(cleaned).length;

      if (dotCount > 0 && commaCount == 0) {
        // e.g. 150.000 -> Vietnamese thousand separators
        if (dotCount == 1 && cleaned.split('.').last.length <= 2) {
          // Decimal like 15.50
          return double.tryParse(cleaned);
        } else {
          // Thousand separator: 150.000 -> 150000
          return double.tryParse(cleaned.replaceAll('.', ''));
        }
      } else if (commaCount > 0 && dotCount == 0) {
        // e.g. 150,000 -> English thousand separator
        if (commaCount == 1 && cleaned.split(',').last.length <= 2) {
          // Decimal in some locales
          return double.tryParse(cleaned.replaceAll(',', '.'));
        } else {
          // Thousand separator: 150,000 -> 150000
          return double.tryParse(cleaned.replaceAll(',', ''));
        }
      } else if (dotCount > 0 && commaCount > 0) {
        // Mixed: 1.250.000,50 or 1,250,000.50
        final lastDot = cleaned.lastIndexOf('.');
        final lastComma = cleaned.lastIndexOf(',');
        if (lastDot > lastComma) {
          // 1,250.00 -> comma is thousand, dot is decimal
          cleaned = cleaned.replaceAll(',', '');
          return double.tryParse(cleaned);
        } else {
          // 1.250,00 -> dot is thousand, comma is decimal
          cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
          return double.tryParse(cleaned);
        }
      } else {
        // Plain digits: 150000
        return double.tryParse(cleaned);
      }
    } catch (_) {
      return null;
    }
  }

  /// 4. Auto-suggest Category based on Merchant Name and Receipt Text
  static String _suggestCategory(String? merchant, List<String> lines) {
    final fullText = '${merchant ?? ''} ${lines.join(' ')}'.toLowerCase();

    // 1. Food (Ăn uống)
    if (_containsAny(fullText, [
      'coffee', 'cafe', 'cà phê', 'tea', 'trà', 'restaurant', 'nhà hàng', 'quán',
      'bánh', 'food', 'kfc', 'lotteria', 'jollibee', 'pizza', 'phở', 'bún', 'cơm',
      'lẩu', 'nướng', 'bbq', 'gà rán', 'mì', 'chè', 'highlands', 'starbucks',
      'phúc long', 'bánh mì'
    ])) {
      return ExpenseCategory.food.id;
    }

    // 2. Study (Học tập)
    if (_containsAny(fullText, [
      'fahasa', 'phương nam', 'nhà sách', 'sách', 'khóa học', 'học phí',
      'đại học', 'trường', 'văn phòng phẩm', 'giáo trình', 'bút', 'vở'
    ])) {
      return ExpenseCategory.study.id;
    }

    // 3. Travel (Di chuyển)
    if (_containsAny(fullText, [
      'xăng', 'petrolimex', 'petrol', 'grab', 'be', 'gojek', 'taxi', 'mai linh',
      'giao hàng', 'ship', 'bus', 'vé xe', 'vé máy bay', 'parking', 'giữ xe'
    ])) {
      return ExpenseCategory.travel.id;
    }

    // 4. Gear (Thiết bị & Đồ dùng)
    if (_containsAny(fullText, [
      'mart', 'siêu thị', 'store', 'shop', 'winmart', 'circle k', 'familymart',
      '7-eleven', 'bách hóa xanh', 'co.opmart', 'big c', 'lotte', 'quần áo',
      'thời trang', 'zara', 'uniqlo', 'thiết bị', 'điện tử', 'gear', 'chuột',
      'tai nghe', 'phụ kiện', 'pharmacity', 'tiện ích', 'đồ dùng'
    ])) {
      return ExpenseCategory.gear.id;
    }

    // 5. Entertainment (Giải trí)
    if (_containsAny(fullText, [
      'cinema', 'cgv', 'bhd', 'lotte cinema', 'game', 'rạp chiếu phim', 'karaoke',
      'billiards', 'vé xem phim', 'tour', 'du lịch'
    ])) {
      return ExpenseCategory.entertainment.id;
    }

    return ExpenseCategory.other.id;
  }

  static bool _containsAny(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}
