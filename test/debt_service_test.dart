import 'package:expense_tracker/models/debt.dart';
import 'package:expense_tracker/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('debt can be added, adjusted, persisted, and settled', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DatabaseService();
    await service.init();
    final now = DateTime(2026, 9, 7);

    await service.addDebt(
      Debt(
        id: 'debt-1',
        personName: 'An',
        direction: DebtDirection.owedToMe,
        createdAt: now,
        transactions: [
          DebtTransaction(id: 'initial', amount: 100000, createdAt: now),
        ],
      ),
    );
    await service.adjustDebt('debt-1', 50000);
    await service.adjustDebt('debt-1', -30000);

    expect(service.debts.single.balance, 120000);
    final restored = DatabaseService();
    await restored.init();
    expect(restored.debts.single.balance, 120000);

    await restored.settleDebt('debt-1');
    expect(restored.debts, isEmpty);
  });

  test('repayment is capped at the remaining balance', () async {
    SharedPreferences.setMockInitialValues({});
    final service = DatabaseService();
    await service.init();
    final now = DateTime(2026, 9, 7);
    await service.addDebt(
      Debt(
        id: 'debt-2',
        personName: 'Bình',
        direction: DebtDirection.iOwe,
        createdAt: now,
        transactions: [
          DebtTransaction(id: 'initial', amount: 50000, createdAt: now),
        ],
      ),
    );

    await service.adjustDebt('debt-2', -100000);
    expect(service.debts, isEmpty);
  });
}
