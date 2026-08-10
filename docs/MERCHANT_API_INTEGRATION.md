# Merchant App — แผนต่อ API ทั้งหมด (Integration Plan)

> เอกสารนี้รวม **ทุกสิ่งที่ merchant-app ต้องต่อ** เพื่อเลิกใช้ mock แล้วเชื่อม backend จริง
> พร้อมผลตรวจ flow ของ customer-app / driver-app เทียบกับ Swagger
> `https://driver-api-dev.nutchaphut.dev/swagger/index.html`
>
> ตรวจเมื่อ: 2026-08-08 · อ้างอิง Swagger 2.0 (Driver Backend API v1.0, 288 paths)

---

## 0. TL;DR — ภาพรวมสถานะ 3 แอป

| แอป | ต่อ backend จริงหรือยัง | สรุป |
|-----|------------------------|------|
| **customer-app** | ✅ ต่อครบ | สั่งอาหาร → ติดตามสถานะ ทำงานกับ backend จริง (`https://driver-api-dev.nutchaphut.dev`) ใช้ status ชุดจริง + WebSocket + polling ทุก 10 วิ |
| **driver-app** | ✅ happy-path ครบ | รับงานอาหารผ่าน WS event `food_delivery_offer` → accept / picked-up / delivered ผ่าน REST จริง (ขาด offer/reject/failed/no-show, WS URL ยัง hardcode dev) |
| **merchant-app** | ❌ **mock 100%** | `ApiClient.useMock = true`, `SocketService._isMockMode = true` ยังไม่ยิง backend จริงเลย และใช้ "สัญญา WebSocket เก่า" ที่ backend ไม่ได้ส่ง |

**ข้อสรุปสำคัญ:** customer + driver ย้ายมาใช้สัญญา backend จริงแล้ว เหลือ **merchant-app แอปเดียว** ที่ยังตกขบวน และยังยึดสัญญาเก่า (`NEW_ORDER`, `ORDER_STATUS_UPDATED`, สถานะ `DELIVERY/COMPLETED`) ที่ **เลิกใช้แล้ว**

---

## 1. Flow เต็ม end-to-end (ตอบโจทย์ "merchant รับ order → กดเรียก rider → แจ้งลูกค้า")

### 1.1 สถานะจริงของ order (backend เป็นเจ้าของ single source of truth)

```
PLACED
  ├─▶ RESTAURANT_ACCEPTED ─▶ PREPARING ─▶ READY_FOR_PICKUP ─▶ DRIVER_ASSIGNED ─▶ DRIVER_PICKED_UP ─▶ DELIVERED
  ├─▶ RESTAURANT_REJECTED            (ร้านปฏิเสธ)
  └─▶ CANCELLED                      (ลูกค้า/ระบบยกเลิก ก่อนถึง DELIVERED)
```

> ⚠️ สถานะ `DELIVERY` / `COMPLETED` / `FINDING_DRIVER` / `CONFIRMING` ที่อยู่ในโค้ด/สเปคเก่า
> **ไม่มีใน backend จริง** — ห้ามใช้ ให้ยึดชุดข้างบนเท่านั้น (ตรงกับที่ customer-app ใช้อยู่แล้ว)

### 1.2 ใครทำอะไร ตรงจุดไหน

```
 Customer                Backend / WS             Merchant (แอปนี้)          Rider
    │ สั่ง+จ่าย → PLACED   │                          │                         │
    │                     │── order_created ────────▶│ 🔔 เด้ง order ใหม่       │
    │                     │◀─ POST .../accept ───────│ กดรับออเดอร์             │
    │◀ status:ACCEPTED ───│   (เริ่มหา rider คู่ขนาน) ────────────────────────▶│ food_delivery_offer
    │                     │◀─ POST .../preparing ────│ เริ่มทำอาหาร            │
    │◀ status:PREPARING ──│                          │                         │
    │                     │◀─ POST .../ready ────────│ อาหารเสร็จ (ปุ่ม "พร้อม")│
    │                     │   READY_FOR_PICKUP        │                         │
    │                     │── driver_assigned ──────▶│ (เห็นว่ามี rider แล้ว)   │◀ accept
    │◀ status:DRIVER_..  ─│◀──────────────────────────────── picked-up ───────│ ถึงร้าน รับอาหาร
    │◀ DRIVER_PICKED_UP ──│                          │ (ย้ายไปแท็บ "กำลังส่ง")  │
    │◀ DELIVERED ─────────│◀──────────────────────────────── delivered ───────│ ส่งถึงลูกค้า
    │  เห็นใบเสร็จ         │   DELIVERED               │ (ย้ายไป "ประวัติ")      │
```

