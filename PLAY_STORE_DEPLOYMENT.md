# Mapcars Driver App — Google Play Store Deployment Tracker & History

This document serves as the live log, interactive checklist, and step-by-step record for publishing the **Mapcars Driver App** (`com.mapcars.mapcars.driver`) to the **Google Play Store**.

---

## 📌 App Overview & Metadata

| Field | Value |
|---|---|
| **App Name** | Mapcars Driver |
| **Package Name (Application ID)** | `com.mapcars.mapcars.driver` |
| **Target Country / Region** | United Kingdom (UK) |
| **Category** | Maps & Navigation / Business |
| **Default Language** | English (United Kingdom) – `en-GB` |
| **Privacy Policy URL** | `https://mapcars.uk/legal/privacy` (canonical — `/privacy.html` 301-redirects here, use the direct URL in Play Console) |
| **Account Deletion Support** | Via email to `info@mapcars.uk` (§10 "Delete account" on the Privacy Policy page) |

---

## 📅 Deployment Progress & History Log

| Date | Milestone / Action | Status | Notes |
|---|---|---|---|
| **2026-08-01** | Deployment Tracker initialized | ✅ Done | Initialized deployment strategy & tracker document. |
| **2026-08-01** | App Access / Sign-in details | ✅ Done | Demo driver credentials configured for review team. |
| **2026-08-01** | Content Ratings Questionnaire | ✅ Done | IARC rating submitted. |
| **2026-08-01** | Store Listing & Visual Assets | ✅ Done | Short/Full descriptions and graphics uploaded. |
| **2026-08-01** | Android SDK 36 Build Fix | ✅ Done | Resolved `:file_picker` compileSdk dependency conflict. `flutter build apk` succeeds. |
| **2026-08-01** | Android Release Keystore Generation | ✅ Done | `upload-keystore.jks` + `key.properties` generated 2026-08-09, backed up to `keys/mobile/driver_app/android/`. |
| **2026-08-09** | Production App Bundle (`.aab`) Build | ✅ Done | `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab` (66.6MB), version `0.1.0+1`. |
| **2026-08-09** | App Bundle Rebuilt | ✅ Done | First `.aab` predated the FCM `main.dart`/`env.dart` wiring (built 21:36, code edited 21:42). Rebuilt clean at 22:09 → `app-release.aab` (69.8MB, still `0.1.0+1`), confirmed signed with the release keystore. |
| **2026-08-10** | App Bundle Rebuilt (v2) | ✅ Done | Picked up recent account/onboarding changes (`vehicle_form_screen.dart`, `verify_screen.dart`, `driver_profile_form.dart`, `documents_screen.dart`, `profile_screen.dart`, etc.) predating the 08-09 build. Bumped to `0.1.0+2` → `app-release.aab` (66.6MB), confirmed signed with the release keystore. **Use this build**, not the 08-09 one. |
| **Pending** | App Content & Policy Declarations | ⬜ Pending | Data safety, Privacy Policy, Target Audience, Review Credentials. |
| **Pending** | Internal / Closed Testing Track Release | ⬜ Pending | First upload of `.aab` file and testing setup. |
| **Pending** | Production Release & Play Store Review Submission | ⬜ Pending | Submit for final Google review. |

---

## 🛠️ Step-by-Step Deployment Roadmap

### Phase 1: Local App & Build Preparation
- [ ] **1.1 Keystore Generation**: Create Android release signing key (`upload-keystore.jks`).
- [ ] **1.2 Key Properties Setup**: Create `android/key.properties` with keystore credentials.
- [ ] **1.3 Version Code & Name**: Verify `pubspec.yaml` version (e.g. `1.0.0+1`).
- [ ] **1.4 Package Name Verification**: Confirm package name `com.mapcars.mapcars.driver`.
- [ ] **1.5 Assets & Icons**: Verify launcher icon & native splash screen assets.
- [ ] **1.6 Environment & API Keys**: Verify Google Maps API Key and Firebase `google-services.json`.
- [ ] **1.7 Build Release Bundle**: Execute `flutter build appbundle --release`.

### Phase 2: Google Play Console Configuration
- [ ] **2.1 Developer Account**: Verify active Google Play Developer Account ($25 registration completed).
- [ ] **2.2 Create App**: Create new app entry for "Mapcars Driver".
- [ ] **2.3 Store Listing Setup**:
  - [ ] App Name, Short Description, Full Description.
  - [ ] App Icon (512x512 px PNG).
  - [ ] Feature Graphic (1024x500 px PNG).
  - [ ] Phone Screenshots (Min 2, recommended 4-8 high-resolution screenshots).
- [ ] **2.4 App Content & Compliance**:
  - [ ] Privacy Policy URL (`https://mapcars.uk/privacy.html`).
  - [ ] App Access (Provide test driver login credentials / phone number for Play review team).
  - [ ] Content Ratings Questionnaire.
  - [ ] Target Audience & Content (18+ / Adults).
  - [ ] Data Safety Form (Filled using `mobile/docs/play-store/DATA_SAFETY.md`).
  - [ ] Government Apps & Financial Features declaration.

### Phase 3: Release & Submission
- [ ] **3.1 Internal / Closed Testing**: Upload `.aab` bundle to Internal Testing track.
- [ ] **3.2 Tester Verification**: Install via Play Store link and verify location, FCM, maps, and login work.
- [ ] **3.3 Production Release**: Promote build to Production track and submit for Google Review.

---

## 💬 Q&A & Decision History

*Record of key deployment decisions, questions asked, and answers provided.*

- **Q1: What signing key format and location should we use?**
  - *Answer:* Use standard Java keystore (`upload-keystore.jks`) placed in `android/` directory (gitignored), configured via `android/key.properties`.
- **Q2: Can the Privacy Policy URL (`https://mapcars.uk/legal/privacy`) be changed later?**
  - *Answer:* Yes, absolutely. You can update your Privacy Policy URL in Play Console at any time under **App content → Privacy policy**.
- **Q3: What sign-in credentials should be provided to Google Play Review team?**
  - *Answer:* Provide the demo driver credentials (`driver@mapcars.co.uk` / `Driver@1234` or Phone `+447700900000` with OTP `000000`).


