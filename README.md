# mapcars_driver

Mapcars — UK ride-hailing **driver** mobile app (Flutter). Pure client: it talks
to the Mapcars .NET API over HTTP and never touches a database directly.

## Run

```bash
flutter pub get

# Android emulator (default — API at 10.0.2.2:5126)
flutter run

# Physical device — point at your PC's LAN IP
flutter run --dart-define=LOCAL_API=http://192.168.1.20:5126

# Staging / production builds
flutter run   --dart-define=APP_ENV=staging
flutter build apk --dart-define=APP_ENV=prod
```

Start the API first (see `api/`). Accounts / keys this app needs are in
[instruction.md](instruction.md).

## Architecture

Feature-first, layered, mirrors the sibling `customer_app` so both apps stay
consistent. Dependencies point inward: presentation → providers → services →
core. `core/` never imports a feature.

```
lib/src/
├─ core/
│  ├─ config/      app_config.dart (env by --dart-define), env.dart (.env overrides)
│  ├─ network/     dioProvider + auth/error interceptors, apiCall(), ApiException
│  ├─ storage/     secure_store.dart (Keystore / Keychain)
│  ├─ router/      go_router with auth-aware redirect guard (routerProvider)
│  ├─ theme/       brand tokens + Material themes
│  └─ widgets/     shared design-system widgets (mc.dart)
└─ features/<feature>/
   ├─ models/        immutable state + DTO mappers (e.g. AuthState, AuthSession)
   ├─ services/      typed API calls for the feature (e.g. DriverAuthService)
   ├─ providers/     Riverpod notifiers exposing state to the UI (AuthNotifier)
   └─ presentation/  screens / widgets
```

### How the layers fit together

- **State management:** Riverpod. `AuthNotifier` (a `StateNotifier<AuthState>`)
  owns the auth flow; screens `watch` it for loading/error/dev-OTP and call its
  methods. Add a notifier per feature rather than `setState` for shared state.
- **Networking:** every request goes through `dioProvider`. An interceptor
  injects the `Bearer` token; on a `401` for an authenticated call it clears the
  token and bumps `unauthorizedProvider`, which `AuthNotifier` listens to and
  signs out — so an expired session bounces the driver back to onboarding.
  `apiCall()` converts `DioException` → `ApiException` (friendly messages).
- **Auth contract:** `DriverAuthService` maps 1:1 to
  `Mapcars.Api/Controllers/DriverAuthController.cs` (`/api/v1/auth/drivers/*`).
- **Persistence:** `SessionRepository` writes the `AuthSession` to secure
  storage; the splash screen restores it on launch (`AuthNotifier.restore()`).
- **Routing & guards:** `routerProvider` re-evaluates a redirect whenever the
  token changes. Auth gating is enforced in staging/prod; local dev keeps the
  full prototype walk-through open so every screen is browsable.

### Adding a feature

Copy the **auth** slice as the template: `models/` (state + JSON mappers) →
`services/` (typed Dio calls returning your models, wrapped in `apiCall`) →
`providers/` (a notifier) → `presentation/` (screens that watch the notifier).
Change the API contract first; never hand-edit client shapes to diverge from it.

## Test

```bash
flutter test
```
