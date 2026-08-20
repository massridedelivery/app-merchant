import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/finance/data/finance_repository.dart';
import 'package:merchant_app/features/finance/models/finance.dart';
import 'package:merchant_app/features/finance/presentation/screens/withdraw_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A repo with a healthy, withdrawable balance so the confirm CTA is enabled.
class _FakeFinanceRepository extends FinanceRepository {
  _FakeFinanceRepository() : super(ApiClient());

  @override
  Future<FinanceSummary> fetchSummary() async => FinanceSummary(
        balance: 2500,
        availableBalance: 2500,
        pendingWithdrawal: 0,
        lifetimeEarnings: 9000,
        totalWithdrawn: 6500,
        canWithdraw: true,
      );

  @override
  Future<List<WithdrawalRequest>> fetchWithdrawals() async => [];

  @override
  Future<void> requestWithdrawal(double amount) async {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
      'entering an amount and confirming opens the breakdown bottom sheet',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider
              .overrideWithValue(_FakeFinanceRepository()),
        ],
        child: const MaterialApp(home: WithdrawScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The available balance loaded from the fake summary.
    expect(find.text('฿2500.00'), findsOneWidget);

    // Enter a valid amount; the live net hint appears immediately.
    await tester.enterText(find.byType(TextField), '500');
    await tester.pumpAndSettle();
    expect(find.textContaining('ยอดที่จะได้รับ ฿500.00'), findsOneWidget);

    // Tap the confirm CTA -> the confirmation bottom sheet appears.
    await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันการถอนเงิน'));
    await tester.pumpAndSettle();

    // The sheet shows the fee/net breakdown and the destination account.
    expect(find.text('ยอดที่ขอถอน'), findsOneWidget);
    expect(find.text('ค่าธรรมเนียม'), findsOneWidget);
    expect(find.text('ฟรี'), findsOneWidget);
    expect(find.text('ยอดที่จะได้รับ'), findsOneWidget);
    expect(find.text('ยืนยันถอน ฿500'), findsOneWidget);
  });
}
