# API Audit — Merchant App vs. Backend Swagger

Cross-check of the `api/food` endpoints the **Merchant App** calls (from the
codebase) against the backend's Swagger spec.

- **Swagger source:** `https://driver-api-dev.nutchaphut.dev/swagger/doc.json` (Swagger 2.0, 288 paths, 61 under `/api/food`)
- **App base URL:** `http://localhost:8080/api/food` ([`lib/core/network/api_client.dart`](../lib/core/network/api_client.dart)) — relative paths are prefixed with `/api/food`.
- **Audited:** on 2026-08-08, against the dev Swagger at the time.

> ⚠️ Many Merchant App screens currently run against the built-in **mock
> interceptor** (`_isMockMode = true`), so endpoints missing from the backend
> still "work" in the app today and will break once a real backend is wired in.

## ✅ Matches (app ↔ Swagger) — 14 endpoints

| Method | Path (under `/api/food`) | Used in |
|--------|--------------------------|---------|
| GET | `/customer/restaurants/{id}/menu` | `menu_provider` |
| GET · POST · PUT | `/restaurant/ads` | `ad_provider` |
| POST | `/restaurant/busy` | status sheet |
| POST | `/restaurant/open` | status sheet |
| POST | `/restaurant/menu/categories` | add category |
| POST | `/restaurant/menu/items` | add menu item |
| GET | `/restaurant/orders/pending` | `order_provider` |
| POST | `/restaurant/orders/{id}/accept` | `order_provider` |
| POST | `/restaurant/orders/{id}/preparing` | `order_provider` |
| POST | `/restaurant/orders/{id}/ready` | `order_provider` |
| POST | `/restaurant/orders/{id}/reject` | `order_provider` |
| GET | `/restaurant/profile` | profile |

## ❌ App calls NOT in Swagger — 7 endpoints

| Method | Path the app calls | Issue |
|--------|--------------------|-------|
| GET | `/restaurant/finance/earnings` | No finance endpoints exist in the backend |
| GET | `/restaurant/finance/summary` | Missing |
| GET | `/restaurant/finance/transactions` | Missing |
| POST | `/restaurant/withdraw` | No withdraw endpoint in Swagger |
| GET | `/restaurant/orders/history` | Backend only has `orders/pending` |
| GET | `/restaurant/hours` | Only in the mock; not in the backend |
| GET | `/restaurant/modifier-groups` | **Wrong method** — Swagger has only `POST` (create), no `GET` (list) |

These cluster around the **Finance**, **Withdraw**, **Order History**, and
**Store Hours** screens — all mock-only today.

## 🐛 Config bugs

1. **`/auth/login` wrong base.** Swagger exposes it at the root (`/auth/login`),
   **not** under `/api/food`. The app's base URL is `/api/food`, so
   `dio.post('/auth/login')` resolves to `/api/food/auth/login` — a mismatch.
   See [`auth_provider.dart:46`](../lib/features/auth/providers/auth_provider.dart).
2. **`withdraw` double prefix.** [`bank_account_screen.dart:64`](../lib/features/profile/presentation/screens/bank_account_screen.dart)
   hardcodes `/api/food/restaurant/withdraw` while the base URL already contains
   `/api/food`, producing `/api/food/api/food/restaurant/withdraw`. (The endpoint
   doesn't exist in Swagger either.)

## 🧩 Backend features available but not yet used (restaurant scope)

| Method | Path | Feature |
|--------|------|---------|
| GET | `/restaurant/menu/categories` | List categories (app only POSTs) |
| PUT · DELETE | `/restaurant/menu/categories/{id}` | Edit / delete category |
| PUT · DELETE | `/restaurant/menu/items/{id}` | Edit / delete menu item (app only POSTs) |
| POST · PUT · DELETE | `/restaurant/modifier-groups` (+ `/{id}`, `/{gid}/modifiers`) | Full modifier CRUD |
| POST · DELETE | `/restaurant/items/{itemID}/modifier-groups` | Attach / detach a modifier group to an item |
| PUT | `/restaurant/profile` | Update restaurant profile (app only GETs) |
| GET · POST | `/restaurant/documents` | Upload / view restaurant KYC documents |
| PUT | `/restaurant/orders/{id}/ops` | Order operations (edit/partial changes) |

> Swagger also fully documents the `/customer/*` (cart, estimate, orders, chat,
> review) and `/driver/*` (accept, picked-up, delivered, chat, offer) surfaces —
> those belong to the Customer App and Driver App, not this repo.

## Summary

- **14 of the ~21** endpoints the app calls match the backend.
- **7 app endpoints have no backend** — Finance, Withdraw, Order History, Store
  Hours. They work today only via the mock interceptor.
- **2 config bugs** (`auth/login` base, `withdraw` double-prefix) must be fixed
  before pointing at a real backend.
- Backend already offers **modifier CRUD, menu edit/delete, profile update, and
  document upload** that the app hasn't wired up yet.

### Suggested follow-ups

1. Backend: add (or confirm) Finance summary/earnings/transactions, Withdraw,
   Order History, and Store Hours endpoints — or adjust the app to whatever the
   real contract is.
2. App: fix the `auth/login` base path and the `withdraw` double-prefix.
3. App: change `GET /restaurant/modifier-groups` to the documented endpoints, or
   have the backend add a list endpoint.
