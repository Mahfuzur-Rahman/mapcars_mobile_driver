# Mapcars Driver — Run & Test Instructions

Flutter **driver** mobile app (`mapcars_driver`). Feature-first structure under
`lib/src/`. Talks **only** to the Mapcars .NET API.

> ✅ Flutter is installed, native folders (`android/`, `web/`) are generated, and
> all **16 driver screens** are built as a clickable/swipeable **UI prototype**
> (no backend wired yet — sample data is hardcoded). Just run it (section 5).

## The prototype
- Opens on **Splash → Intro (swipe) → Verify → Registration → Documents →
  Under review → Continue to app → Home**.
- From **Home** (online toggle) tap the waiting card to simulate an incoming
  **request → navigate → arrived → driving → trip complete**. Tabs reach
  **Earnings / Profile / Settings**.
- The splash has a **"Browse all screens"** link (route `/screens`) to jump to
  any screen directly.
- Same design system as the customer app (`lib/src/core/`); screens are in
  `lib/src/features/<onboarding|drive|account>/presentation/`.

## 1. Install Flutter (already done on this machine)

```powershell
winget install --id=Google.Flutter -e
winget install --id=Google.AndroidStudio -e   # Android SDK + adb + emulator
flutter doctor
```

## 2. Native folders — already generated
If you ever need to regenerate them (back up `pubspec.yaml` + `lib/main.dart` first):

```powershell
cd mobile/driver_app
flutter create --platforms=android,web --org com.mapcars --project-name mapcars_driver .
flutter pub get
```

## 3. Config / accounts you will need

| Service | What for | Where it goes | Free to start? |
|---------|----------|---------------|----------------|
| **Mapbox** | Map + navigation on device | `.env` → `MAPBOX_TOKEN` | Yes — free tier |
| (the API) | All app data | `.env` → `API_BASE_URL` | Local, free |

```powershell
copy .env.example .env   # then edit values
```

## 4. Point the app at your API

- **Android emulator:** `API_BASE_URL=http://10.0.2.2:5126` (already the default).
- **Physical Android phone:** use your PC's LAN IP, e.g.
  `API_BASE_URL=http://192.168.1.20:5126`. Find it with `ipconfig`. Phone and PC
  must be on the same Wi-Fi.

## 5. Run & test on your Android phone

1. Phone: Settings → About → tap **Build number** ×7 → enable **USB debugging**.
2. Plug in via USB, accept the debugging prompt.
3. ```powershell
   flutter devices    # confirm your phone shows up
   flutter run
   ```
4. The home screen shows the **online/offline toggle** and an **API connection**
   indicator. Green = it reached `/api/v1/ping`. Start the API first
   (`../../api/instruction.md`).

> 💡 You can run **both apps at once** on two devices/emulators — start the
> customer app from `mobile/customer_app` and the driver app from here.

Hot reload: press `r` (reload) / `R` (restart) / `q` (quit) in the terminal.

## 6. Maps / navigation (later)
Uncomment `mapbox_maps_flutter` in `pubspec.yaml`, set `MAPBOX_TOKEN`, and add the
Android `minSdkVersion 21` + Mapbox download token per the package README.
