# Spyglass — Requirements

## 1. Overview

**Spyglass** is a single-purpose macOS menu bar utility. While the user holds a
trigger key, a soft-edged circular lens follows the cursor and shows the live
content of the window hidden directly beneath the frontmost window at that
point — as if a hole were cut through the front window. Releasing the key makes
the lens vanish instantly. Clicking through the lens raises the revealed window.

- **Target user**: everyday Mac users (writers, designers, office workers, developers)
  who constantly need to "peek at something under the current window" without
  minimizing, resizing, or entering Mission Control.
- **Pain point**: "I know it's under there somewhere" — checking a reference,
  a chart, a chat, or a video hidden behind the active window currently requires
  destroying your window arrangement.
- **Platform**: macOS 14+ (Sonoma or later), Apple Silicon + Intel.
- **Distribution**: free OSS on GitHub (MIT). GitHub Releases with a notarized
  DMG; Homebrew cask later. Not sandboxed / not App Store (Screen Recording +
  Accessibility requirements make MAS impractical).
- **Tech stack**: Swift 6 / SwiftUI + AppKit, built from `macos-app-template`
  (XcodeGen `project.yml`, local package `SpyglassKit` with `SpyglassCore` /
  `SpyglassUI`, SwiftLint strict, SwiftFormat, 80% line-coverage floor on Core).

### Core value proposition (one sentence)

> Hold a key, see through your front window; release, and it never happened.

## 2. Features

### 2.1 The Lens (core feature)

**Trigger**
- Default: **hold the right ⌘ (Command) key alone**. Engages after a short
  hold threshold of **150 ms** (prevents flicker during normal right-⌘ shortcut
  use). Configurable in Settings: `Right ⌘` (default) / `⌃⌥ (Control+Option)` /
  `fn`. Detected via a `CGEventTap` on `flagsChanged` (requires Accessibility
  permission — see 2.4).
- The lens is active **only while the key is held**. Release → lens disappears
  immediately (fade-out ≤ 120 ms).
- If another modifier or any regular key is pressed while holding the trigger,
  the peek is cancelled (the user is doing a shortcut, not peeking).

**What the lens shows**
- At the cursor's screen point, resolve the topmost *normal* window under the
  cursor (call it `front`), then find the next window beneath it in z-order
  whose frame contains that point (call it `target`). The lens renders
  `target`'s live content, correctly positioned so the portion visible inside
  the lens circle corresponds to the same screen coordinates — i.e. it looks
  like a hole cut through `front`, not a thumbnail.
- **Exactly one layer deep.** No scroll-to-dig (explicitly out of scope, v2 candidate).
- Window resolution uses `CGWindowListCopyWindowInfo` (on-screen, current Space),
  filtered to layer 0 (normal windows), excluding Spyglass's own windows,
  excluding windows with alpha 0 or tiny frames (< 40×40 pt).
- Capture uses **ScreenCaptureKit** `SCContentFilter(desktopIndependentWindow:)`
  — occluded windows still stream full content (verified public API behavior).
  One `SCStream` at a time, for `target` only. Stream config: 30 fps,
  scale = display scale factor, cursor excluded.
- When the cursor moves such that `target` changes, tear down and restart the
  stream, **debounced at 80 ms**; during the swap show the lens's frosted
  empty state (see below) rather than stale pixels.

**Lens presentation**
- A borderless, click-through-by-default, non-activating overlay window
  (`NSPanel`, `.screenSaver` level, `ignoresMouseEvents = true` except during
  click handling, `collectionBehavior = [.canJoinAllSpaces, .transient]`).
- Circular mask with a soft feathered edge; the exact visual spec (diameter,
  rim, shadow, animation curves) is defined in `design.md` and is normative.
- Lens center follows the cursor at display refresh rate (the overlay moves
  every mouse-moved event; content updates at stream rate — motion smoothness
  comes from the overlay movement, not the stream fps).
- Default diameter **320 pt**; Settings slider range **220–460 pt**, step 20.
- The lens is clamped to stay fully on the screen the cursor is on (it slides
  against screen edges instead of being cut off).

**Empty / degraded states inside the lens** (single unified style, spec in design.md)
- No window beneath `front` at this point → empty state.
- Cursor over the desktop (no `front` window) → empty state.
- `target` is DRM/content-protected (stream delivers blank) → empty state
  (indistinguishable from blank content is acceptable for MVP; no detection work).
- Stream not yet delivering (first frame pending / debounce swap) → empty state.

**Click-to-raise**
- While peeking, a **left click** inside the lens raises and activates `target`
  (`AXUIElement` raise + `NSRunningApplication.activate`), and the peek session
  ends immediately (lens dismisses even if the key is still held; a new peek
  requires releasing and re-pressing the trigger).
- Clicks outside the lens behave normally (the overlay ignores them).
- Right-click / other buttons: no special behavior (pass through normally).

### 2.2 Menu bar presence

- Standard `MenuBarExtra` / `NSStatusItem` with a template icon (spec in design.md).
- Menu items: `About Spyglass`, `Settings… ⌘,`, `Quit Spyglass ⌘Q`. Nothing else.
- Icon states: normal; **warning state** (badge/alternate symbol) when any
  required permission is missing — clicking the icon then shows a menu with
  `Fix permissions…` (reopens onboarding) at the top.

### 2.3 Settings window

Small, fixed-size, non-resizable window (spec + layout in design.md / wireframes.md).
Exactly three controls:
1. **Trigger key** — segmented control or popup: Right ⌘ / ⌃⌥ / fn.
2. **Lens size** — slider 220–460 pt with live preview circle in the window.
3. **Launch at login** — toggle (`SMAppService.mainApp`).

