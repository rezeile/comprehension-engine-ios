## Goal

Create a beautiful, elegant, non-scroll login/landing experience for the iOS companion (SwiftUI) that mirrors the polish targeted in the web `frontend/` after `BEAUTIFY.md` is implemented. Preserve existing auth logic while elevating the first-run and logout experiences with refined visuals, motion, and accessibility.

## Success Criteria (Acceptance Tests)

- **Full-viewport, non-scroll login screen** with a multi‑color gradient background, grain/noise overlay (optional), and high contrast overlay for text.
- **Lightweight marketing header**: brand icon on the left, minimal wordmark, nothing else.
- **Centered CTA**: a single primary button “Continue with Google”; no email option.
- **Immediate processing transition**: within ~100ms after tapping the CTA, show a branded processing view/overlay while the Google OAuth flow proceeds.
- **Smooth logout**: fade/scale transition from the authenticated app back to the login screen without a harsh flash.
- **Accessibility**: Dynamic Type, VoiceOver labels/hints, sufficient contrast, and reduced-motion support.
- **Unit/UI tests** verifying: render states, CTA presence, absence of email form, immediate route-to-processing, logout transition, and basic a11y checks.

## UX Copy (Proposals)

- **Headline (recommended)**: “Learn Faster, Deeper”
- **Subheader (recommended)**: “Your AI learning companion that personalizes how you understand complex ideas—accelerating mastery by an order of magnitude.”

Other four-word options (shortlist):
- **Understand Anything, Faster**
- **Accelerate Human Understanding**
- **Master Complex Ideas**
- **Clarity at Speed**
- **Insight, On Demand**
- **Think Deeper, Faster**
- **Personalized Learning Velocity**
- **10x Your Mastery**
- **Precision Learning Engine**
- **From Confusion to Clarity**

Alternate subheaders (choose one if preferred):
- **A personal AI that learns how you learn to boost comprehension and retention.**
- **Cut through complexity with a companion that adapts to your cognition.**
- **Turn dense material into rapid, durable understanding.**

## Visual and Layout Spec (SwiftUI)

- **Full-bleed, non-scroll**: use `ZStack` with `.ignoresSafeArea()` and a container that fills the screen.
- **Gradient background**: 3–4 color linear/anglular gradient, subtle grain/noise overlay for depth; add semi-transparent dark overlay for contrast.
- **Header**: left-aligned brand icon (reuse app icon or add `brand-icon` in assets), lightweight wordmark text; no nav or secondary content.
- **Center stack**: H1, subheader, primary CTA; align to center, responsive to Dynamic Type.
- **CTA**: A11y-first, high contrast, focus ring visible; Google icon to the left.
- **Processing**: branded cube/diamond loader (SwiftUI shapes + transforms + blur/glow). Fallback to `ProgressView` when `UIAccessibility.isReduceMotionEnabled == true`.
- **Transitions**: cross-fade + slight scale on screen change; respect reduced motion (disable or reduce to opacity-only when enabled).

## Information Architecture (Mapping from Web to iOS)

- **Route `/login` → `LoginView`**: marketing-first design replaces current stack.
- **Route `/auth/processing` → `AuthProcessingView` (new)**: branded loader during sign-in.
- **Post-auth redirect → `ContentView`** unchanged.
- **Global gate → `RootView`** continues to switch between authenticated and unauthenticated states, now with animated transitions.

Current relevant views/state:

```7:41:/Users/eliezerabate/Documents/ComprehensionEngine/ComprehensionEngine/Views/LoginView.swift
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            VStack(spacing: 8) {
                Text("Welcome to Comprehension Engine")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Text("Sign in to sync your experience across devices.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            VStack(spacing: 12) {
                GoogleSignInFlatButton()
                    .accessibilityLabel("Continue with Google")
                    .accessibilityHint("Sign in using your Google account")
            }
            .padding(.horizontal, 24)

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .overlay(auth.isLoading ? ProgressView().progressViewStyle(.circular) : nil)
    }
```

```6:15:/Users/eliezerabate/Documents/ComprehensionEngine/ComprehensionEngine/Views/RootView.swift
    var body: some View {
        Group {
            if !requireLoginEnabled() || auth.isAuthenticated {
                ContentView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: auth.isAuthenticated)
    }
```

## Implementation Plan (Discrete Tasks)

