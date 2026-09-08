import 'package:expense_tracker/screens/debts_screen.dart';
import 'package:expense_tracker/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('adding and adjusting a debt closes sheets without exceptions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = DatabaseService();
    await service.init();
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: service,
          builder: (_, __) => DebtsScreen(databaseService: service),
        ),
      ),
    );

    await tester.tap(find.text('Thêm khoản nợ'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Tên người'), 'An');
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '100000');
    await tester.enterText(
      find.widgetWithText(TextField, 'Ghi chú (không bắt buộc)'),
      'Tiền ăn trưa',
    );
    await tester.tap(find.text('Lưu khoản nợ'));
    await tester.pumpAndSettle();

    expect(find.text('An'), findsOneWidget);
    expect(find.text('Tiền ăn trưa'), findsNothing);
    expect(service.debts.single.transactions.single.note, 'Tiền ăn trưa');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mượn thêm'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '50000');
    await tester.tap(find.text('Cộng vào khoản nợ'));
    await tester.pumpAndSettle();

    expect(service.debts.single.balance, 150000);
    expect(tester.takeException(), isNull);
  });
}
