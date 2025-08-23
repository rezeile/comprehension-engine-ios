## iOS Google Sign-In Flow (ComprehensionEngine)

This document explains what happens when a user taps "Continue with Google" in the iOS app, and how the app interacts with the backend authentication service.

### 1) User taps "Continue with Google"
- Entry point: `Views/LoginView.swift` button `GoogleSignInFlatButton`.
- Action: Triggers `auth.startGoogleSignInFlow(presentingViewController:)` via a `Task`.

```swift
Button(action: {
    onTap?()
    Task { await signIn() }
})
```

Presenter is resolved using `UIApplication.shared.topMostViewController()` to supply a UIKit presenter to Google SDK.

### 2) Native Google Sign-In on iOS
- Location: `Managers/AuthManager.startGoogleSignInFlow`
- Uses `GoogleSignIn` SDK (guarded by `#if canImport(GoogleSignIn)`).
- Calls:
  - `GIDSignIn.sharedInstance.signIn(withPresenting: presenter)`
  - Extracts `googleAccessToken` from `signInResult.user.accessToken.tokenString`.

On success, it proceeds to exchange the Google token with your backend; on failure it sets `errorMessage` and `isAuthenticated = false`.

### 3) Token exchange with backend (mobile flow)
- Location: `AuthManager.exchangeGoogleAccessToken(_:)`
- Backend URL is resolved by `BackendAPI.resolveBaseURLString()` and Info.plist `BACKEND_BASE_URL`.
- Makes a POST to `/api/auth/mobile/google` with JSON body: `{ "access_token": "<googleAccessToken>" }`.
- Expects a `TokenResponse` containing `access_token`, `refresh_token`, `token_type`, `expires_in`.
- On success, `persistTokens(pair:)` saves tokens to Keychain (`ce.access_token`, `ce.refresh_token`) via `KeychainHelper`, mirrors them in-memory, and sets `isAuthenticated = true`.

### 4) Load user profile and session state
- After token exchange, `AuthManager.fetchCurrentUser()` GETs `/api/auth/me` with `Authorization: Bearer <access_token>` to populate `user`.
- `RootView` switches from `LoginView` to `ContentView` when `auth.isAuthenticated` is true (unless `REQUIRE_LOGIN` is false).

### 5) Token refresh lifecycle
- `AuthManager.refreshTokensIfNeeded()` and `forceRefresh()` call POST `/api/auth/refresh` with `{ "refresh_token": "..." }`.
- On success, tokens are rotated and re-persisted; on failure, user is logged out.
- `BackendAPI.performWithAuthRetry` also attempts a forced refresh on 401 during API calls and retries once with the new token.

### 6) Where values are configured (iOS)
- `Info.plist`:
  - `BACKEND_BASE_URL`: e.g., your cloudflared public tunnel URL.
  - `REQUIRE_LOGIN`: controls if login is required to enter the app.
  - `GIDClientID` and URL scheme for Google Sign-In callback within the Google SDK.

### 7) Backend endpoints involved
- File: `backend/api/auth_routes.py`:
  - `POST /api/auth/mobile/google` (used by iOS): verifies the Google access token, upserts user, returns app `access_token` and `refresh_token`.
  - `POST /api/auth/refresh`: validates refresh token and issues new tokens.
  - `GET /api/auth/me`: requires valid access token; returns current user info.
- File: `backend/auth/oauth.py`: `get_google_user_info(access_token)` calls Google UserInfo endpoint to validate the incoming Google token and obtain email/name/picture.
- File: `backend/auth/jwt_handler.py`: issues and verifies JWT `access` and `refresh` tokens.
- File: `backend/auth/dependencies.py`: extracts `Authorization` bearer or cookie for protected routes, verifies token, loads `User`.

### 8) End-to-end sequence
1. User taps button in `LoginView` → shows `AuthProcessingView` overlay while loading.
2. Google SDK UI appears; user selects account and grants access.
3. iOS receives Google `accessToken`.
4. iOS POSTs token to backend `/api/auth/mobile/google`.
5. Backend validates with Google, upserts user, returns app JWTs.
6. iOS stores tokens in Keychain and memory; `isAuthenticated = true`.
7. iOS calls `/api/auth/me` to fetch profile.
8. `RootView` transitions to `ContentView`.

### 9) Error handling
- Google sign-in errors set `auth.errorMessage` and stop the spinner.
- Backend exchange or refresh failures set appropriate errors or log out the user.
- `BackendAPI` transparently retries once on 401 after refreshing tokens via `AuthManager`.

### 10) Logout
- `AuthManager.logout()` removes tokens from Keychain and memory, resets auth state; UI returns to `LoginView` by `RootView` logic.

### 11) Notes
- Web-based `/api/auth/login` + `/callback` cookie flow is not used by iOS; iOS uses the dedicated mobile exchange endpoint.
- Ensure `GOOGLE_CLIENT_ID/SECRET`, `SECRET_KEY`, and `BACKEND_PUBLIC_URL` are set on backend; ensure `GIDClientID` and URL scheme are set in iOS `Info.plist`.
