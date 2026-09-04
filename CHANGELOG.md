# Changelog

Notable user-facing and repository changes are recorded here. RPGFit has not
yet published a tagged release.

## Unreleased

### App

- Rebuilt the original prototype as a four-tab SwiftUI experience for iPhone
  and iPad: Character, Train, Journey, and Progress.
- Added guided per-set sessions, routines, supersets, rest timing, custom
  exercises, equipment filtering, history editing, charts, records, plate
  math, and CSV export.
- Added placement, classes, attributes, quests, campaign and Trial encounters,
  chests, equipment loadouts, companions, bonds, streaks, and prestige.
- Added versioned local persistence, automatic recovery, manual private
  CloudKit backup, optional write-only HealthKit export, a home-screen widget,
  and a rest-timer Live Activity.
- Added a privacy manifest, in-app privacy policy, accessibility improvements,
  deterministic App Store screenshots, and extensive model-invariant tests.
- Normalized placement scoring across the expanded exercise catalog so every
  non-mobility session can establish a meaningful, monotonic starting level.

### Repository

- Replaced the stale upload-only prototype tree with the complete Xcode
  project and shared schemes.
- Added project, architecture, contribution, security, and release
  documentation.
- Added automated unit-test CI and structured issue and pull-request templates.

## Prototype — 2025-11-17

- Uploaded the initial single-file RPG-style fitness tracker prototype.
