# Backend: Merchant Withdrawal — endpoints the app already calls, waiting on BE

The merchant app (Flutter) has finished the **"แจ้งถอนเงิน" withdraw flow** (Grab/LINEMAN-style).
The client is ready for every contract below — backend just needs to implement them, then the app
switches from local/mock to the real endpoints.

- **Base URL:** `driver-api-dev.nutchaphut.dev`
- **Auth:** every endpoint needs `Authorization: Bearer <jwt>`, role = restaurant/merchant
- **Errors:** `{ "error": "<msg>" }`
- **Precedent:** the driver side already has the equivalent surface (`/api/driver/payouts*`) — use it as a template.

**Jira:** SCRUM-60 (base, In Review) · SCRUM-77 · SCRUM-78 · SCRUM-79

---

## 1) [SCRUM-60 addition] Withdrawal history + Bank account

### `GET /api/food/restaurant/withdrawals` — withdrawal history (app already calls this)

Response — array of:

```json
[
  { "id": "wd_123", "amount": 1250.00, "status": "completed", "created_at": "2026-08-20T10:00:00Z" }
]
```

- Status mapping in the app: `COMPLETED`/`PAID`/`SUCCESS` → "สำเร็จ", `FAILED`/`REJECTED` → "ไม่สำเร็จ", else → "รอดำเนินการ".
- May be empty (`[]`).
- App ref: `lib/features/finance/data/finance_repository.dart` (`fetchWithdrawals`), `models/finance.dart` (`WithdrawalRequest`).

### `GET /api/food/restaurant/bank-account` — payout account (app currently hard-codes SCB •••1234)

```json
{
  "bank_name": "ธนาคารไทยพาณิชย์ (SCB)",
  "bank_code": "014",
  "account_number_masked": "•••• 1234",
  "account_name": "นาย สมชาย เข็มกลัด"
}
```

### `PUT /api/food/restaurant/bank-account` — set / update account

Body: `{ "bank_code": "014", "account_number": "1234567890", "account_name": "..." }`

- Store `account_number` **encrypted at rest** (same as the driver payout method).
- App ref: `lib/features/finance/presentation/screens/bank_account_screen.dart`, `withdraw_screen.dart` (`_bankName` / `_bankAccountMasked` constants to be replaced).

---

## 2) [SCRUM-78] Withdrawal fee / WHT

The app shows a breakdown — ยอดที่ขอถอน → ค่าธรรมเนียม → ยอดที่จะได้รับ — and currently **assumes free** (`fee = 0`).
The driver side already withholds **1% WHT** on payouts (SCRUM-42 §9); the merchant side likely needs an equivalent.
The app renders whatever the backend reports — it just needs the number.

- Add a fee model to `GET /api/food/restaurant/finance/summary` — e.g. `withdrawal_fee_flat`, `withdrawal_fee_rate`, or `withholding_tax_rate`.
- `POST /api/food/restaurant/withdraw` returns the fee + net actually applied:

```json
{ "id": "wd_123", "amount": 1000.00, "fee": 0.00, "net_amount": 1000.00, "status": "pending" }
```

- Confirm the policy (free / flat / % / WHT?) so the app labels it correctly ("ฟรี" vs "-฿X").
- App ref: `lib/features/finance/models/finance.dart` — `WithdrawalQuote` (today `WithdrawalQuote.of(amount)` hard-codes `fee = 0`; wire the real fee here).

---

## 3) [SCRUM-77] Auto-payout (scheduled weekly transfer)

The app has an auto-payout toggle stored locally; move it server-side and add the cron that actually transfers.

### `GET /api/food/restaurant/finance/auto-payout`

```json
{ "enabled": false, "day_of_week": 1, "min_amount": 100 }
```

### `PUT /api/food/restaurant/finance/auto-payout`

Body: `{ "enabled": true }` — `day_of_week` / `min_amount` optional (default Monday, min ฿100).

### Cron (weekly)

- On the chosen `day_of_week`: for each merchant with `enabled = true` and `available_balance >= min_amount`,
  create a withdrawal to the registered bank account (same path as `POST /withdraw`).
- Respect the "one pending request at a time" rule (skip/defer if a manual withdrawal is already pending).
- App ref: `lib/features/finance/data/payout_settings.dart` (swap local SharedPreferences for the endpoint), `withdraw_screen.dart` (`_autoPayoutCard()`).

---

## 4) [SCRUM-79] FCM push on withdrawal completed (money in)

When a withdrawal's status becomes `completed`/`paid` (and optionally `rejected`), send an FCM push (HTTP v1)
to the restaurant's registered device token(s) (`app: "merchant"` — the register side is already done, see SCRUM-72).

```json
{
  "message": {
    "token": "<merchant-fcm-token>",
    "notification": { "title": "โอนเงินสำเร็จ", "body": "฿1,250 โอนเข้าบัญชีของคุณแล้ว" },
    "data": { "type": "withdrawal_completed", "withdrawal_id": "wd_123", "route": "/" },
    "android": { "priority": "high", "notification": { "channel_id": "high_importance_channel" } },
    "apns": { "payload": { "aps": { "sound": "default" } } }
  }
}
```

- `data.type` must start with `withdrawal` — the app auto-routes it to the Finance tab.
- Use the **default** channel (not the loud order channel) — this is informational, not a wake-and-act alert.
- A `notification` block (title + body) is required, or the push can be throttled and missed.
- Verify via the real FCM HTTP v1 API (not the Firebase console test).
- App ref: `lib/core/notifications/push_notification_service.dart` — `_isWithdrawal()` + `_handleTap()`.

---

## Combined acceptance

- [ ] `GET /withdrawals` + `GET`/`PUT /bank-account` live (SCRUM-60)
- [ ] fee/net returned on summary + `POST /withdraw` (SCRUM-78)
- [ ] `GET`/`PUT` auto-payout + weekly cron (SCRUM-77)
- [ ] `withdrawal_completed` push delivered + tap opens the Finance tab (SCRUM-79)
- [ ] Response shapes agreed with the app team / Swagger updated
