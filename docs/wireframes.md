# Spyglass — Wireframes & UX Flows

Companion to `requirements.md` (what to build) and `design.md` (exact visual
values). Where a size/color appears in both this file and `design.md`,
`design.md` is normative.

## 1. Onboarding Window

Fixed 440 × 640 pt, non-resizable, non-miniaturizable, hidden title bar
(`.fullSizeContentView`, transparent titlebar), centered on the main screen.
Shown on first launch and whenever a required permission is missing.

```
+------------------------------------------+
|  (o)                                  x  |   <- standard close button only
|                                          |
|               [App Icon]                 |   96×96 pt
|                                          |
|               Spyglass                   |   Title, 28 pt bold
|    See through your front window.        |   Tagline, 15 pt secondary
|                                          |
|  +------------------------------------+  |
|  |                                    |  |
|  |        DEMO ANIMATION AREA         |  |   376×180 pt, rounded 12 pt
|  |   (looping lens demo, bundled      |  |   bundled asset, autoplays,
|  |    asset — NOT live capture)       |  |   no controls
|  |                                    |  |
|  +------------------------------------+  |
|                                          |
|  +------------------------------------+  |
|  | [rec.icon] Screen Recording        |  |   permission row 1, 56 pt
|  |   Required to show window content  |  |
|  |                        [ Grant ]   |  |   -> button becomes ✓ when granted
|  +------------------------------------+  |
|  | [key.icon] Accessibility           |  |   permission row 2, 56 pt
|  |   Required for the trigger key     |  |
|  |                        [ Grant ]   |  |
|  +------------------------------------+  |
|                                          |
|  [x] Launch Spyglass at login            |   toggle, default ON
|                                          |
|  +------------------------------------+  |
|  |          Start peeking             |  |   primary CTA, 376×44 pt
|  +------------------------------------+  |   disabled until both ✓
|                                          |
+------------------------------------------+
```

Permission row states (each row independently):

```
NOT GRANTED:  [icon]  Title / subtitle              [ Grant ]      <- bordered button
GRANTED:      [icon]  Title / subtitle              [✓ Granted]    <- green check + label, no button
```

Relaunch variant: granting Screen Recording during this process's lifetime
**always** requires an app relaunch before capture works (TCC does not
hot-apply it). When the grant is first detected in-process, the CTA area
swaps to:

```
|  +------------------------------------+  |
|  |         Relaunch Spyglass          |  |   same size/style as CTA
|  +------------------------------------+  |
|   Screen Recording needs a quick         |
|   relaunch to take effect.  (13pt, sec.) |
```

Behavior notes:
- `Grant` (Screen Recording) → call `CGRequestScreenCaptureAccess()`, and also
  offer the deep link if the system dialog does not appear (button subtitle
  becomes `Open System Settings…` after first click).
- `Grant` (Accessibility) → `AXIsProcessTrustedWithOptions` with prompt option,
  same deep-link fallback.
- Screen Recording status: poll every 1 s while this window is visible (no OS
  change notification exists). Accessibility status: subscribe to the
  `com.apple.accessibility.api` distributed notification, re-check after
  250 ms. Rows flip to ✓ automatically. No manual refresh button.
- `Start peeking` closes the window and (if toggle on) registers login item.
- Closing the window with both permissions granted = same as CTA.
- Closing without permissions: app stays running; menu bar icon shows warning state.

## 2. Settings Window

Fixed 400 × 360 pt, non-resizable, standard titlebar, title "Spyglass Settings".
SwiftUI `Form` with `.formStyle(.grouped)`.

```
+--------------------------------------------+
|  ● ● ●        Spyglass Settings            |
+--------------------------------------------+
|                                            |
|  Trigger                                   |
|  +--------------------------------------+  |
|  | Hold to peek   [Right ⌘ | ⌃⌥ | fn]   |  |  <- segmented picker,
|  +--------------------------------------+  |     default Right ⌘
|                                            |
|  Lens                                      |
|  +--------------------------------------+  |
|  |  Size      220 ----o------ 460       |  |  <- slider, step 20,
|  |                                      |  |     default 320
|  |            +------------+            |  |
|  |           /              \           |  |  <- live preview: a real
|  |          |   (preview)    |          |  |     lens-styled circle,
|  |           \              /           |  |     rendered at 1/4 scale,
|  |            +------------+            |  |     updates while dragging
|  |               320 pt                 |  |  <- current value, 12pt sec.
|  +--------------------------------------+  |
|                                            |
|  General                                   |
|  +--------------------------------------+  |
|  | Launch at login              [ on ]  |  |
|  +--------------------------------------+  |
|                                            |
+--------------------------------------------+
```

- No Save/Cancel; every change applies immediately and persists.
- The preview circle uses the exact same rendering component as the real lens
  (rim, highlight, shadow) with placeholder content (`design.md` §Lens), so the
  settings window doubles as a living spec of the hero visual.

## 3. Menu Bar

Normal state (all permissions granted):

```
[aperture icon]            <- template image, SF Symbol "camera.aperture"
   |
   +----------------------------+
   | About Spyglass             |
   | Settings…              ⌘, |
   |----------------------------|
   | Quit Spyglass          ⌘Q |
   +----------------------------+
```

Warning state (any permission missing): icon tinted systemOrange, menu gains
one item at the top:

```
[aperture icon, orange]
   |
   +----------------------------+
   | ⚠ Fix Permissions…         |   <- opens onboarding window
   |----------------------------|
   | About Spyglass             |
   | Settings…              ⌘, |
   |----------------------------|
   | Quit Spyglass          ⌘Q |
   +----------------------------+
```

## 4. Lens Overlay States

State A — normal peek (content streaming):

```
        ░░░░░░░░░░░░░░░░░░░░░░░░░   <- front window (untouched, real)
     ░░░░  ╭───────────╮  ░░░░░░
    ░░░   ╭╯ ˚          ╰╮  ░░░░    ˚  = rim highlight (upper-left)
    ░░░   │   target's   │  ░░░░    rim = 2pt brass gradient stroke
    ░░░   │ live content │  ░░░░    outside: soft shadow
    ░░░   ╰╮            ╭╯  ░░░░    content = live SCStream frame,
     ░░░░  ╰───────────╯  ░░░░░░    screen-aligned (hole illusion)
        ░░░░░░░░░░░░░░░░░░░░░░░░░
```

- Content inside the circle shows the exact region of `target` that lies under
  the lens circle in *screen coordinates* (not a thumbnail, not centered).
- A 1-line caption pill hangs 8 pt below the lens: `[app icon 14pt] Window Title`
  (13 pt medium), truncated middle at 260 pt max. Identifies what you're seeing.

State B — empty (no window beneath / blank stream / stream swapping):

```
      ╭───────────╮
     ╭╯            ╰╮
     │   ◌  (frosted │      <- ultraThinMaterial fill,
     │   material,   │         SF Symbol "circle.dashed" 28pt
     │   dim symbol) │         at 40% secondary, centered
     ╰╮            ╭╯
      ╰───────────╯
      (no caption pill)
```

State C — click-to-raise feedback (≤ 250 ms, then everything dismisses):

```
   click inside lens
        │
        ▼
   rim flashes brighter + lens scales 1.0 → 1.06 → dismiss
   target window raises & activates simultaneously
```

## 5. User Flows

### 5.1 First launch

```
[Launch] -> both permissions already granted? 
   |-- yes -> [menu bar icon appears, nothing else]      (returning users)
   |-- no  -> [Onboarding window]
                |
                | user grants Screen Recording -> row ✓ (poll)
                | user grants Accessibility    -> row ✓ (poll)
                |
                |-- SR granted this session   -> [Relaunch Spyglass] (always)
                |                                   -> app relaunches -> both ✓
                |-- both ✓ after relaunch     -> [Start peeking] enabled
                v
        [Start peeking] -> window closes -> (toggle on? register login item)
```

### 5.2 Peek interaction (state machine — mirrors `PeekStateMachine` in Core)

```
IDLE
  └─ trigger key down ──────────────► ARMED (150 ms hold timer)
       ARMED: any other key / trigger up before 150 ms ──► IDLE (no lens ever shown)
       ARMED: timer fires ───────────► PEEKING
PEEKING (lens visible, follows cursor)
  ├─ cursor moves, same target ─────► update lens position only
  ├─ resolved target changes ───────► empty state, debounce 80 ms, new stream
  ├─ no target at point ────────────► empty state
  ├─ any non-trigger key down ──────► ENDED (cancel: user is typing a shortcut)
  ├─ left click inside lens ────────► ENDED (raise target + flash, ≤250 ms)
  └─ trigger key up ────────────────► ENDED (fade out ≤120 ms)
ENDED ──► IDLE (a new peek always requires a fresh key press)
```

### 5.3 Permission lost mid-session

```
[PEEKING] -> stream/tap fails with permission error
    -> lens dismisses -> menu icon = warning state
    -> next trigger press: no lens; onboarding window opens instead
```

## 6. Cross-Cutting Specifications

### 6.1 Error handling

| Failure | User-visible behavior | Recovery |
|---|---|---|
| SCStream start/frame failure | Lens shows empty state (State B) | Auto-retry on next target change |
| Event tap disabled by timeout | Nothing visible | Re-enable programmatically, log |
| Permission revoked | Lens dismisses; menu icon warning; onboarding on next use | User re-grants |
| Login item registration fails | Toggle reverts + inline 12 pt secondary text "Couldn't register — check System Settings › Login Items" | User acts |

No alert dialogs anywhere in the app. No sounds. The app must never present
a modal in the middle of a peek.

### 6.2 Accessibility

- All interactive controls: `accessibilityLabel`; onboarding rows announce
  status changes ("Screen Recording: granted").
- Settings/onboarding fully keyboard-navigable (Tab order top→bottom).
- Contrast: all text ≥ 4.5:1 in both appearances (values in `design.md`).
- Reduce Motion on: lens appear/dismiss uses opacity-only fades (same
  durations); click feedback drops the scale pulse, keeps the rim flash.
- Reduce Transparency on: empty-state material falls back to solid
  `windowBackgroundColor`.
- The lens itself is decorative/visual; it is `accessibilityHidden` (VoiceOver
  users interact with real windows directly).

### 6.3 Loading & feedback

- Only loading state in the app: lens empty state (State B). No spinners.
- Success feedback: none needed (results are directly visible).
- The onboarding CTA enabling (disabled → enabled) is animated (design.md).

### 6.4 Form validation

Not applicable — the app has no free-form input. All settings are
constrained controls (picker, stepped slider, toggle) that cannot hold
invalid values. `SettingsStore` still clamps persisted values on read
(diameter → nearest of 220…460; unknown trigger key → Right ⌘) so a
hand-edited defaults plist can never crash the app.
