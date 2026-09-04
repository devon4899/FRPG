# Contributing to RPGFit

Thanks for helping improve RPGFit. The project is a focused, native Apple-
platform app, so changes should preserve its private-first data model and keep
the workout log useful independently of the RPG layer.

## Before starting

For a bug, search existing issues and include a minimal reproduction. For a
larger feature or a change to progression math, persistence, privacy behavior,
or platform entitlements, open an issue before investing in an implementation.

Please never attach real workout exports, Health data, iCloud records, signing
profiles, or other personal information to an issue.

## Local setup

1. Install Xcode 26.3 or newer.
2. Clone the repository and open `RPGFitMVP.xcodeproj`.
3. Select the shared `RPGFitMVP` scheme.
4. Build against an iOS 18.5+ simulator.

No package bootstrap is required. Simulator builds work without an Apple
Developer account. Physical-device builds require your own signing team and
service identifiers; see the setup note in the main README.

## Development expectations

- Keep app behavior deterministic and testable. Do not hide state mutations in
  view bodies.
- Preserve exact workout facts and convert display units only at UI boundaries.
- Add backward-compatible decoding and a migration whenever persisted schema
  changes.
- Add or update tests for scoring, XP, currency, equipment, quest, restore, and
  history-edit behavior.
- Use semantic colors and the components in `Theme.swift`; verify light and
  dark appearance plus accessibility Dynamic Type sizes.
- Give interactive controls meaningful accessibility labels and do not rely on
  color alone to communicate state.
- New network calls, analytics, SDKs, read access to Health data, or automatic
  cloud sync require explicit product and privacy review.

## Verification

Run the unit suite before opening a pull request:

```bash
xcodebuild test \
  -project RPGFitMVP.xcodeproj \
  -scheme RPGFitMVP \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.6' \
  -only-testing:RPGFitMVPTests \
  CODE_SIGNING_ALLOWED=NO
```

For UI work, also build the app, launch it from a clean simulator, and exercise
the changed flow on both an iPhone and iPad layout. The App Store screenshot
harness is intentionally not part of routine CI because it writes image
artifacts and requires a freshly erased simulator.

## Pull requests

Keep each pull request cohesive and describe:

- The user-facing problem and outcome.
- Any persisted-data, reward-accounting, privacy, or entitlement impact.
- Tests run and devices or simulator configurations checked.
- Before/after images for visible UI changes.

Do not commit build products, result bundles, user-specific Xcode state, signing
profiles, or generated QA screenshots outside the curated folders under
`docs/screenshots`.

This repository does not currently provide an open-source license. A submitted
contribution should not include code or assets that you do not have permission
to contribute.
