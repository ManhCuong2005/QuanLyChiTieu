import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/receipt_parser.dart';
import 'package:expense_tracker/models/category.dart';

void main() {
  group('ReceiptParser Tests', () {
    test('Correctly parses Highlands Coffee receipt', () {
      const sampleHighlands = '''
HIGHLANDS COFFEE
Dia chi: 123 Nguyen Trai, Q.1, TP.HCM
Ngay: 15/03/2025 09:30
Thu ngan: Nguyen Van A

1  Phin Sua Da (L)       39.000
1  Tra Sen Vang (M)      45.000
1  Banh Mi Thit Nuong    25.000

Cong tien hang:         109.000
VAT (10%):               10.900
Tong cong:              119.900
Tien khach dua:         200.000
Tien thoi:               80.100

Cam on quy khach & Hen gap lai!
''';

      final result = ReceiptParser.parse(sampleHighlands);

      expect(result.merchantName, 'Highlands Coffee');
      expect(result.totalAmount, 119900.0);
      expect(result.transactionDate, isNotNull);
      expect(result.transactionDate!.year, 2025);
      expect(result.transactionDate!.month, 3);
      expect(result.transactionDate!.day, 15);
      expect(result.transactionDate!.hour, 9);
      expect(result.transactionDate!.minute, 30);
      expect(result.suggestedCategory, ExpenseCategory.food.id);
    });

    test('Correctly parses WinMart supermarket receipt', () {
      const sampleWinMart = '''
SIEU THI WINMART+
Cty CP Dich Vu Thuong Mai Tong Hop VinCommerce
Ngay GD: 2024-11-20 18:45:12
Hoa Don: #WM98421

Sua tuoi TH True Milk 1L     36.000
Banh mi sandwich             22.000
Nuoc ngot Coca Cola 1.5L     20.000
Tao Envy My 1kg              95.000

Tong tien:                  173.000 VND
Khach phai tra:             173.000
Tien mat:                   200.000
Tien thua:                   27.000
''';

      final result = ReceiptParser.parse(sampleWinMart);

      expect(result.merchantName, 'WinMart+');
      expect(result.totalAmount, 173000.0);
      expect(result.transactionDate, isNotNull);
      expect(result.transactionDate!.year, 2024);
      expect(result.transactionDate!.month, 11);
      expect(result.transactionDate!.day, 20);
      expect(result.suggestedCategory, ExpenseCategory.shopping.id);
    });

    test('Correctly parses Circle K convenience store receipt', () {
      const sampleCircleK = '''
CIRCLE K VIET NAM
Cua Hang: Circle K Tran Hung Dao
Date: 05/01/2025 22:15
Order #1024

Mi xao Bo                    25.000
Nuoc tang luc Redbull        15.000

Total:                       40.000 đ
Payment: Cash
Thank you for shopping!
''';

      final result = ReceiptParser.parse(sampleCircleK);

      expect(result.merchantName, 'Circle K');
      expect(result.totalAmount, 40000.0);
      expect(result.transactionDate, isNotNull);
      expect(result.suggestedCategory, ExpenseCategory.shopping.id);
    });
  });
}
