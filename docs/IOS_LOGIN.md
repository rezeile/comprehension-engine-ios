## iOS Login and Authentication Plan (ComprehensionEngine)

This document proposes a careful, modern, and regression-safe plan to add a new SwiftUI login experience to the iOS app `ComprehensionEngine/` that leverages the shared backend `backend/` used by the web frontend `frontend/`.

### Goals

- **New login UI**: SwiftUI screen with "Continue with Google" and "Continue with Apple".
- **Shared identity**: If a user signs in with Google on iOS, they are recognized as the same account used on web (and see the same chat history when server endpoints are available).
- **No regressions**: Preserve current app behavior; changes are additive and modular.
- **Decoupled logout**: Logging out on iOS does not affect web, and vice versa.
- **Modern patterns**: Use current SwiftUI and iOS auth best practices; avoid legacy APIs.

### Current Backend Auth Overview (reference)

- Google OAuth in `backend/auth/oauth.py` and routes in `backend/api/auth_routes.py`.
  - Web uses server-driven OAuth: `GET /api/auth/login` → Google → `GET /api/auth/callback` → sets `ce_access_token` and `ce_refresh_token` cookies → redirect to web.
  - Token refresh: `POST /api/auth/refresh` returns JSON `{ access_token, refresh_token, ... }`.
  - User info: `GET /api/auth/me` uses bearer or cookies.
- The backend currently has no Apple Sign In endpoint.
- The web frontend also sends `Authorization: Bearer <access_token>` from localStorage when present.

### Architecture Decision: Mobile Auth Uses Token Exchange

For iOS we will use native sign-in SDKs to get an identity token or Google access token locally, then exchange it with the backend for our app's JWTs.

- **Google (primary)**: Use `GoogleSignIn` (SPM). Obtain a Google access token and call a new backend endpoint to exchange for app JWTs.
- **Apple (optional in phase 2)**: Use `Sign in with Apple` to obtain `identityToken` (JWT). Post to a new backend endpoint to exchange for app JWTs.

This avoids web-style cookie redirects and guarantees logout independence (mobile keeps tokens in Keychain; web keeps cookies in the browser).

### Backend Changes (minimal, additive)

Add two new endpoints; reuse existing token creation and user upsert logic.

1) `POST /api/auth/mobile/google`
- **Request**:
```json
{ "access_token": "<google_access_token>" }
```
- **Behavior**:
  - Validate token by calling Google `userinfo` (already implemented as `get_google_user_info`).
  - `create_user_from_google(db, google_user)` to upsert the user.
  - Issue app `access_token` and `refresh_token` via existing `create_access_token` and `create_refresh_token`.
- **Response**:
```json
{
  "access_token": "<jwt>",
  "refresh_token": "<jwt>",
  "token_type": "bearer",
  "expires_in": 1800
}
```

2) `POST /api/auth/mobile/apple` (Phase 2)
- **Request**:
```json
{ "identity_token": "<apple_identity_jwt>", "full_name": "optional", "email": "optional" }
```
- **Behavior**:
  - Verify Apple `identity_token` against Apple JWKs.
  - Extract `sub` (Apple user ID), `email` (if available), link by email when possible.
  - Create or update user (introduce `apple_id` column if not present; link by email when appropriate).
  - Issue app tokens as above.
- **Response**: Same shape as Google mobile endpoint.

3) CORS / Auth
- Allow mobile app origins as needed (mostly irrelevant since we use direct HTTPS and bearer headers, not web views).
- Keep existing web cookie logic unchanged; do not set cookies for mobile endpoints.

### Token Lifecycle (iOS)

- Store `access_token` and `refresh_token` in the **Keychain**.
- Attach `Authorization: Bearer <access_token>` to all API requests from iOS.
- On 401/expired token, call `POST /api/auth/refresh` with the `refresh_token` and retry once.
- Do not use cookie auth on iOS; do not call `/api/auth/logout` (cookies), simply clear Keychain on mobile logout.

### iOS App Changes

#### 1) Add `AuthManager` (ObservableObject)

- Responsibilities:
  - Expose `@Published var isAuthenticated: Bool`, `@Published var user: User?`, loading/error states.
  - `signInWithGoogle(presenting:)` → obtain Google `accessToken` → exchange at `/api/auth/mobile/google` → store tokens in Keychain → fetch `/api/auth/me` to populate `user`.
  - `signInWithApple()` (phase 2) → obtain Apple `identityToken` → exchange at `/api/auth/mobile/apple` → store tokens → fetch `me`.
  - `refreshTokensIfNeeded()` and `logout()` (clear Keychain and in-memory state).
  - Migrate any pre-existing ad-hoc auth header usage into this single source of truth.

Keychain keys:
- `ce.access_token`
- `ce.refresh_token`

#### 2) Update `BackendAPI` to use AuthManager tokens

- Add a dependency (injected or singleton accessor) to retrieve the current `access_token`.
- Set `Authorization` header for all requests if a token is present.
- When a request fails with 401, have a retry policy that asks `AuthManager` to refresh, then retries once.
- Keep existing API behavior otherwise (chat, TTS, etc.)

#### 3) SwiftUI Login Screen