1) Asset Prep
- **Export iOS icon** `1024.png` (already present under `Assets.xcassets/AppIcon.appiconset/`) into a reusable asset named `brand-icon` for header use.
- **Optional grain/noise overlay**: add a small transparent PNG (e.g., `noise_512.png`) scaled to fill the screen with low opacity.
- Ensure current app icons remain intact; do not regress asset catalogs.

2) Marketing Header Component
- **New** `ComprehensionEngine/Views/Shared/MarketingHeader.swift`
  - Left-aligned `Image("brand-icon")` (or app icon), fixed size, with corner radius and subtle shadow.
  - Wordmark `Text("Comprehension Engine")` using `Typography.swift` (e.g., `.heading3()`), color from `AppColors.textPrimary` with high contrast.
  - Layout: `HStack` with safe-area padding, max width alignment leading.
  - A11y: `accessibilityElement(children: .combine)`, label as “Comprehension Engine, home header”.

3) Login Page Redesign
- **Edit** `ComprehensionEngine/Views/LoginView.swift` layout:
  - Replace top-level `VStack` with `ZStack` full-screen gradient background using brand stops.
  - Add `MarketingHeader` pinned to top-left.
  - Center content stack with recommended H1 and subheader using typography presets.
  - Remove any email or secondary auth UI; show only Google CTA component.
  - Button: keep existing Google button logic; visually restyle to be the primary CTA with focus ring and hover/press states (iOS interaction variants).
  - Introduce a local `@State private var isProcessing: Bool` that flips true on tap, then navigates (or overlays) to processing within ~100ms while `AuthManager` handles the OAuth flow.
  - A11y: set `accessibilitySortPriority` to make the CTA first, provide descriptive label/hint, and ensure Dynamic Type wraps gracefully.

4) Processing Screen
- **New** `ComprehensionEngine/Views/Auth/AuthProcessingView.swift`
  - Branded cube/diamond loader built with `RoundedRectangle`/`Rectangle` rotated, blurred glow using `shadow` or `blur` + `blendMode`.
  - Use `TimelineView(.animation)` to drive smooth rotation at 60fps; fallback to `ProgressView` when `UIAccessibility.isReduceMotionEnabled == true`.
  - Provide `accessibilityLabel("Signing in")` and `accessibilityHint("Please wait")`.
  - Visual variant: small animated glow behind the shape; ensure contrast.

5) Navigation and State Flow
- **Option A (simplest)**: Keep `AuthProcessingView` as an overlay in `LoginView` when `isProcessing || auth.isLoading`.
  - Pros: minimal change to `RootView` logic; keeps auth logic untouched.
  - Behavior: on tap → set `isProcessing = true` → trigger `Task { await signIn() }` → overlay `AuthProcessingView` until `auth.isAuthenticated` or error.
- **Option B (route-like)**: Update `RootView` to show `AuthProcessingView` when `auth.isLoading` is true.
  - Add a computed `isAuthenticating` in `AuthManager` or set `isLoading` semantics specifically during login.
  - Switch `RootView`’s unauthenticated branch between `LoginView` and `AuthProcessingView` based on the flag for a clearer state machine.

6) Smooth Logout Transition
- Animate the transition in `RootView` when `auth.isAuthenticated` flips to false.
  - Wrap state change handling with `withAnimation(.easeInOut(duration: 0.2))`.
  - Apply transitions: `.transition(.opacity.combined(with: .scale(scale: 0.98)))` on the container.
  - Respect reduced motion: when `UIAccessibility.isReduceMotionEnabled`, reduce to `.opacity` only.

7) Theming & Tokens
- **Update** `ComprehensionEngine/Styles/ColorScheme.swift`:
  - Add brand gradient stops to match web idea: `#7C3AED` → `#EC4899` → `#22D3EE` → `#F59E0B`.
  - Expose helpers:
    - `static var brandGradientStops: [Color]`
    - `static func brandLinearGradient() -> LinearGradient`
    - `static func brandAngularGradient() -> AngularGradient`
  - Add `brandGlow` color and `focusRing` color.
- **Typography** `ComprehensionEngine/Styles/Typography.swift`:
  - Confirm hero/display sizes cover the H1 and subheader needs (e.g., `displayHero`, `bodyLarge`).
  - Ensure presets handle Dynamic Type gracefully; audit line height/letter spacing for legibility on gradient.

