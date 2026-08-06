# Order Flow — Customer · Merchant · Rider

End-to-end lifecycle of a single food-delivery order across the three apps.
Derived from the actual Merchant App code plus the team's WebSocket spec:

- [`lib/features/orders/providers/order_provider.dart`](../lib/features/orders/providers/order_provider.dart)
- [`lib/core/services/socket_service.dart`](../lib/core/services/socket_service.dart)
- [`food_delivery_websocket_spec.md`](../food_delivery_websocket_spec.md)
- [`RESTAURANT_API_GUIDE.md`](../RESTAURANT_API_GUIDE.md)

## Actors

| Actor | App | Responsibility |
|-------|-----|----------------|
| **Customer** | Customer App | Places & pays for the order, tracks status + live rider location |
| **Merchant** | **Merchant App** (this repo) | Accepts/rejects orders, prepares food, marks ready |
| **Rider** | Driver App | Accepts the job, picks up at the restaurant, delivers to the customer |
| *(Backend + WebSocket server)* | — | Coordinates real-time state between the three apps |

## Status lifecycle

```
PLACED → RESTAURANT_ACCEPTED → PREPARING → READY_FOR_PICKUP → DELIVERY → COMPLETED
   │
   └─▶ RESTAURANT_REJECTED (restaurant declines)
   ·   any state before COMPLETED ─▶ CANCELLED (customer / system)
```

The Merchant App buckets these into UI tabs (`order_provider.dart`):

| Bucket | Statuses |
|--------|----------|
| **Preparing** | `PLACED`, `RESTAURANT_ACCEPTED`, `PREPARING` |
| **Ready** | `READY_FOR_PICKUP` |
| **Delivering** | `DELIVERY` |
| **History** | `COMPLETED`, `RESTAURANT_REJECTED`, `CANCELLED` |

## Step-by-step

### 1. Customer places the order → `PLACED`
- Customer picks a nearby restaurant, selects items, pays.
- Backend creates the order as **`PLACED`** and emits **`NEW_ORDER`** over WebSocket to the Merchant App.
- Merchant App (`order_provider.dart`) receives it, drops it into the **Preparing** bucket, and raises the new-order popup (`hasNewOrder = true`).

### 2. Merchant accepts or rejects → `RESTAURANT_ACCEPTED` / `RESTAURANT_REJECTED`
| Action | Endpoint | New status |
|--------|----------|-----------|
| Accept | `POST /restaurant/orders/{id}/accept` | `RESTAURANT_ACCEPTED` |
| Reject | `POST /restaurant/orders/{id}/reject` | `RESTAURANT_REJECTED` → History |

- The system begins **finding a rider** in parallel.
- Customer sees the change via **`ORDER_STATUS_UPDATED`**.

### 3. Merchant starts cooking → `PREPARING`
- `POST /restaurant/orders/{id}/preparing` → **`PREPARING`**.
- Customer sees "restaurant is preparing your food."

### 4. Food ready → `READY_FOR_PICKUP`
- `POST /restaurant/orders/{id}/ready` → **`READY_FOR_PICKUP`**.
- In the Merchant App the order moves from **Preparing** to the **Ready** bucket.

### 5. Rider picks up → `DELIVERY` *(driver-triggered, not the merchant)*
- The Driver App marks pickup → **`DELIVERY`**.
- Emits **`ORDER_STATUS_UPDATED (DELIVERY)`** to both merchant and customer.
- Merchant App moves the order into the **Delivering** bucket.
- Rider then streams **`DRIVER_LOCATION_UPDATED`** every 5–10s so the customer sees the motorbike move on the map; optional **`ETA_UPDATED`** refreshes the arrival time.

### 6. Delivered → `COMPLETED`
- Rider hands off and marks complete → **`COMPLETED`**.
- Customer sees the receipt; the merchant sees the order in **History** and the revenue in the **Finance** screen.

## Sequence (all three actors)

```
 Customer                Backend / WS            Merchant                 Rider
    │ order + pay → PLACED │                        │                       │
    │                      │──── NEW_ORDER ────────▶│ 🔔 new order          │
    │                      │◀──── accept ───────────│ tap accept            │
    │◀ STATUS: CONFIRMING ─│                        │                       │
    │                      │      (find rider) ────────────────────────────▶│ takes job
    │                      │◀──── preparing ────────│ cooking               │
    │◀ STATUS: PREPARING ──│                        │                       │
    │                      │◀──── ready ────────────│ food ready            │
    │                      │      READY_FOR_PICKUP  │                       │
    │                      │◀───────────────────────────── pickup ─────────│ arrives → DELIVERY
    │◀ STATUS: DELIVERY ───│                        │ (moves to Delivering) │
    │◀ DRIVER_LOCATION ⟳ ──│◀────────────────────────────── location ⟳ ────│ pings every 5-10s
    │◀ STATUS: COMPLETED ──│◀────────────────────────────── complete ──────│ delivered
    │  sees receipt        │       COMPLETED        │ History + Finance     │
```

## Notes on the current code

1. **Runs fully mocked today.** `SocketService._isMockMode = true` and the API base URL is `http://localhost:8080` — no real backend yet. The app simulates a new order every 60s for demo purposes.
2. **Status names don't fully match across apps.** Merchant uses `RESTAURANT_ACCEPTED` / `READY_FOR_PICKUP`; the customer spec uses `FINDING_DRIVER` / `CONFIRMING`. `PREPARING`, `DELIVERY`, `COMPLETED`, `CANCELLED` are shared. A backend mapping is required.
3. **The merchant does not control the delivery phase.** `DELIVERY` and `COMPLETED` are driven by the Driver App; the Merchant App only reacts via socket and re-buckets — there are no merchant endpoints for these two states.
4. **Rider matching / dispatch lives in the backend.** It isn't in any of the three apps; `driver_id` starts as `null` at `PLACED` and the backend fills it in.