### 1.3 ตอบ 3 คำถามของทีมโดยตรง

**Q: merchant รับ order ยังไง?**
- รับแบบ real-time ผ่าน **WebSocket event `order_created`** (payload มี object `order` เต็ม)
- ตอน cold start / รีเฟรช ให้ดึงด้วย `GET /api/food/restaurant/orders/pending`
- กดรับ = `POST /api/food/restaurant/orders/{id}/accept` (PLACED → RESTAURANT_ACCEPTED)

**Q: "พอเสร็จ กดให้ rider มารับอาหาร" ทำยังไง?**
- **ไม่มีปุ่ม "เรียก rider" แยกต่างหาก** — การที่ merchant กด **"พร้อมให้มารับ"** = `POST /api/food/restaurant/orders/{id}/ready`
  (PREPARING → READY_FOR_PICKUP) คือสัญญาณให้ระบบส่ง rider มารับ
- จริง ๆ backend **เริ่มจับคู่ rider ตั้งแต่ตอน accept แล้ว (คู่ขนาน)** เพื่อให้ rider มาถึงพอดีตอนอาหารเสร็จ
- merchant **ไม่ได้เป็นคนสั่ง dispatch เอง** — หน้าที่จับคู่/ส่ง rider อยู่ที่ backend ทั้งหมด (`driver_id` เริ่มเป็น `null` แล้ว backend เติมให้ แล้วยิง event `driver_assigned` กลับมา)

**Q: แจ้งเตือนลูกค้า + อัพเดทสถานะ ยังไง?**
- **merchant ไม่ต้องแจ้งลูกค้าเอง** — แค่เปลี่ยนสถานะ order (accept/preparing/ready) แล้ว **backend fan-out ให้ลูกค้าเองอัตโนมัติ** ผ่าน WebSocket + FCM push
- customer-app ฟังสถานะจาก WS (`status` / `order.status` ใน payload) + poll `GET /orders/{id}` ทุก 10 วิ อยู่แล้ว
- สิ่งที่ merchant "ต้องทำ" เพื่อให้ลูกค้าได้รับแจ้ง = เรียก endpoint เปลี่ยนสถานะให้ครบทุกสเต็ปเท่านั้น

---

## 2. Config ที่ต้องแก้ (จุดเริ่ม)

| ไฟล์ | ปัจจุบัน (mock) | ต้องแก้เป็น |
|------|----------------|-----------|
| `lib/core/network/api_client.dart:12` | `host = 'http://localhost:8080'` | `https://driver-api-dev.nutchaphut.dev` |
| `lib/core/network/api_client.dart:14` | `useMock = true` | `false` |
| `lib/core/services/socket_service.dart:14` | `_isMockMode = true` | `false` (ต่อ WS จริง) |
| `lib/core/services/socket_service.dart:8` | `wsUrl = 'ws://localhost:8080/ws'` | `wss://driver-api-dev.nutchaphut.dev/ws` |
| `env/dev.json` | `localhost:8080` | base = `https://driver-api-dev.nutchaphut.dev`, ws = `wss://driver-api-dev.nutchaphut.dev/ws` |

> แนะนำย้ายค่าเหล่านี้ไปอ่านจาก `env/*.json` ผ่าน `--dart-define-from-file` ให้เหมือน customer-app/driver-app แทนการ hardcode

- **Base URL note:** endpoint ส่วนใหญ่อยู่ใต้ `/api/food` แต่ auth อยู่ที่ root (`/auth/...`) — โครงสร้าง `host` + `baseUrl` ปัจจุบันรองรับอยู่แล้ว (เรียก auth ด้วย absolute URL)

---

## 3. Auth — ต้องแก้ให้ตรง backend จริง (ตอนนี้ผิด 3 จุด)

Endpoint จริง: `POST /auth/login` (อยู่ที่ root ไม่ใช่ใต้ `/api/food`)

