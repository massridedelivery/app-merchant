import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/features/finance/models/bank_account.dart';

void main() {
  group('BankAccount', () {
    test('parses the masked payout account', () {
      final acc = BankAccount.fromJson(const {
        'bank_name': 'ธนาคารไทยพาณิชย์',
        'bank_code': '014',
        'account_number_masked': '•••• 1234',
        'account_name': 'สมชาย ใจดี',
      });
      expect(acc.bankCode, '014');
      expect(acc.accountNumberMasked, '•••• 1234');
      expect(acc.isLinked, isTrue);
    });

    test('empty strings (never linked) read as not linked, not a crash', () {
      final acc = BankAccount.fromJson(const {
        'bank_name': '',
        'bank_code': '',
        'account_number_masked': '',
        'account_name': '',
      });
      expect(acc.isLinked, isFalse);
    });

    test('bankNameForCode resolves known codes and falls back', () {
      expect(bankNameForCode('014'), 'ธนาคารไทยพาณิชย์');
      expect(bankNameForCode('999'), '999');
    });
  });
}