Persistence: `UserDefaults` via a `SettingsStore` in Core (protocol-backed for tests).
Changes apply immediately; no Save button.

### 2.4 Onboarding (first launch & permission recovery)

Single dedicated window, shown when (a) first launch, or (b) any required
permission is missing at launch or at peek-attempt time.

Requires **two** permissions, presented as two steps on one screen:
1. **Screen Recording** (for ScreenCaptureKit capture) — `CGPreflightScreenCaptureAccess()`
   / `CGRequestScreenCaptureAccess()`; deep-link button to
   `x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture`.
2. **Accessibility** (for the trigger-key event tap and click-to-raise) —
   `AXIsProcessTrustedWithOptions`; deep-link to `?Privacy_Accessibility`.

Content order (visual spec in design.md): app icon + name, one-line promise,
a looping demo animation of the lens mechanic (coded SwiftUI, not live capture),
the two permission rows each with status (granted ✓ / grant button),
a **Launch at login** toggle (default ON), and a single primary button
(`Start peeking`) enabled only when both permissions are granted.

Permission-status detection (patterns verified against Ice/Loop source):
- **Screen Recording has no change notification and does not hot-apply**:
  poll `CGPreflightScreenCaptureAccess()` on a 1 s timer while the onboarding
  window is visible. A grant made during this process's lifetime **always
  requires an app relaunch** before capture works — when the poll flips to
  granted for the first time in-process, the CTA becomes `Relaunch Spyglass`
  (performs the relaunch); after relaunch the normal `Start peeking` CTA shows.
- **Accessibility has a real notification**: subscribe to
  `com.apple.accessibility.api` via `DistributedNotificationCenter` and
  re-check `AXIsProcessTrusted()` after a 250 ms settle delay (the
  notification can fire before the API reflects the new state). No polling.
- macOS 15+ re-prompts Screen Recording periodically (~monthly), so the
  permission screen must stay reachable forever via the menu bar warning
  state — it is not a first-run-only surface.

### 2.5 App lifecycle

- LSUIElement (no Dock icon, no main window).
- The app never shows any window except: onboarding, settings, about panel, and
  the lens overlay.

## 3. Cross-Cutting Concerns

### 3.1 Architecture (Core/UI split — coverage floor applies to Core)

`SpyglassCore` (no AppKit/SwiftUI imports; 80% line coverage enforced):
- `PeekStateMachine` — states: `idle → armed(holdTimer) → peeking(target) → ended`;
  inputs: keyDown/keyUp/otherKey/click/targetChanged/permissionLost. Pure logic.
- `WindowResolver` — given a cursor point and an array of `WindowInfo`
  (id, frame, layer, alpha, ownerPID, isSpyglass), returns `(front, target)?`.
  Pure function over injected snapshot data.
- `LensGeometry` — lens rect from cursor point + diameter + screen bounds
  (edge clamping), capture-crop mapping from screen coords to window-local coords.
- `SettingsStore` — trigger key, diameter, launch-at-login (protocol `Persisting`
  abstracts UserDefaults).
- `PermissionsModel` — combines two `Bool` sources into onboarding/menu state.
- `TriggerKeyClassifier` — maps CGEvent flag payloads (as plain structs) to
  trigger key identity, hold/cancel decisions.

`SpyglassUI` (SwiftUI/AppKit; thin):
- `LensOverlayController` (NSPanel + Metal/CALayer-backed content view),
  `CaptureEngine` (SCStream wrapper), `EventTapMonitor`, `MenuBar`,
  `SettingsView`, `OnboardingView`.

App target: `@main` wiring only.

### 3.2 Error handling

- Event tap disabled by system (`tapDisabledByTimeout`) → re-enable immediately; log.
- SCStream error/stop → tear down, lens shows empty state; retry on next target change.
- Permission revoked mid-session → end peek, switch menu icon to warning state,
  show onboarding on next trigger attempt.
- All failures must be silent-safe: the app must never crash or beachball the
  system during a peek; worst case is "lens shows empty state".

### 3.3 Performance budgets

- Idle (no peek): 0% CPU target (< 0.1%), no timers running; event tap only.
- Peeking: ≤ 15% CPU on Apple Silicon at 30 fps stream; overlay movement must
  track the cursor without visible lag (move on every mouse event).
- Memory: < 150 MB during peek (one stream), < 40 MB idle.

### 3.4 Accessibility & appearance

- Full dark/light mode support (design.md defines both).
- Settings/onboarding: standard keyboard navigation and VoiceOver labels.
- Reduced motion: replace lens fade/scale animations with opacity-only.

## 4. Out of Scope (MVP) — with rationale

| Deferred | Why |
|---|---|
| Scroll-to-dig deeper layers | Complexity vs. verified one-layer mental model; v2 candidate |
| Scroll-to-resize lens while holding | Conflicts with future dig gesture; settings slider suffices |
| Interacting *into* the hidden window through the lens | macOS cannot forward events into occluded windows sanely; click-to-raise covers the need |
| Multiple simultaneous lenses | Gimmick; complicates stream budget |
| Screenshot/copy of lens content | Scope creep; CleanShot territory |
| DRM-blank detection & special messaging | Indistinguishable cheaply; unified empty state suffices |
| Cross-Space window peeking | No public API to enumerate/capture other-Space windows reliably |
| Mac App Store distribution | Screen Recording + event tap = non-sandboxable in practice |
| Localization beyond English | OSS launch scope |
