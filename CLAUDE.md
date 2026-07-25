# Afterimage — working notes for Claude

A "disposable camera for groups": start a roll with friends, shoot blind, and the whole roll
reveals at sunrise. SwiftUI + Firebase + AVFoundation, iOS 26.0 minimum, portrait only.

## Use the agent team — every development task

Implementation, builds, and reviews go through the agents in `.claude/agents/`:
`swiftui-perf-engineer` (Screens/Components/Theme), `camera-engineer` (AVFoundation),
`firebase-engineer` (Services/rules/functions), `build-and-device-runner` (builds, deploys,
screenshots), `design-guardian` (DESIGN.md review), `swift-code-reviewer` (concurrency + perf review).

Cycle: domain engineer implements → runner builds Release and deploys → guardian and reviewer
review in parallel → fixes → re-verify → commit.

## Docs

- **DESIGN.md** — binding visual/motion/copy rules. Read before any UI change.
- **HANDOFF.md** — project state, decisions, gotchas, build commands.
- **PERF_DIAGNOSIS.md** — 2026-07-25 performance audit (heat + scroll choppiness) and fix priorities.
- **SESSION_LOG.md**, **DEV_SETUP.md** — history and the daily hot-reload loop.

## Build and deploy

Project `Afterimage/afterimage.xcodeproj` (one level deeper than expected — use absolute
paths), scheme `afterimage`, built product **`groupRoll.app`**, bundle `com.ethanbayard.afterimage`.
iPhone: xcodebuild UDID `00008140-0010396901A2801C`, devicectl id `1B32AB5E-78B3-5127-90D9-DF7A73153D81`.
Commands are in HANDOFF.md.

- Xcode uses synced root groups — **never edit `project.pbxproj`** to add files.
- **Judge performance on Release builds only**; Debug SwiftUI is misleadingly slow.
- Debug builds sign out on every fresh install (`signOutIfFreshBuild`) — expected, not a bug.
- The Simulator has no camera and can't sign in: authed screens and camera work verify on device.

## Things that break if you forget them

- **The Rolls feed in `HomeView` must stay an eager `VStack`.** Its cards need a concrete
  proposed height; a lazy container collapses them into stretched frames and black gaps
  (tried July 2026, broke the page). Any roll-card layout change requires visual verification
  of the Rolls page specifically — Profile rendering fine proves nothing.
- **The camera shutter ritual is sacred**: heavy haptic → 90ms flash → ~320ms blackout → toast.
  Never retime it.
- **Ambient "living film" motion is gated, not removed.** Every `TimelineView` takes a
  `paused:` derived from page/card visibility, scene phase, and Reduce Motion. Deleting the
  motion loses the product's character; leaving it ungated cooks the phone.
- **Listener-bearing services are environment singletons** created in `ContentView` — the paged
  `TabView` keeps every page mounted, so per-view `@State` services duplicate Firestore listeners.
- Only the canonical `Theme/Motion.swift` curves; palette tokens only; no pure black or white.
