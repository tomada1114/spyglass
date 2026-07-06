# Spyglass

[![CI](https://github.com/tomada1114/spyglass/actions/workflows/ci.yml/badge.svg)](https://github.com/tomada1114/spyglass/actions/workflows/ci.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/tomada1114/spyglass/badge)](https://scorecard.dev/viewer/?uri=github.com/tomada1114/spyglass)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Hold a key, see through your front window; release, and it never happened.

Spyglass is a free, open-source macOS menu bar utility. While you hold the
trigger key, a circular lens follows your cursor and shows the **live**
content of the window hidden directly beneath the frontmost one — as if a
hole were cut through it. No minimizing, no Mission Control, no destroyed
window arrangement.

- **Hold right ⌘** (or ⌃⌥ / fn, configurable) — the lens appears after a
  150 ms hold and follows your cursor
- **Live, not a screenshot** — occluded windows stream their real content at
  30 fps via ScreenCaptureKit
- **Click through the lens** to raise and activate the revealed window
- **Exactly one layer deep** — a deliberate, predictable mental model
- **Invisible until summoned** — no Dock icon, no windows, zero idle CPU
- macOS 14+, Apple Silicon + Intel, MIT-licensed

## Permissions

Spyglass needs two system permissions, requested once during onboarding:

- **Screen Recording** — required by ScreenCaptureKit to show window
  content. macOS applies a grant only after an app relaunch; onboarding
  offers the relaunch button when needed.
- **Accessibility** — required to observe the global trigger key and to
  raise the revealed window on click.

Spyglass never records, stores, or transmits anything; frames go straight
from ScreenCaptureKit to the lens on screen.

## Building from Source

Prerequisites: Xcode 26.5+, [mise](https://mise.jdx.dev/), and
[Just](https://just.systems) (`brew install mise just`).

```bash
git clone https://github.com/tomada1114/spyglass.git
cd spyglass
mise trust     # approve mise.toml once — mise refuses untrusted configs
just install   # pinned tools via mise + git hooks + xcodegen generate
just check     # format → lint → test (80% floor) → build
just run       # build and launch the app
```

## Design Philosophy

Spyglass is built from
[macos-app-template](https://github.com/tomada1114/macos-app-template);
every infrastructure choice below has a reason. If you disagree with a
decision, you know exactly what to change and why it was there.

### Why XcodeGen with a gitignored `.xcodeproj`?

`project.yml` is declarative, diffable, and safely editable by both humans and
AI agents; a raw `pbxproj` is a UUID graph that merge conflicts and agents can
silently corrupt. The generated project is treated like a lockfile-derived
artifact: regenerate, never hand-edit. Trade-off: XcodeGen is a third-party
tool with its own bus factor — but the manifest is simple enough to migrate
away from if that ever matters.

### Why a thin app shell + local Swift package?

`App/` contains only the `@main` entry point and resources. Everything real
lives in `Packages/SpyglassKit`, so tests run with plain `swift test` — no
simulator, no signing, no Xcode project required. Precedent: pointfreeco's
isowords.

### Why the Core/UI split and a coverage floor on Core only?

`SpyglassCore` holds all logic and never imports SwiftUI; `SpyglassUI` holds thin
views. The 80% line-coverage floor applies to Core only — that is what makes a
strict numeric gate *honest* for a GUI app instead of an invitation to write
meaningless view tests. Note: Swift's llvm-cov has no dependable branch
metric, so the gate uses line coverage (a deliberate divergence from this
template's Python sibling, which gates on branch coverage).

### Why Swift Testing?

`@Test`, `#expect`, and parameterized `@Test(arguments:)` are the modern
default shipped with the toolchain. XCTest appears exactly once — in the
XCUITest launch target, because Apple has not ported UI automation to Swift
Testing.

### Why zero dependencies?

An app template should not impose opinions about networking, persistence, or
update frameworks. You add what you need; docs/architecture.md lists vetted
suggestions (ViewInspector, swift-snapshot-testing, Sparkle) and when they
earn their place.

### Why Just?

One command — `just check` — runs the same gate locally that CI runs. Just has
cleaner syntax than Make and is a task runner, not a build system, which is
exactly what an Xcode project needs. Every recipe also works without Just (see
CONTRIBUTING.md).

### Why CLAUDE.md and .claude/rules/?

AI-assisted development is the norm, not the exception. `CLAUDE.md` and
path-scoped rules give LLMs the project's standards, architecture, and hard
prohibitions (never lower the coverage floor, never disable safety lint
rules) — reducing review cycles.

### Why secret-gated notarization?

The release workflow always produces a DMG; when Developer ID secrets are
configured it signs, notarizes, and staples, otherwise it ad-hoc signs and
says so loudly. The template works on day one without an Apple Developer
Program membership, and upgrades to fully trusted distribution by adding
secrets — no workflow edits. See docs/distribution.md.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for full setup instructions.

```bash
just install
just check
```

The first local `just uitest` run may prompt for Accessibility permission
(System Settings → Privacy & Security); CI runners are pre-provisioned and
run it on every push.

## Documentation

- [Getting Started](docs/getting-started.md)
- [Architecture](docs/architecture.md)
- [Distribution & Signing](docs/distribution.md)
- [Adding iOS Later](docs/adding-ios.md)

## License

[MIT](LICENSE)
