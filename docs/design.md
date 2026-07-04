# Spyglass — Design Specification

This document is **normative**: every color, size, duration, and symbol name
below is an implementation requirement, not a suggestion. Where SwiftUI code
needs a value that is not listed here, use the nearest listed token — do not
invent new values.

## 0. Design Principles

1. **The lens IS the product.** All craft budget goes into the lens: its rim,
   its shadow, its appear/dismiss motion. Everything else is quiet, native macOS.
2. **Invisible until summoned.** No floating UI, no dock icon, no sounds.
   When the trigger key is not held, Spyglass must be visually nonexistent.
3. **Native, with one brass thread.** Windows use standard macOS components and
   materials; the single brand element — the warm brass accent — appears in the
   lens rim, the primary button, and the icon. Nowhere else.

## 1. Color Tokens

Define all of these in `Assets.xcassets` as color sets with Any/Dark variants
(names exactly as written, camelCase).

| Token | Light | Dark | Used for |
|---|---|---|---|
| `brassPrimary` | `#9A7328` | `#E3B341` | tinted icons, links, slider tint |
| `brassDeep` | `#8F6A20` | `#B98A2F` | gradient dark stop |
| `brassMid` | `#C9962E` | `#C9962E` | gradient mid stop |
| `brassBright` | `#F0C75E` | `#F5D98A` | rim highlight, click flash |
| `stageBackground` | `#211D17` | `#211D17` | onboarding demo stage (fixed dark in both modes) |
| `stageWindowFront` | `#2E2A24` | `#2E2A24` | demo mock front window |
| `stageWindowBack` | `#3A342B` | `#3A342B` | demo mock back window |

System semantics (do not redefine): granted = `systemGreen`,
warning = `systemOrange`, all text = `labelColor` / `secondaryLabelColor`,
window backgrounds = default `windowBackgroundColor` / Form grouped defaults.

Contrast note: `brassPrimary` on `windowBackgroundColor` meets ≥ 4.5:1 in both
modes; never place `brassBright` text on light backgrounds (decorative only).

## 2. Typography

System font (SF Pro) only. Fixed sizes (pt):

| Role | Spec |
|---|---|
| Onboarding title | 28, bold |
| Onboarding tagline | 15, regular, `secondaryLabelColor` |
| Section/row title | 13, semibold |
| Row subtitle / captions | 12, regular, `secondaryLabelColor` |
| Button label | 15, semibold |
| Lens caption pill | 13, medium |
| Slider value readout | 12, regular, monospaced digits, `secondaryLabelColor` |

## 3. Spacing & Radii

8-pt grid. Allowed spacing values: 4, 8, 12, 16, 20, 24, 32.
Corner radii: controls 10, cards/rows 10, demo stage 12, caption pill 12
(= half its 24 pt height).

## 4. The Lens (hero component — `LensView`)

One SwiftUI component used at full size by the overlay, at 1/4 scale by the
settings preview, and at mini scale inside the onboarding demo. Layers, back
to front (D = configured diameter, default 320):

1. **Content** — the live capture frame, positioned so the visible region
   corresponds 1:1 with screen coordinates (hole illusion), masked to a circle
   of diameter D − 4.
2. **Vignette** — radial gradient inside the content circle: clear from center
   to 78% radius, then black at 8% opacity at the edge. Sells "optical glass"
   without hiding content.
3. **Inner glass edge** — 1 pt stroke at diameter D − 4, white, masked by a
   linear gradient at 135° (white 40% → clear → white 15%) so it catches light
   at the top-left and only faintly at the bottom-right. (This masked-hairline
   technique is how Loop hand-rolls its glass inner highlight; a flat
   uniform-opacity ring reads as a fake border.)
4. **Rim** — 2 pt stroke at diameter D: linear gradient at 135°,
   stops: `brassBright` (0.0) → `brassMid` (0.55) → `brassDeep` (1.0).
5. **Specular highlight** — an arc from 190° to 240° (SwiftUI `trim` on a
   circle, 0° = right, counterclockwise ⇒ upper-left), 3 pt stroke, white at
   60%, blur radius 4. This is the "˚" glint in the wireframe. Light direction
   is top-left **everywhere in the app** (icon, demo, lens) — one light source.
6. **Outer shadow** — soft omnidirectional glow, matching how Loop/Ice shadow
   round floating chrome: black 20% (light mode) / 28% (dark mode),
   radius 12, offset (0, 0). No directional drop shadow.

**Caption pill** (State A only): 24 pt tall capsule, horizontal padding 10,
8 pt below the lens circle, centered; `.ultraThinMaterial` background;
content = target app icon at 14 pt + window title, 13 pt medium, middle
truncation, max total width 260 pt. The pill fades in 80 ms *after* the lens
appears (staggered, so the lens leads).

