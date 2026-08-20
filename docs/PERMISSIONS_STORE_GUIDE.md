# Permissions audit + store-review guide (Driver / Customer / Merchant apps)

หลักการเดียวกันทุกแอป: **ขอสิทธิ์เฉพาะที่ฟีเจอร์ใช้จริง, ขอตอนจะใช้ (in-context), และประกาศให้ตรงกับสโตร์**
Merchant app ทำเสร็จแล้ว (เหลือแค่ แจ้งเตือน + กล้อง/คลังรูป, ตัด location ทิ้ง) — ใช้เป็นตัวอย่าง

---

## ขั้นที่ 1 — Audit ว่าตอนนี้ขออะไรบ้าง

```bash
# Android
grep -E "uses-permission|uses-feature|foregroundServiceType" android/app/src/main/AndroidManifest.xml
# iOS
grep -E "UsageDescription|UIBackgroundModes|NSLocation" ios/Runner/Info.plist
# โค้ดที่ขอสิทธิ์จริง
grep -rnE "Permission\.[a-zA-Z]+|requestPermission|\.request\(\)|myLocationEnabled|ImagePicker|Geolocator" lib
# APK ที่ build จริง (merged manifest — เห็นสิ่งที่ plugin inject ด้วย)
flutter build apk --debug && \
  grep -iE "permission" build/app/intermediates/merged_manifest*/**/AndroidManifest.xml 2>/dev/null
```
กติกา: ทุก permission ต้อง **map กับฟีเจอร์ได้** ถ้า declare แล้วไม่ได้ใช้ → ทั้ง 2 สโตร์ถือว่าผิด policy → ลบทิ้ง

---

## ขั้นที่ 2 — สิทธิ์ที่แต่ละแอป *น่าจะ* ต้องใช้ (เช็คกับฟีเจอร์จริง)

| สิทธิ์ | Driver | Customer | Merchant | หมายเหตุ |
|---|---|---|---|---|
| แจ้งเตือน (POST_NOTIFICATIONS / iOS) | ✅ งานเข้า | ✅ สถานะออเดอร์ | ✅ ออเดอร์ใหม่ | request-on-use |
| ตำแหน่ง **ขณะใช้** (WhenInUse/FINE) | ✅ นำทาง/รับงาน | ✅ หาร้านใกล้ฉัน/ติดตาม | ❌ ตัดทิ้งแล้ว | ขอตอนเข้าแผนที่ |
| ตำแหน่ง **เบื้องหลัง** (Always/BACKGROUND) | ⚠️ เฉพาะถ้าติดตามตอนแอปพับ | ❌ ไม่ควร | ❌ | ดู "background location" ข้างล่าง — เข้มมาก |
| Foreground service (location) | ⚠️ ถ้าส่งพิกัดตอนวิ่งงาน | ❌ | ❌ | Android 14 ต้องมี type + ประกาศ |
| กล้อง | ✅ KYC/โปรไฟล์ | 🟡 โปรไฟล์/แชท | ✅ รูปร้าน | request-on-use |
| คลังรูป | ✅ | ✅ | ✅ | ใช้ Photo Picker เลี่ยง permission |
| ไมโครโฟน | ❌ (เว้นมีแชทเสียง) | ❌ | ❌ | อย่า declare ถ้าไม่ใช้ |
| โทรศัพท์/Contacts | ปกติ**ไม่ต้อง** | ไม่ต้อง | ไม่ต้อง | โทรใช้ `tel:` แทน (ไม่ต้องขอสิทธิ์) |

> ถ้าเจอ permission ที่ไม่มีฟีเจอร์รองรับ (เช่น READ_CONTACTS, RECORD_AUDIO, ACCESS_BACKGROUND_LOCATION ที่ไม่ได้ใช้) → **ลบ** และถ้า plugin inject มา ให้ override ใน AndroidManifest:
> ```xml
> <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" tools:node="remove"/>
> ```

---

