# API Diff — `develop` vs `main`

Comparison of the API surface between branches.

- **`develop`** @ `3a731c7` (new)
- **`main`** @ `f81eb50` (base)

`develop` introduces a full repository / network layer (~1,676 insertions across 16 files). Endpoints below are what `develop` adds or changes relative to `main`.

---

## Infra changes

- **Base URL** — `main` used `{host}/api/food`; `develop` changed it to `http://localhost:8080`, so each call now carries the full `/api/...` path.
- **Auth interceptor** — JWT refresh via `POST /auth/refresh`, session persist/clear, and `/auth/` calls exempted from the refresh flow.
- **Socket** — `SocketService` singleton moved into a Riverpod provider; typed events (`new_food_order`, `order_accepted`, `order_ready`, `order_cancelled`) plus a reconnect reconcile against `GET .../orders/pending`.

---

## Auth

| Method | Path |
| ------ | ---- |
| POST | `/auth/login` |
| POST | `/auth/register` |
| POST | `/auth/refresh` |
| POST | `/auth/logout` |

## Restaurant profile / status

| Method | Path |
| ------ | ---- |
| GET | `/api/food/restaurant/profile` |
| PUT | `/api/food/restaurant/profile` |
| POST | `/api/food/restaurant/open` |
| POST | `/api/food/restaurant/busy` |
| GET | `/api/food/restaurant/documents` |
| POST | `/api/food/restaurant/documents` |

## Menu

| Method | Path |
| ------ | ---- |
| GET | `/api/food/restaurant/{id}/menu` |
| GET | `/api/food/restaurant/menu/categories` |
| POST | `/api/food/restaurant/menu/categories` |
| PUT | `/api/food/restaurant/menu/categories/{id}` |
| DELETE | `/api/food/restaurant/menu/categories/{id}` |
| POST | `/api/food/restaurant/menu/items` |
| PUT | `/api/food/restaurant/menu/items/{id}` |
| DELETE | `/api/food/restaurant/menu/items/{id}` |

## Modifiers

| Method | Path |
| ------ | ---- |
| POST | `/api/food/restaurant/modifier-groups` |
| PUT | `/api/food/restaurant/modifier-groups/{id}` |
| DELETE | `/api/food/restaurant/modifier-groups/{id}` |
| POST | `/api/food/restaurant/items/{itemId}/modifier-groups` |
| DELETE | `/api/food/restaurant/items/{itemId}/modifier-groups/{groupId}` |
| POST | `/api/food/restaurant/modifier-groups/{groupId}/modifiers` |
| PUT | `/api/food/restaurant/modifiers/{id}` |
| DELETE | `/api/food/restaurant/modifiers/{id}` |

## Orders

| Method | Path |
| ------ | ---- |
| GET | `/api/food/restaurant/orders/pending?status=` |
| GET | `/api/food/restaurant/orders/history` |
| POST | `/api/food/restaurant/orders/{id}/accept` |
| POST | `/api/food/restaurant/orders/{id}/reject` |
| POST | `/api/food/restaurant/orders/{id}/preparing` |
| POST | `/api/food/restaurant/orders/{id}/ready` |
| PUT | `/api/food/restaurant/orders/{id}/ops` |

## Finance

| Method | Path |
| ------ | ---- |
| GET | `/api/food/restaurant/finance/summary` |
| GET | `/api/food/restaurant/finance/transactions` |
| GET | `/api/food/restaurant/finance/earnings` |
| POST | `/api/food/restaurant/withdraw` |

## Ads

| Method | Path |
| ------ | ---- |
| GET | `/api/food/restaurant/ads` |
| POST | `/api/food/restaurant/ads` |
| PUT | `/api/food/restaurant/ads` |

## Media

| Method | Path |
| ------ | ---- |
| GET | `/api/media/upload-url` |
| PUT | *(S3 presigned upload — external host)* |
| POST | `/api/media/confirm` |
| GET | `/api/media/view` |

## Notifications / device

| Method | Path |
| ------ | ---- |
| POST | `/api/notifications/register-device` |
| POST | `/api/notifications/unregister-device` |

---

## Notes

Code comments flag these endpoints as **not existing server-side** (per SCRUM-53) — mock-only:

- `/api/food/restaurant/finance/earnings`
- `/api/food/restaurant/orders/history`
- merchant wallet / earnings endpoints (no merchant-facing wallet endpoint exists)