**Request body จริง:**
```json
{
  "email": "may_7781@hotmail.com",
  "password": "••••••",
  "device_id": "optional",
  "device_model": "optional",
  "os": "ios|android",
  "os_version": "optional",
  "app_version": "optional",
  "integrity_token": "optional"
}
```

**Response 200 จริง (`internal_auth.TokenPair`):**
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "eyJhbGc...",
  "expires_in": 3600
}
```

**สิ่งที่ต้องแก้ใน `lib/features/auth/providers/auth_provider.dart`:**

| ปัญหา | ปัจจุบัน | แก้เป็น |
|-------|---------|--------|
| field ผิด | ส่ง `{username, password, role:'restaurant'}` | ส่ง `{email, password, ...}` — **ไม่มี field `role`** (role อยู่ใน JWT ตาม account) |
| อ่าน token ผิด key | `response.data['token']` | `response.data['access_token']` (+ เก็บ `refresh_token`) |
| ไม่มี refresh | — | เก็บ `refresh_token`, ต่อ `POST /auth/refresh` เมื่อ 401 |

- Endpoint auth อื่นที่มี: `POST /auth/register`, `POST /auth/logout`, `POST /auth/refresh`, `POST /auth/otp/send`, `POST /auth/otp/verify`
- ทุก request ที่เหลือแนบ `Authorization: Bearer <access_token>` (interceptor ปัจจุบันทำอยู่แล้ว)

---

## 4. WebSocket — ต้องเขียนใหม่ทั้งหมด (สำคัญที่สุด)

### 4.1 ปัญหาปัจจุบัน
`socket_service.dart` + `order_provider._subscribeToSocket()` ยึด **สัญญาเก่า** ที่ backend ไม่ส่ง:
- อ่าน `event['data']` (backend จริง **ไม่มี** wrapper `data` — fields อยู่ flat)
- ฟัง type `NEW_ORDER` / `ORDER_STATUS_UPDATED` (backend จริงใช้ชื่อ event คนละชุด)
- rebucket ด้วยสถานะ `DELIVERY` / `COMPLETED` (backend จริงใช้ `DRIVER_PICKED_UP` / `DELIVERED`)

→ ผลคือถ้าเปิด WS จริงตอนนี้ **`event['data']` จะ null ทุกครั้ง ไม่มีอะไรทำงานเลย**

### 4.2 การเชื่อมต่อ
```
wss://driver-api-dev.nutchaphut.dev/ws?token=<access_token>
```
- server ping ทุก 54 วิ, client ควร pong ภายใน 60 วิ, idle timeout 30 วิ
- ทำ reconnect + exponential backoff (มีโครงเดิมอยู่แล้ว)

### 4.3 Event จริงที่ backend ส่งมาให้ร้าน (payload แบบ **flat**)

| Event `type` | payload | ความหมาย → บัคเก็ต merchant |
|--------------|---------|------------------------------|
| `order_created` | `{ type, order_id, status:"PLACED", order:{...} }` | ออเดอร์ใหม่ → เพิ่มใน **Preparing** + เด้ง popup |
| `order_accepted` | `{ type, order_id, status:"RESTAURANT_ACCEPTED" }` | echo ยืนยันรับ |
| `order_rejected` | `{ type, order_id, status:"RESTAURANT_REJECTED" }` | → History |
| `order_preparing` | `{ type, order_id, status:"PREPARING" }` | กำลังทำ (คง Preparing) |
| `order_ready` | `{ type, order_id, status:"READY_FOR_PICKUP" }` | → **Ready** |
| `driver_assigned` | `{ type, order_id, driver_id:"..." }` | ได้ rider แล้ว (เก็บ `driver_id`, ยังอยู่ Ready) |
| `order_picked_up` | `{ type, order_id, status:"DRIVER_PICKED_UP" }` | rider รับของ → **Delivering** |
| `order_delivered` | `{ type, order_id, status:"DELIVERED" }` | ส่งเสร็จ → **History** |
| `order_cancelled` | `{ type, order_id, status:"CANCELLED", reason:"..." }` | ยกเลิก → History |

ตัวอย่าง `order_created` เต็ม:
```json
{
  "type": "order_created",
  "order_id": "order-123",
  "status": "PLACED",
  "order": {
    "id": "order-123", "customer_id": "cust-456", "restaurant_id": "rest-123",
    "driver_id": null, "status": "PLACED",
    "delivery_address": "456 Customer St, Bangkok",
    "delivery_lat": 13.7563, "delivery_lng": 100.5018,
    "food_total": 250.0, "delivery_fee": 25.0, "total_amount": 275.0,
    "payment_method": "credit_card", "placed_at": "2024-01-01T12:00:00Z",
    "tier": "STANDARD",
    "items": [
      { "id":"orderitem-1","order_id":"order-123","menu_item_id":"item-456",
        "name":"Spring Rolls","quantity":2,"unit_price":89.0,
        "variant_options":null,"selected_modifiers":[],"subtotal":178.0 }
    ]
  }
}
```

### 4.4 สิ่งที่ต้องแก้ในโค้ด
- `socket_service.dart`: ลบ mock broadcaster, ต่อ WS จริง, ส่ง message ดิบทั้ง object เข้า stream (อย่า assume `data`)
- `order_provider._subscribeToSocket()`: `switch (event['type'])` ตามตาราง 4.3, อ่าน `event['order']` (ไม่ใช่ `event['data']`), และ **rebucket ด้วย `DRIVER_PICKED_UP` / `DELIVERED`** (ไม่ใช่ `DELIVERY` / `COMPLETED`)

---

## 5. REST Endpoints ฝั่งร้าน — mapping ครบ

Base: `https://driver-api-dev.nutchaphut.dev` · ทุกอันแนบ `Authorization: Bearer <access_token>`

