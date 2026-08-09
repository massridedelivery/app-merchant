# Backend Gaps — สิ่งที่ Merchant App ต้องการจาก Backend

> ส่งให้ทีม backend · ตรวจกับ Swagger `https://driver-api-dev.nutchaphut.dev/swagger/doc.json` (2026-08-08)
>
> Merchant App มีสกรีนพร้อมแล้ว แต่ **ไม่มี endpoint รองรับใน backend** — ตอนนี้รันได้เพราะ mock
> พอปิด mock (Phase 1) สกรีนกลุ่มนี้จะพัง ต้องการให้ backend เพิ่ม/ยืนยัน contract

---

## 🔴 P1 — Endpoint ที่ขาด (blocking สกรีน merchant)

### 1. Order History (หน้าประวัติออเดอร์)
Backend มีแค่ `GET /api/food/restaurant/orders/pending` (เฉพาะออเดอร์ที่ยัง active)
ต้องการ endpoint ดึงออเดอร์ที่จบแล้ว (DELIVERED / CANCELLED / RESTAURANT_REJECTED)

**เสนอ:**
```
GET /api/food/restaurant/orders/history?from=<ISO>&to=<ISO>&page=1&limit=20
→ 200: Order[]   (โครงเดียวกับ /orders/pending, filter status = terminal)
```

### 2. Finance / Earnings (หน้าการเงินร้าน)
ปัจจุบัน wallet ร้านมีแค่ฝั่ง admin (`POST /api/admin/wallets/merchants/{id}/adjust`) ไม่มีให้ร้านเรียกเอง
Merchant App เรียก 3 อันที่ไม่มี: `/restaurant/finance/summary`, `/restaurant/finance/earnings`, `/restaurant/finance/transactions`

**เสนอ:**
```
GET /api/food/restaurant/finance/summary
→ 200: { total_revenue, total_orders, avg_order_value, pending_payout }

GET /api/food/restaurant/finance/transactions?page=1&limit=20
→ 200: Transaction[]   { id, order_id, type, amount, balance_after, created_at }

GET /api/food/restaurant/finance/earnings?period=day|week|month
→ 200: { balance, pending, transactions[] }
```

### 3. Withdraw / Payout (หน้าถอนเงิน)
Merchant App เรียก `POST /restaurant/withdraw` — ไม่มีใน backend
(ฝั่ง driver มี `/api/driver/payouts` เป็นแบบอ้างอิงได้)

**เสนอ:**
```
POST /api/food/restaurant/payouts   { amount }
→ 201: { id, amount, status, requested_at }
GET  /api/food/restaurant/payouts   → 200: Payout[]
```

### 4. Store Hours (หน้าเวลาเปิด-ปิด + วันหยุดพิเศษ)
Merchant App เรียก `GET/PUT /restaurant/hours` — มีแค่ใน mock

**เสนอ:**
```
GET /api/food/restaurant/hours
→ 200: { delivery_hours: [{ day, is_open, is_24hr, slots:[{open,close}] }],
         special_closures: [{ id, reason, start_date, end_date, is_all_day }] }
PUT /api/food/restaurant/hours   (body เดียวกัน)
```

---

## 🟡 P2 — method ที่ขาด (มี resource แล้ว แต่ไม่มี GET list)

### 5. List Modifier Groups
Backend มี `POST /api/food/restaurant/modifier-groups` (สร้าง) แต่ **ไม่มี GET** (list)
Merchant App ต้องใช้ list เพื่อแสดง/เลือก modifier ตอนสร้างเมนู

**เสนอ:**
```
GET /api/food/restaurant/modifier-groups
→ 200: ModifierGroup[]  { id, name, min_select, max_select, is_active, modifiers[] }
```

---

## 🟢 ยืนยัน contract (ไม่ถึงกับ block แต่อยากให้ backend คอนเฟิร์ม)

### 6. WebSocket event frames ต้องฝัง `status` เสมอ
customer-app พึ่ง `status` / `order.status` ที่ฝังใน payload (ไม่ได้ switch ตามชื่อ event)
→ ทุก event (`order_accepted/preparing/ready/picked_up/delivered/cancelled`) **ต้องมี field `status`** ในเฟรม
ไม่งั้น customer เห็นสถานะช้า (รอ poll 10 วิ)

### 7. Event `order_created` ต้องมี object `order` เต็ม
merchant ต้องการ `order.items[]`, `customer_name/phone`, `delivery_address/lat/lng`, `total_amount`, `tier`
เพื่อแสดง popup ออเดอร์ใหม่ได้ทันทีโดยไม่ต้อง refetch

### 8. `selected_modifiers` เป็น object
ยืนยันว่า `OrderItem.selected_modifiers` = array ของ `{ id, name, price }` (ตาม `internal_foodorder.SelectedModifier`)
— merchant แก้ parser ให้รองรับแล้ว

---

## สรุปนับ
- **P1: 4 กลุ่ม** (History, Finance, Withdraw, Hours) — สกรีนพังถ้าไม่มี
- **P2: 1** (GET modifier-groups)
- **ยืนยัน contract: 3** (WS status, order payload, modifiers)

> ทางเลือกถ้า backend ยังไม่พร้อม: ซ่อน/disable สกรีน Finance·Withdraw·History·Hours ใน merchant ชั่วคราว
> เพื่อให้ Phase 1 (รับออเดอร์ happy path) ใช้งานได้ก่อน
