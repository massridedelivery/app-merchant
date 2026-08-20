import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/finance/models/finance.dart';

/// The confirm sheet and the live hint both render whatever [WithdrawalQuote]
/// reports, so its arithmetic is the single source of truth for what the
/// merchant is told they will receive.
void main() {
  group('WithdrawalQuote', () {
    test('standard payout is free — net equals amount', () {
      final q = WithdrawalQuote.of(500);
      expect(q.amount, 500);
      expect(q.fee, 0);
      expect(q.net, 500);
      expect(q.isFree, isTrue);
    });

    test('a fee is subtracted from the net', () {
      const q = WithdrawalQuote(amount: 1000, fee: 15);
      expect(q.net, 985);
      expect(q.isFree, isFalse);
    });

    test('net never goes negative when the fee exceeds the amount', () {
      const q = WithdrawalQuote(amount: 10, fee: 25);
      expect(q.net, 0);
    });
  });
}