### 5.1 ✅ มีใน backend + merchant เรียกถูก path แล้ว (แค่ปิด mock)

| Method | Path | ใช้ที่ | Response |
|--------|------|--------|----------|
| GET | `/api/food/restaurant/profile` | profile | object โปรไฟล์ร้าน |
| PUT | `/api/food/restaurant/profile` | store details | โปรไฟล์ที่อัพเดต |
| POST | `/api/food/restaurant/open` | status sheet | `{ "is_open": true }` |
| POST | `/api/food/restaurant/busy` | status sheet | `{ "message": "busy mode updated" }` |
| GET | `/api/food/restaurant/orders/pending?status=...` | order_provider | `Order[]` |
| POST | `/api/food/restaurant/orders/{id}/accept` | order_provider | `{ "message":"RESTAURANT_ACCEPTED" }` |
| POST | `/api/food/restaurant/orders/{id}/reject` | order_provider | `{ "message":"RESTAURANT_REJECTED" }` |
| POST | `/api/food/restaurant/orders/{id}/preparing` | order_provider | `{ "message":"PREPARING" }` |
| POST | `/api/food/restaurant/orders/{id}/ready` | order_provider | `{ "message":"READY_FOR_PICKUP" }` |
| GET | `/api/food/customer/restaurants/{id}/menu` | menu_provider (แสดงเมนู) | เมนูร้าน |
| GET·POST·PUT | `/api/food/restaurant/ads` | ad_provider | ad settings |
| POST | `/api/food/restaurant/menu/categories` | add category | category |
| POST | `/api/food/restaurant/menu/items` | add item | item |

**Payload ที่ต้องเตรียม (body):**

`POST /restaurant/busy`
```json
{ "is_busy": true, "duration_min": 30 }
```

`POST /restaurant/open`
```json
{ "is_open": true }
```

`PUT /restaurant/profile`
```json
{
  "restaurant_name": "...", "description": "...", "cuisine_type": "...",
  "address": "...", "lat": 13.76, "lng": 100.51,
  "logo_url": "key.jpg", "cover_image_url": "key.jpg",
  "min_order_amount": 150.0, "bank_code": "SCB", "bank_account_number": "..."
}
```

### 5.2 🆕 มีใน backend แต่ merchant **ยังไม่ได้ต่อ** (ควรต่อเพิ่ม)

