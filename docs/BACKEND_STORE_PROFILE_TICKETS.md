# [SCRUM-80] Backend: accept contact fields on `PUT /restaurant/profile`

The merchant app now has a full-page store editor (EditStoreScreen). It edits everything
`PUT /api/food/restaurant/profile` accepts today — name, cuisine, address, description, min order,
and now **logo + cover images** (media `file_key` → `logo_url` / `cover_image_url`, already supported).

But the store details screen also **displays** several contact fields the endpoint does **not** accept,
so they're stuck read-only and the merchant can't fix them in-app.

- `phone` — เบอร์ติดต่อร้าน
- manager (`manager_name` / `manager_phone` / `manager_email`) — ผู้จัดการ
- `email`
- `tax_id` — เลขประจำตัวผู้เสียภาษี (13 digits)

`RestaurantRepository.updateProfile` even notes it: "the documented body has no phone or manager
fields, so those stay read-only."

## What the backend needs to do

Extend `PUT /api/food/restaurant/profile` to accept these (all optional, patch-style like the existing fields):

```json
{
  "phone": "+66649426362",
  "manager_name": "…",
  "manager_phone": "…",
  "manager_email": "…",
  "email": "…",
  "tax_id": "1510100184948"
}
```

- Validate formats (phone / email / 13-digit Thai tax id) and echo the accepted fields back like the other profile fields.
- **Decide + report back:** which fields are merchant-editable vs admin-only — especially `tax_id`, which may need to stay locked after verification.

## App reference (ready to wire as soon as BE ships)

- `lib/features/restaurant/data/restaurant_repository.dart` → `updateProfile` (add the params)
- `lib/features/restaurant/presentation/screens/edit_store_screen.dart` → add the input fields once accepted
- `lib/features/restaurant/presentation/screens/store_details_screen.dart` → currently shows them read-only

## Acceptance criteria

- [ ] `PUT /profile` accepts phone / manager / email / tax id (those agreed as merchant-editable)
- [ ] Validation + echo-back in place; Swagger updated
- [ ] Decision recorded on which contact fields are merchant-editable vs admin-only
- [ ] App adds the fields to the editor once shipped

Related: SCRUM-53 §3 (profile spec).
