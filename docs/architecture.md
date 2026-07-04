# Architecture

## Layers

```
┌─────────────────────────────┐
│ App/            (app shell) │  @main, WindowGroup — wiring only
├─────────────────────────────┤
│ SpyglassUI         (SwiftUI)   │  thin views, no business logic
├─────────────────────────────┤
│ SpyglassCore       (logic)     │  models + view models, no SwiftUI import,
│                             │  80% line-coverage floor
└─────────────────────────────┘
```

The dependency direction is strictly one-way: `SpyglassCore` ← `SpyglassUI` ← `App`.

## Where new code goes

| You are adding… | It goes in… | Tested by… |
|---|---|---|
| Domain logic, state, view models | `Packages/SpyglassKit/Sources/SpyglassCore` | Swift Testing in `Tests/SpyglassCoreTests` (coverage-gated) |
| Views, view modifiers | `Packages/SpyglassKit/Sources/SpyglassUI` | Core view-model tests + the launch UI test |
| App lifecycle, scenes, menus | `App/` | `LaunchUITests` + `just smoke` |

Keeping logic out of views is what makes the coverage floor honest: the gate
measures the code that can regress silently, not SwiftUI layout.

## Recommended optional dependencies

The template ships with zero. When a real need appears, these are vetted
starting points:

- [ViewInspector](https://github.com/nalexn/ViewInspector) — unit-test SwiftUI
  view hierarchies when view-model tests stop being enough.
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)
  — pixel/structure regression tests for complex custom views.
- [Sparkle](https://sparkle-project.org/) — in-app updates once you distribute
  outside the App Store and users ask for auto-update (see docs/distribution.md).

Before adding any dependency, apply the checklist in `.claude/rules/project.md`
(maintenance, license, transitive weight) and commit `Package.resolved` with it.
