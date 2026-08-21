import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/finance/models/finance.dart';

FinanceSummary _summary({double flat = 0, double rate = 0, double wht = 0}) =>
    FinanceSummary(
      balance: 10000,
      availableBalance: 10000,
      pendingWithdrawal: 0,
      lifetimeEarnings: 0,
      totalWithdrawn: 0,
      canWithdraw: true,
      withdrawalFeeFlat: flat,
      withdrawalFeeRate: rate,
      withholdingTaxRate: wht,
    );

/// The confirm sheet and live hint render whatever WithdrawalQuote reports, and
/// the fee comes from the summary's rate model (SCRUM-78).
void main() {
  group('WithdrawalQuote.from', () {
    test('free policy (all rates 0) — net equals amount', () {
      final q = WithdrawalQuote.from(500, _summary());
      expect(q.fee, 0);
      expect(q.net, 500);
      expect(q.isFree, isTrue);
    });

    test('flat + percentage fee are combined', () {
      // flat 10 + 1000 * (0.01 + 0.005) = 10 + 15 = 25
      final q = WithdrawalQuote.from(1000, _summary(flat: 10, rate: 0.01, wht: 0.005));
      expect(q.fee, closeTo(25, 0.0001));
      expect(q.net, closeTo(975, 0.0001));
      expect(q.isFree, isFalse);
    });

    test('net never goes negative', () {
      final q = WithdrawalQuote.from(5, _summary(flat: 50));
      expect(q.net, 0);
    });
  });
}