## ขั้นที่ 3 — Flow มาตรฐาน (ทำให้ถูกต้อง)

**อย่าขอรวดเดียวตอนเปิดแอป** (ทั้ง 2 สโตร์ตีกลับ) ทำแบบนี้:

```
1. เปิดแอป → ไม่เด้งขอสิทธิ์
2. ผู้ใช้กดฟีเจอร์ที่ต้องใช้สิทธิ์ → แสดง priming สั้นๆ (อธิบายว่าทำไม) → ค่อยเรียก OS prompt
3. ถ้า denied → แสดงเหตุผลซ้ำ + ปุ่ม "ไปตั้งค่า" (openAppSettings)
4. ถ้า permanentlyDenied → ต้องส่งไป Settings เท่านั้น (เรียก prompt ซ้ำไม่ขึ้นแล้ว)
```

โค้ดกลาง (permission_handler):
```dart
Future<bool> ensurePermission(Permission p, {required String why}) async {
  var status = await p.status;
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) { await openAppSettings(); return false; }
  // (แนะนำ) โชว์ dialog priming อธิบาย `why` ก่อน แล้วค่อย request
  status = await p.request();
  return status.isGranted;
}
```

จังหวะขอ:
- **แจ้งเตือน** → หลัง login สำเร็จ หรือตอนกด "เปิดรับงาน/ออเดอร์" ครั้งแรก
- **กล้อง/คลังรูป** → ตอนกด "เพิ่ม/เปลี่ยนรูป" (OS เด้งเอง)
- **ตำแหน่ง** → ตอนเข้าหน้าแผนที่/กด "ใช้ตำแหน่งปัจจุบัน"

---

## ขั้นที่ 4 — ให้ผ่าน App Store (Apple)