**Empty state** (State B): content layer replaced by an
`NSVisualEffectView(material: .hudWindow, blendingMode: .behindWindow,
state: .active)` fill — the material every admired floating overlay
(Loop's radial menu included) uses — with SF Symbol `circle.dashed` at 28 pt,
`secondaryLabelColor` at 40% opacity, centered. No caption pill. All other
layers (rim, highlight, shadow) unchanged.

### Lens motion

| Event | Animation |
|---|---|
| Appear | scale 0.86 → 1.00 + opacity 0 → 1, spring(response 0.28, dampingFraction 0.78), anchored at cursor |
| Follow cursor | none — set position directly on every mouse-moved event (zero-lag) |
| Dismiss (key up) | opacity → 0 + scale → 0.94, easeOut 120 ms |
| Target swap | content cross-fades through empty state, 100 ms each way |
| Click-to-raise | rim & highlight animate to `brassBright` + scale 1.00 → 1.06, spring(response 0.18, dampingFraction 0.7), then dismiss; total ≤ 250 ms |
| Reduce Motion | all scale changes removed; same durations, opacity only |

## 5. Menu Bar

- Icon: SF Symbol `camera.aperture`, template rendering, default size
  (16 pt). Never colored in normal state.
- Warning state: same symbol with `contentTintColor = .systemOrange`, and the
  `⚠ Fix Permissions…` menu item (symbol `exclamationmark.triangle.fill`,
  `systemOrange`) inserted at the top of the menu.
- Menu items and order: exactly as wireframed. No icons on normal items.

## 6. Settings Window (400 × 360, fixed)

- **Not** a stock `Form(.formStyle(.grouped))` — source review of Loop, Ice,
  and Thaw shows every admired utility composes its own grouped boxes, and the
  stock Form reads as templated. Use a single `VStack(spacing: 16)` of three
  purpose-built group boxes (background `.quinary` fill, corner radius 10,
  inner padding 12) with 13 pt semibold section captions above each:
  `Trigger`, `Lens`, `General` (contents per wireframe §2). Standard titlebar,
  title `Spyglass Settings`.
- Trigger picker: segmented, three options labeled `Right ⌘`, `⌃⌥`, `fn`.
- Lens size slider: range 220–460, step 20, tint `brassPrimary`; value
  readout (`320 pt`) below the preview, centered.
- Live preview: the real `LensView` at 1/4 scale (so 320 ⇒ 80 pt on screen),
  rendered in empty-state style but with `stageBackground` fill and a
  `brassPrimary` `chart.bar.fill` glyph at 20 pt as placeholder content.
  It re-renders continuously while the slider is dragged.
- Launch at login: standard `Toggle`, no custom styling.

## 7. Onboarding Window (440 × 640, fixed)

Layout, sizes, and states exactly as wireframe §1. Additional visual specs:

- Window: hidden title bar (`.fullSizeContentView` + transparent titlebar),
  close button only; background = `windowBackgroundColor`.
- App icon rendered at 96 pt with its built-in shadow (no extra shadow).
- Demo stage: 376 × 180, corner 12, fill `stageBackground` — a fixed dark
  "theater" in both light and dark mode. Content is **coded SwiftUI, not a
  video asset**:
  - Mock front window: 240 × 120 rounded 8, `stageWindowFront`, three 6 pt
    traffic-light dots (`#FF5F57`, `#FEBC2E`, `#28C840`) at top-left inset 10.
  - Mock back window: 200 × 100 rounded 8, `stageWindowBack`, offset (+70, +30)
    behind the front one, containing a `chart.bar.fill` glyph 28 pt in
    `brassPrimary`.
  - A mini `LensView` (diameter 64) travels a gentle S-path across the front
    window over 4 s (`easeInOut`, autoreverses, repeats forever). Where it
    overlaps the back window's frame it reveals the chart glyph (mask trick:
    the back window content is rendered above the front mock, masked to the
    lens circle). This *is* the product demo, built from the product's own
    component.
- Permission rows: 56 pt, corner 10, background
  `quaternarySystemFill`-equivalent (`Color(nsColor: .quaternaryLabelColor).opacity(0.08)`
  is NOT acceptable — use `.background(.quaternary.opacity(0.5))` or a grouped
  `Form` row); leading icon in a 32 × 32 rounded-8 container filled
  `brassPrimary` at 12% opacity, icon 16 pt `brassPrimary`:
  - Screen Recording: `record.circle`
  - Accessibility: `accessibility`
  - Granted state: `checkmark.circle.fill` 16 pt `systemGreen` + `Granted`
    13 pt `secondaryLabelColor` (replaces the button, cross-fade 200 ms).
- Primary CTA: 376 × 44, corner 10, fill = linear gradient 180°
  `brassMid` → `brassDeep` (light) / `brassBright` → `brassMid` (dark), label
  white 15 pt semibold (`Start peeking`). Hover: brightness +6%. Pressed:
  scale 0.98. Disabled: 35% opacity, no hover. Enable transition: opacity
  animate 200 ms (no bounce).
- Launch-at-login toggle row: 44 pt, standard `Toggle`, 13 pt label.

## 8. App Icon

Buildable as flat vector layers (no artwork skills needed):

1. macOS squircle, background radial gradient `#26211A` (center) → `#17140F` (edge).
2. Centered circle, 62% of icon width: rim = 6%-width ring stroked with the
   lens rim gradient (§4 layer 4), plus the specular arc (§4 layer 5) scaled up.
3. Inside the circle, a diagonal split at 135°: upper-left half `#3A342B`
   (the "front window"), lower-right half `#F5EFE3` with a 3-bar chart glyph
   in `brassMid` (the revealed content). The split edge gets a 2 pt soft shadow.
4. No text, no gloss, no border.

Export via the template's icon pipeline (single 1024 pt master).

## 9. Craft Guardrails (do / avoid)

Do:
- Keep the lens's follow-motion unanimated — lag kills the illusion.
- Stagger the caption pill after the lens (the lens always leads).
- Use `NSVisualEffectView` materials for the empty state (real vibrancy).
- Test every screen in light mode, dark mode, and Reduce Motion.
- Keep idle CPU at zero — no timers when not peeking (menu bar apps get
  named and shamed for idle drain).

Avoid:
- Any glow, pulse, or animation that runs continuously during a peek.
- Brass on brass (gradient fills behind brass icons/text).
- Custom-styled standard controls (toggles, pickers stay stock).
- Sounds of any kind.
- More than one accent hue anywhere in the app.
