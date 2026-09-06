import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/services/database_service.dart';

void main() {
  testWidgets('ExpenseTrackerApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final dbService = DatabaseService();
    await dbService.init();

    await tester.pumpWidget(
      ExpenseTrackerApp(
        databaseService: dbService,
        autoCheckForUpdates: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Quản Lý Chi Tiêu OCR'), findsOneWidget);
    expect(find.text('Quét Hóa Đơn (OCR)'), findsOneWidget);
  });
}