1. **Purpose string ต้องมีทุกสิทธิ์ที่แตะ** ใน `ios/Runner/Info.plist` — ขาด = reject, กว้างไป = reject
   - ⚠️ **ITMS-90683 (สำคัญ):** ถ้า **link SDK** ที่อ้าง API ข้อมูลอ่อนไหว (เช่น `google_maps_flutter`/`geocoding` → CoreLocation) Apple บังคับให้มี purpose string **แม้แอปจะไม่ได้ใช้จริง** ("your app might not use these APIs, a purpose string is still required")
   - เจอตอนทำ Merchant: ลบ `NSLocationWhenInUseUsageDescription` ออกแล้วโดน ITMS-90683 เพราะยังมี map SDK → ต้อง **ใส่ WhenInUse กลับ** (ไม่เอา Always) ด้วย string ตรงๆ เช่น "ใช้แสดงแผนที่เพื่อเลือกตำแหน่งที่ตั้งร้าน" — แอปไม่ prompt ผู้ใช้ก็ได้ แต่ string ต้องมี
   - สรุป: **มี map/geocoding = ต้องมี `NSLocationWhenInUseUsageDescription` เสมอ** (แต่ยังตัด Always/background ได้ถ้าไม่ใช้)
   เขียนให้เจาะจง (บอก "ทำไม"):
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>ใช้ตำแหน่งเพื่อนำทางไปจุดรับ-ส่งและรับงานใกล้คุณ</string>
   <key>NSCameraUsageDescription</key>
   <string>ใช้กล้องเพื่อถ่ายรูปเอกสารยืนยันตัวตนและรูปโปรไฟล์</string>
   <key>NSPhotoLibraryUsageDescription</key>
   <string>ใช้เลือกรูปจากคลังภาพเพื่ออัปโหลดโปรไฟล์/เอกสาร</string>
   ```
2. **ห้ามขอสิทธิ์ตอนเปิดแอปโดยไม่มีบริบท** — ต้อง in-context (Guideline 5.1.1)
3. **App Privacy "nutrition labels"** ใน App Store Connect → ประกาศชนิดข้อมูลที่เก็บ/ใช้ (Location, Photos, Contact Info ฯลฯ) ให้ตรงกับที่ขอจริง
4. **Background location (Always)** = ถูกตรวจหนัก ต้องมีเหตุผลชัดว่าจำเป็น (เช่น Driver ส่งพิกัดตอนวิ่งงาน) + แอปจะโชว์ location indicator สีฟ้า/ม่วง; ถ้าไม่จำเป็น **ใช้ WhenInUse พอ**
5. ถ้ามี tracking ข้ามแอป/โฆษณา → ต้องมี **App Tracking Transparency** (`NSUserTrackingUsageDescription` + prompt) — ปกติแอปเราไม่ต้อง

---

## ขั้นที่ 5 — ให้ผ่าน Google Play

1. **ทุก permission ต้องมีฟีเจอร์รองรับ** ไม่งั้นผิด Permissions policy
2. **POST_NOTIFICATIONS** (Android 13+) → declare + request runtime
3. **รูป/สื่อ**: Android 13+ ใช้ **Photo Picker** (ไม่ต้องขอ permission) แทน `READ_MEDIA_IMAGES`/`READ_EXTERNAL_STORAGE`
   - ถ้าใช้ broad media permission จะเข้า **Photo and Video Permissions policy** ต้องยื่นแบบฟอร์มอธิบาย → เลี่ยงด้วย Photo Picker ดีสุด (image_picker บน Android 13+ ใช้ Photo Picker ให้อยู่แล้ว)
4. **Background location** (`ACCESS_BACKGROUND_LOCATION`):
   - ต้องมี **prominent in-app disclosure** ก่อนขอ (อธิบายชัด + แอปทำงานเบื้องหลัง)
   - ต้องยื่น **Location Permissions Declaration** ใน Play Console (อาจต้องแนบวิดีโอ demo) → review นาน
   - ถ้าไม่จำเป็นจริง **อย่าขอ** — ใช้ foreground + foreground service แทน
5. **Foreground service** (เช่น Driver ส่งพิกัดตอนวิ่งงาน) Android 14+:
   - ประกาศ `android:foregroundServiceType="location"` + permission `FOREGROUND_SERVICE_LOCATION`
   - ยื่นแบบฟอร์ม Foreground Service ใน Play Console อธิบาย use case
6. **Data safety form** ใน Play Console → ประกาศชนิดข้อมูลที่เก็บ/แชร์ (Location, Photos ฯลฯ) ให้ตรง
7. **Target API level** ต้องถึงเกณฑ์ล่าสุดที่ Play บังคับ (เช็คตอนอัปโหลด)

---

## Checklist ก่อนส่งสโตร์ (ทำต่อแอป)
- [ ] Audit: ทุก permission map กับฟีเจอร์จริง; ลบที่ไม่ใช้ (รวมที่ plugin inject)
- [ ] iOS: มี purpose string ครบทุกสิทธิ์ที่แตะ + เจาะจง
- [ ] ขอสิทธิ์แบบ in-context (ไม่ขอตอน launch)
- [ ] จัดการเคส denied / permanentlyDenied (→ openAppSettings)
- [ ] Android 13+: ใช้ Photo Picker แทน media permission; POST_NOTIFICATIONS runtime
- [ ] Background location: ตัดถ้าไม่จำเป็น; ถ้าจำเป็น → disclosure + Play declaration + iOS justification
- [ ] Foreground service (ถ้ามี): type + Play declaration
- [ ] Play Data safety + Apple App Privacy labels ตรงกับสิทธิ์ที่ขอจริง

---

## อ้างอิงการทำฝั่ง Merchant (ทำแล้ว)
- ตัด location ทั้งหมด (ไม่จำเป็น): PR #38 — ลบ NSLocation keys + `myLocationEnabled:false`; merged manifest ไม่มี LOCATION
- แจ้งเตือน/กล้อง/คลังรูป = request-on-use
- iOS test-sound: ต้องขอ iOS notification permission เอง เพราะ dev build ไม่มี Firebase (PR #37)