| Method | Path | ใช้ทำอะไร |
|--------|------|-----------|
| PUT | `/api/food/restaurant/orders/{id}/ops` | ปรับเวลาเตรียม / ทำเครื่องหมายของหมด (OOS) |
| GET | `/api/food/restaurant/menu/categories` | list หมวดเมนู (ตอนนี้แอป POST อย่างเดียว) |
| PUT·DELETE | `/api/food/restaurant/menu/categories/{id}` | แก้/ลบหมวด |
| PUT·DELETE | `/api/food/restaurant/menu/items/{id}` | แก้/ลบเมนู |
| POST·PUT·DELETE | `/api/food/restaurant/modifier-groups` (+`/{id}`, `/{gid}/modifiers`) | CRUD ตัวเลือกเสริม (modifier) เต็มรูปแบบ |
| POST·DELETE | `/api/food/restaurant/items/{itemID}/modifier-groups` | ผูก/ถอด modifier group กับเมนู |
| GET·POST | `/api/food/restaurant/documents` | อัพโหลด/ดูเอกสาร KYC ร้าน |
| POST | `/api/notifications/register-device` | ลงทะเบียน FCM (ดูข้อ 6) |

`PUT /restaurant/orders/{id}/ops`
```json
{ "prep_time_adjustment_min": 5, "oos_order_item_ids": ["orderitem-1"] }
```

### 5.3 ❌ merchant เรียกอยู่ แต่ backend **ไม่มี endpoint นี้** — ต้องตัดสินใจ

| Method | Path ที่แอปเรียก | ปัญหา | สกรีนที่กระทบ |
|--------|------------------|-------|----------------|
| GET | `/restaurant/finance/summary` | ไม่มีใน backend | Finance |
| GET | `/restaurant/finance/earnings` | ไม่มี | Finance |
| GET | `/restaurant/finance/transactions` | ไม่มี | Finance |
| POST | `/restaurant/withdraw` | ไม่มี (+ bug double-prefix `/api/food/api/food/...` ที่ `bank_account_screen.dart:64`) | ถอนเงิน |
| GET | `/restaurant/orders/history` | ไม่มี (backend มีแค่ `orders/pending`) | ประวัติออเดอร์ |
| GET | `/restaurant/hours` | ไม่มี (มีแค่ใน mock) | เวลาเปิด-ปิด |
| GET | `/restaurant/modifier-groups` | **ผิด method** — backend มีแค่ POST (สร้าง) ไม่มี GET (list) | เมนู/ตัวเลือกเสริม |

> การเงินฝั่งร้านใน backend ปัจจุบันมีแค่ฝั่ง **admin** (`/api/admin/wallets/merchants/{id}/adjust`) — ไม่มี endpoint ให้ร้านเรียกเอง
>
> **ต้องคุยกับทีม backend:** เพิ่ม endpoint Finance / Withdraw / Order History / Store Hours (+ GET modifier-groups) หรือปรับ scope แอปให้ตรงของจริง สกรีนกลุ่มนี้จะ **พังทันที** เมื่อปิด mock

---

## 6. Push Notification (FCM) — เตรียมสำหรับแจ้งเตือนร้านตอนไม่ได้เปิดแอป

- ลงทะเบียน token: `POST /api/notifications/register-device`
  ```json
  { "device_type": "ios|android", "token": "<fcm_token>" }
  ```
- ยกเลิกตอน logout: `POST /api/notifications/unregister-device`
- รายการแจ้งเตือนในแอป: `GET /api/notifications`, mark read `PATCH /api/notifications/{id}/read`
- ตามแพทเทิร์น driver-app: **FCM เป็นแค่ "ปลุก" ให้เปิดแอป** (ไม่มี order data) → พอเปิดแล้วโหลดออเดอร์จริงผ่าน WS/REST อีกที
- ต้องตั้ง Firebase project ให้ merchant-app (ปัจจุบัน pubspec ยังไม่มี `firebase_messaging`)

---

## 7. Model ที่ต้องแก้ให้ตรง schema จริง

`lib/features/orders/models/order.dart` — `OrderItem.selectedModifiers`
- ตอนนี้ parse เป็น `List<String>` (`.map((m)=>m.toString())`)
- backend จริง `selected_modifiers` = **array ของ object** `internal_foodorder.SelectedModifier`:
  ```json
  { "id": "mod-1", "name": "เพิ่มไข่ดาว", "price": 15.0 }
  ```