- A new SwiftUI view: `LoginView` with:
  - Title, brief description.
  - Buttons:
    - "Continue with Google" using `GoogleSignIn` via `GIDSignIn.sharedInstance.signIn(withPresenting:)`.
    - "Continue with Apple" using `SignInWithAppleButton` (`AuthenticationServices`) (phase 2).
  - Non-blocking error banners for failures.
  - Accessibility labels.

Navigation:
- On app launch, if tokens are valid in Keychain → show the main chat UI.
- Otherwise → show `LoginView`.
- Use a lightweight `AppViewRouter` or a top-level `@StateObject` `AuthManager` bound to the root `ContentView` to switch screens.

#### 4) Configuration (Xcode)

- Add `GoogleSignIn` via Swift Package Manager.
- Add `Sign in with Apple` capability (phase 2).
- Add URL Type with Google reversed client ID in `Info.plist` (`GIDClientID` setup) so that Google Sign-In can return to the app.
- Ensure `BACKEND_BASE_URL` remains configured in `Info.plist` for `BackendAPI`.

### Chat History Parity with Web

The web references conversation endpoints (e.g., `GET /api/conversations`, `GET /api/conversations/{id}/turns`), but these may not yet exist server-side.

- If these endpoints are available: implement `ConversationService` on iOS mirroring the web’s `ConversationService.ts` to list conversations and turns, authenticated by bearer.
- If not available: keep current local-session behavior and plan a small backend follow-up to add:
  - `GET /api/conversations?limit=&offset=` → list user’s conversations.
  - `GET /api/conversations/{id}/turns?limit=&offset=` → list message history.
  - `PATCH /api/conversations/{id}` → update title/topic/active flag.

### Logout Independence

- iOS logout: clear Keychain tokens, reset `AuthManager` state. No backend call required.
- Web logout: clears cookies via `/api/auth/logout` and does not affect iOS.
- Because iOS uses bearer headers and web uses cookies (with optional localStorage), the two sessions are independent by design.

### Error Handling and UX

- Show inline, human-readable errors for sign-in failures (network, token exchange, verification).
- Distinguish recoverable (retry) vs. non-recoverable (configuration) errors.
- Telemetry hook (optional) to log auth errors for diagnostics.

### Security Notes

- Store tokens in Keychain only; never in `UserDefaults`.
- Use HTTPS only; enforce ATS.
- Use short-lived access tokens; rely on refresh token to renew.
- On refresh failure, force re-authentication.
- Do not leak tokens into logs.

### Test Plan

- Unit tests (iOS):
  - `AuthManager`: token persistence, refresh, logout, error paths.
  - `BackendAPI`: header injection, 401 retry once after refresh.
- Integration tests (manual and automated where possible):
  - Sign in with Google → token exchange success; user visible in `/api/auth/me`.
  - App restart → auto sign-in via Keychain tokens and refresh.
  - Logout on iOS → web session remains active; web logout → iOS remains active.
  - If conversation APIs exist → fetch conversation list/turns and render.
- Backend tests:
  - `POST /api/auth/mobile/google` happy path, invalid token, expired token.
  - (Phase 2) `POST /api/auth/mobile/apple` verification and linking by email.

### Rollout Plan

1) Implement backend `POST /api/auth/mobile/google` in a PR; do not change existing web endpoints.
2) Add iOS `AuthManager`, Keychain helpers, and `LoginView`. Wire into `BackendAPI` and root view.
3) QA on Simulator and device; verify endpoint environments via `BACKEND_BASE_URL`.
4) Optional phase 2: Add Apple Sign In endpoint + UI; re-run the test matrix.
5) Optional phase 3: Integrate conversation history once backend endpoints are confirmed or implemented.

### API Contracts (Reference)

- `POST /api/auth/mobile/google`
  - Request: `{ "access_token": "<google_access_token>" }`
  - Response: `{ "access_token": "<jwt>", "refresh_token": "<jwt>", "token_type": "bearer", "expires_in": 1800 }`

- `POST /api/auth/mobile/apple` (phase 2)
  - Request: `{ "identity_token": "<apple_identity_jwt>", "full_name": "optional", "email": "optional" }`
  - Response: `{ "access_token": "<jwt>", "refresh_token": "<jwt>", "token_type": "bearer", "expires_in": 1800 }`

- `POST /api/auth/refresh`
  - Request: `{ "refresh_token": "<jwt>" }`
  - Response: `{ "access_token": "<jwt>", "refresh_token": "<jwt>", "token_type": "bearer", "expires_in": 1800 }`

### Non-Goals

- Do not modify existing web auth flows or cookies.
- Do not couple iOS sign-in to web redirects.
- Do not change current chat logic beyond adding bearer header support and optional conversation history fetch.

### Implementation Notes (SwiftUI Patterns)

- Prefer `@MainActor` for UI updates, `@StateObject` for `AuthManager` at app root, and dependency injection for `BackendAPI`.
- Use `GIDSignIn.sharedInstance.signIn(withPresenting:)` (not deprecated `presenting:` API) for Google.
- Use `SignInWithAppleButton` from `AuthenticationServices` for Apple (phase 2) with `ASAuthorizationControllerDelegate` bridged to SwiftUI.
- Ensure accessibility: button labels, hints, and dynamic type support in `LoginView`.

This plan keeps iOS and web sessions independent while unifying identity in the backend and enabling shared chat history when endpoints are available.