8) Accessibility
- **Contrast**: overlay a semi-transparent black layer (`Color.black.opacity(0.25)`) above the gradient behind text blocks to ensure >= 4.5:1.
- **Dynamic Type**: use `.minimumScaleFactor` cautiously for the H1, allow wrapping; test with larger accessibility sizes.
- **VoiceOver**: CTA labeled “Continue with Google”; loader labeled “Signing in”; hide purely decorative animation with `accessibilityHidden(true)`.
- **Reduced Motion**: gate animations with `UIAccessibility.isReduceMotionEnabled`.

9) Testing (XCTest + XCUITest)
- **Unit/UI Structure**:
  - `ComprehensionEngineTests/LoginViewTests.swift`
    - Assert header, H1, subheader, and CTA are present; email UI absent.
    - Verify gradient/background presence via view hierarchy markers (use `accessibilityIdentifier` on wrappers).
  - `ComprehensionEngineTests/AuthProcessingViewTests.swift`
    - Ensure loader renders; when reduced motion is enabled, `ProgressView` is shown.
  - `ComprehensionEngineUITests/LoginFlowUITests.swift`
    - Tap CTA; assert processing view appears within ~100ms (measure with `XCTWaiter` and expectation on element’s existence).
    - Mock `AuthManager` to return success and transition into `ContentView`.
  - `ComprehensionEngineUITests/LogoutTransitionUITests.swift`
    - From authenticated state, trigger `logout()`; assert fade/scale, then `LoginView`.
- **A11y**: basic checks for labels/hints and Dynamic Type sizing; ensure elements are hittable.

10) Performance
- Prefer `opacity` and `transform` animations for 60fps.
- Keep loader vector-based (no heavy images); avoid large offscreen blurs.
- Use `.drawingGroup()` sparingly; measure with Instruments if needed.

11) Rollout & Fallbacks
- Feature-flag showing the new marketing login via `Info.plist` key (e.g., `NEW_LOGIN_ENABLED = true`).
- Provide a fallback path that shows a simple `ProgressView` if any loader assets/animations fail.

## File Touch List

- `ComprehensionEngine/Views/Shared/MarketingHeader.swift` (new)
- `ComprehensionEngine/Views/Auth/AuthProcessingView.swift` (new)
- `ComprehensionEngine/Views/LoginView.swift` (edit)
- `ComprehensionEngine/Views/RootView.swift` (optional small update if opting for route-like processing)
- `ComprehensionEngine/Styles/ColorScheme.swift` (add gradient/focus tokens)
- `ComprehensionEngine/Styles/Typography.swift` (verify presets; tweak if needed)
- `ComprehensionEngine/Assets.xcassets/brand-icon.imageset` (new, sourced from `AppIcon.appiconset/1024.png`)
- `ComprehensionEngine/Assets.xcassets/noise.imageset` (optional)
- Tests (new):
  - `ComprehensionEngineTests/LoginViewTests.swift`
  - `ComprehensionEngineTests/AuthProcessingViewTests.swift`
  - `ComprehensionEngineUITests/LoginFlowUITests.swift`
  - `ComprehensionEngineUITests/LogoutTransitionUITests.swift`

## Implementation Notes (Guidance Snippets)

- **Login background**
  - Use a gradient helper from `AppColors`:
    - `AppColors.brandLinearGradient()` as the background layer.
    - Optional `Color.black.opacity(0.25)` overlay behind text block.
- **Loader reduced motion**
  - `if UIAccessibility.isReduceMotionEnabled { ProgressView() } else { AnimatedShape() }`.
- **CTA behavior**
  - Set `isProcessing = true` → trigger `Task { await signIn() }` → overlay `AuthProcessingView` until `auth.isAuthenticated` or error.
- **Logout**
  - Animate the change in `RootView` with `.animation` tied to `auth.isAuthenticated`; add `.transition` on child views.

## Open Questions

- Approve the **headline/subheader** or choose from the shortlist.
- **Loader preference**: cube/diamond vs. minimal spinner as the default? (We’ll implement both with graceful fallback.)
- **Header links**: keep ultra-minimal or include a subtle “Learn more” link in the header? (Default: minimal.)

## Timeline (Fast Track)

- 1.5h: Header + layout scaffolding, gradient, and copy in `LoginView`
- 1h: `AuthProcessingView` + transitions
- 0.5h: Logout transition polish in `RootView`
- 1h: Unit/UI tests and fixes
- 0.5h: Asset prep + final pass