- ถ้าไม่แก้ จะได้สตริงขยะ เช่น `"{id: mod-1, name: ..., price: 15.0}"` บน backend จริง
- ควรทำ class `SelectedModifier { id, name, price }` แล้ว map ให้ถูก

**Field เพิ่มเติมใน `Order` จริงที่ควรรองรับ** (ตอนนี้ model ตัดทิ้ง): `customer_name`, `customer_phone`, `delivery_lat/lng`, `delivery_notes`, `driver_id`, `tier`, `prep_time_adjustment_min`, `oos_items`, `promo_discount`, `original_eta_min`, `batching_enabled` ฯลฯ (จำเป็นสำหรับหน้ารายละเอียดออเดอร์ + ปุ่ม ops)

---

## 8. Checklist ลำดับงาน (แนะนำทำตามนี้)

**Phase 1 — เปิดต่อ backend จริง (happy path รับออเดอร์) ✅ เสร็จ**
1. [x] แก้ config: base URL, `useMock=false`, WS URL, `_isMockMode=false` (ข้อ 2)
2. [x] แก้ auth ให้ใช้ `email` + `access_token` + ตัด `role` (+ เก็บ refresh_token, ต่อปุ่ม login จริง) (ข้อ 3)
3. [x] เขียน WebSocket handler ใหม่ตาม event จริง + rebucket ด้วย `DRIVER_PICKED_UP`/`DELIVERED` (ข้อ 4)
4. [x] แก้ `OrderItem` ให้ parse `selected_modifiers` เป็น object (ข้อ 7)
5. [ ] ทดสอบวงจรจริงกับ backend: order_created → accept → preparing → ready → driver_assigned → picked_up → delivered

**Phase 2 — เก็บฟีเจอร์ที่ backend มีอยู่แล้ว ✅ เสร็จ (โค้ด)**
6. [x] ต่อ `PUT /orders/{id}/ops` — `OrderNotifier.updateOps()` (ปรับเวลาเตรียม / OOS)
7. [x] ต่อ menu/modifier CRUD เต็ม — `menu_provider.dart`: category/item create·update·delete·toggle availability, modifier group/modifier CRUD, link/unlink; แก้ resolve restaurant id จาก profile (เลิก hardcode `rest-123`); wire ปุ่มแก้ไขเมนู → toggle/ลบ ใน `menu_screen.dart`
8. [x] ต่อ FCM `register-device`/`unregister-device` — `notification_service.dart` (REST ทำงานจริง) + register ตอน login / unregister ตอน logout
   - ⚠️ เหลือ **Firebase native setup** (pubspec `firebase_core`/`firebase_messaging`, `google-services.json`, `GoogleService-Info.plist`, `Firebase.initializeApp()`, `FirebasePushTokenProvider`) — วิธีทำอยู่ในคอมเมนต์ท้าย `notification_service.dart` ตอนนี้ token provider เป็น no-op กัน crash

**Phase 3 — ปิด gap กับ backend** (ดู `docs/BACKEND_GAPS.md`)
9. [ ] คุย backend เรื่อง Finance / Withdraw / Order History / Store Hours / GET modifier-groups (ข้อ 5.3)
10. [ ] แก้ bug `withdraw` double-prefix ที่ `bank_account_screen.dart:64`

---

## 9. หมายเหตุ cross-app ที่ควรแจ้งทีม
- **driver-app** ขาด REST `GET .../offer`, `reject`, `failed`, `no-show` ของ food (มีแต่ของ messenger) และ WS URL ยัง hardcode dev (`socket_service.dart:82-83`) — happy path ใช้ได้ แต่ edge case (ปฏิเสธ/ส่งไม่สำเร็จ/ลูกค้าไม่รับสาย) ยังไม่รองรับ
- ไฟล์ `food_delivery_websocket_spec.md` (ทั้ง 3 repo) เป็น **สเปคเก่า** (`FINDING_DRIVER/DELIVERY/COMPLETED`, wrapper `data`) — customer-app เลิกใช้แล้ว ควร deprecate เพื่อไม่ให้ merchant หลงยึดต่อ
- customer-app พึ่ง `status`/`order` ที่ฝังใน WS payload + poll 10 วิ (ไม่ได้ switch ตามชื่อ event) — ดังนั้น backend ควรฝัง `status` ในทุก event frame เสมอ
