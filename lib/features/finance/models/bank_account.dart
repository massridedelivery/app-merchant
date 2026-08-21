/// Merchant payout bank account (SCRUM-60, live since v1.6.1-dev11).
///
/// The full account number is never returned — the backend stores it encrypted
/// and only echoes a masked form. To change the account the merchant must type
/// the whole number again, so a PUT always sends all three fields.
class BankAccount {
  final String bankName;
  final String bankCode;
  final String accountNumberMasked;
  final String accountName;

  const BankAccount({
    required this.bankName,
    required this.bankCode,
    required this.accountNumberMasked,
    required this.accountName,
  });

  /// A shop that has never linked an account gets a 200 with empty strings
  /// (not a 404), so "not linked yet" is read off the contents.
  bool get isLinked => bankCode.isNotEmpty && accountName.isNotEmpty;

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        bankName: (json['bank_name'] ?? '').toString(),
        bankCode: (json['bank_code'] ?? '').toString(),
        accountNumberMasked: (json['account_number_masked'] ?? '').toString(),
        accountName: (json['account_name'] ?? '').toString(),
      );
}

/// One selectable bank in the payout-account dropdown. The app sends only the
/// [code] — the backend resolves the display name so the name and code can
/// never disagree (SCRUM-60).
class ThaiBank {
  final String code;
  final String name;
  const ThaiBank(this.code, this.name);
}

/// BOT bank codes (3-digit). Kept to the banks a merchant is likely to use;
/// an unknown code is rejected by the backend with 400.
const List<ThaiBank> kThaiBanks = [
  ThaiBank('002', 'ธนาคารกรุงเทพ'),
  ThaiBank('004', 'ธนาคารกสิกรไทย'),
  ThaiBank('006', 'ธนาคารกรุงไทย'),
  ThaiBank('011', 'ธนาคารทหารไทยธนชาต (ttb)'),
  ThaiBank('014', 'ธนาคารไทยพาณิชย์'),
  ThaiBank('025', 'ธนาคารกรุงศรีอยุธยา'),
  ThaiBank('030', 'ธนาคารออมสิน'),
  ThaiBank('022', 'ธนาคารซีไอเอ็มบีไทย'),
  ThaiBank('024', 'ธนาคารยูโอบี'),
  ThaiBank('034', 'ธนาคารเพื่อการเกษตรและสหกรณ์ (ธ.ก.ส.)'),
  ThaiBank('067', 'ธนาคารทิสโก้'),
  ThaiBank('069', 'ธนาคารเกียรตินาคินภัทร'),
  ThaiBank('073', 'ธนาคารแลนด์ แอนด์ เฮ้าส์'),
];

/// The display name for a code (falls back to the code itself if unknown).
String bankNameForCode(String code) {
  for (final b in kThaiBanks) {
    if (b.code == code) return b.name;
  }
  return code;
}
