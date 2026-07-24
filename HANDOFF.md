# Afterimage — Handoff (continue in a new chat)

_Last updated 2026-07-24 (overnight session). Paste this into a new chat to pick up where we left off._

> **Git state:** on branch `feat/full-app-rebuild`, last commit `26bfc51`
> ("Calibrate camera buttons on-device; press states, camera haptics, instant
> counter, portrait lock"). Working tree clean except this file.
> `main` has been fast-forwarded to match (see "Git layout" below).
> **⚠️ NO GIT REMOTE is configured** — everything lives only on this Mac.
> If a GitHub repo exists (or should), add it: `git remote add origin <url>`
> then `git push -u origin main feat/full-app-rebuild`.

## What this is
**Afterimage** — a "disposable camera for groups." Start a roll with friends, shoot blind
(no preview), wait for a timer, then the whole roll reveals at once in a slideshow.
SwiftUI iOS app on a **live Firebase** backend. Being pushed to **TestFlight** so friends
can install it.

## Key facts a new chat needs
- **Project root:** `~/Desktop/Afterimage/`
- **Xcode project:** `~/Desktop/Afterimage/afterimage/afterimage.xcodeproj` (scheme `afterimage`)
- **Source:** `~/Desktop/Afterimage/afterimage/afterimage/`
- **Firebase project id:** `afterimage-671e4` (console name "GroupCapsule"). Bundle id
  `com.ethanbayard.afterimage`. Storage bucket `afterimage-671e4.firebasestorage.app`.
- **Apple Developer Program:** ACTIVE (paid, Individual). **Team ID `TM7HX4FKWA`**.
- **iPhone (devicectl id):** `1B32AB5E-78B3-5127-90D9-DF7A73153D81` ·
  **xcodebuild destination UDID:** `00008140-0010396901A2801C` (iPhone 16 Pro, iOS 26.5.2)
- **Min iOS: 26.0** — ⚠️ friends on older iPhones CANNOT install. (The `.glassEffect`
  tab bar that gated this is GONE now — bar is plain icons — so lowering the min may
  be back on the table. Still an OPEN decision.)
- **App is PORTRAIT-ONLY** (landscape removed in both build configs).
- **App label on home screen is "groupRoll"** (PRODUCT_NAME), not "Afterimage". KEEP for now.
  Built product is `groupRoll.app`.
- Xcode uses `PBXFileSystemSynchronizedRootGroup` → new `.swift`/asset files are auto-included,
  no `project.pbxproj` edits needed.

## Git layout
- `feat/full-app-rebuild` — the working branch, all session commits land here.
- `main` — fast-forwarded to the same tip (user wants every new feature on main).
  After each feature commit: `git checkout main && git merge --ff-only feat/full-app-rebuild && git checkout feat/full-app-rebuild`
  (or just keep fast-forwarding main the same way).
- No remote. See warning at top.

## ✅ This session (2026-07-23 → 24) — ALL COMMITTED

Commits, oldest first:
1. `4b940a0` — glass tab bar (later removed again), film-strip dividers (6px black +
   6pt rounded corners), Profile opens rolls exactly like the Rolls feed (push
   developing / slideshow developed — no more modal sheet), status bar hidden on camera.
2. `5a85682` — **new glossy shell art (904×1740)** + **full video mode**:
   - `Shot.videoURL` (poster still stays in `photoURL` → thumbnails/heroes never autoplay)
   - `ShotService.uploadVideo` (.mov + poster to Storage)
   - `CameraController`: movie output, poster-frame extractor
   - tap = photo · hold 0.32s = video (red face + pulsing ring + live timer)
   - playback on tap only: `RollSlideshowView` autoplays current video frame then
     advances; `PhotoViewerView` shows poster + play button
   - **storage.rules now allow `video/*` < 200MB — DEPLOYED** ✅
   - mic usage string added to both build configs
3. `26bfc51` — on-device button calibration + UX polish (see bullet list in the
   commit message; highlights below).

### Camera page — how the controls work now
- **Flash**: sheet art ALWAYS visible (needed for on/off glyph swap), presses inward
  with a white ring (`ControlButtonStyle`).
- **Flip**: BAKED button at rest; the sheet art appears scaled to 0.90 while pressed
  (`PressRevealButtonStyle`). ⚠️ Never put a flexible shape (bare `Circle().fill`)
  inside a ButtonStyle body — it inflates the layout to the full proposed size and
  once made the whole screen the flip button's tap target.
- **Shutter**: tap = photo — `ShutterFace` (a disc SLICED FROM THE SHELL ART, so
  pixel-identical) presses in at 0.92; hold = video — `RecordFace` + ring + timer.
  Red is VIDEO-ONLY, never shows on a photo tap.
- **Counter badge**: green Menlo 28pt w/ glow, `.position(x: 86, y: flashCenter.y*s)`.
  Ticks INSTANTLY via `optimisticShotCount` (rolls back on failed upload; server
  listener count wins when it catches up).
- **Haptics**: rigid click + light "film advance" clack 90ms later on capture.
- **Mic attaches only while recording video** (`startRecording`/`detachAudio`) — a
  permanently-attached mic pins iOS's mic-in-use pill over the Dynamic Island.
- Camera page backdrop is `Color.black` (NOT `Palette.background` — the warm dark
  reads as a grey panel below the shell art). Same for the album full-screen camera.

### Shell map (CameraView.Shell) — 904×1740 px space, glossy art, full-bleed
- scale: `s = geo.size.width / 904` (NO overfill, NO nudge — art has no margins)
- screen cutout `(241, 368, 446×769)` — viewfinder overfills by 10px each side
- flash center `(649, 162)`, overlay d `136` (sized to swallow the baked button + its
  bottom drop-shadow skirt)
- flip center `(781, 146)`, pressed-art d `112`
- shutter center `(465, 1505)`, hit r `126`, RecordFace/ShutterFace d `224`/`252`
- `rollCapacity = 24`
- **DEBUG alignment jig**: set `CameraView.showAlignmentJig = true` → crosshair +
  reference rings (pitch 4 shell px) at the mapped coordinates, overlays hidden.
  This is how the buttons were calibrated; reuse it after any art swap.

### Tab bar (MainTabView)
Bare floating icons — NO pill, NO glass. Height is dynamic:
`barHeight = fullScreenHeight − width×(1740/904) − bottomSafeInset` so the bar's top
edge exactly meets the shell's bottom edge on every device. Icons 24pt.
Side effect: Rolls/Profile content ends higher above the icons (user hasn't objected).

### Asset slicing (button art)
6 buttons sliced from `~/Downloads/button-contact-sheet.png` (3×2 grid, discs are
grid-centered, disc radius 189px) via circle-fit + tight alpha mask + checker kill +
1.5px edge feather. ⚠️ The first slicing attempt used dark-pixel CENTROIDS — the
sheet's drop shadows pulled centers off and left opaque checker fringe that looked
like misalignment on device. If art changes, re-run the fit approach, and verify with
the alignment jig. `FlashOffRing`/`RecordFaceRing` imagesets exist but are UNUSED
(the ring is drawn in SwiftUI).

### Verification workflow that finally worked (no more guessing)
**QuickTime Player → File → New Movie Recording → source dropdown → Screen: iPhone**
gives a LIVE view of the phone screen on the Mac even while the app uses the camera.
(iPhone Mirroring does NOT work here — it refuses to connect while the phone camera
is in use.) Claude drove this via computer-use: screenshot → zoom on the buttons →
read deltas against the alignment jig → fix constants → rebuild. Reuse this loop for
any pixel-level UI work.

## ⏳ Open items (in rough priority order)
1. **User verification pass** on the latest build: tab bar height/icons on all 3 pages,
   flip press feel, shutter press-in, video record→upload→tap-to-play in slideshow +
   photo viewer, instant counter, no mic pill on camera page.
2. **Set up a git remote and push** — repo currently exists ONLY on this Mac.
3. **Deploy Firestore rules** (carryover): `cd ~/Desktop/Afterimage && firebase deploy --only firestore:rules`
4. **Deploy functions** (carryover: self-activity on the wire): `firebase deploy --only functions`
5. **Apple Music integration** for roll soundtracks (free/no-subscription path —
   MusicKit preview clips or user-library playback; design TBD).
6. **TestFlight**: archive 1.0, bump build number (camera/UI + video changed a lot).
7. **Decision: lower the iOS 26 minimum?** The glass tab bar that required 26 is gone;
   audit for other 26-only API before deciding.
8. Possible nudges: bar icon size (24), flash overlay (649,162,d136), flip (781,146,d112),
   record-face d224, hold-to-record threshold (0.32s), counter x (86).

## Build / verify commands

```sh
# Build for the physical iPhone:
xcodebuild -project ~/Desktop/Afterimage/afterimage/afterimage.xcodeproj -scheme afterimage \
  -configuration Debug -destination 'id=00008140-0010396901A2801C' \
  -derivedDataPath /tmp/afterimage-device-build -allowProvisioningUpdates build
# Install (retry once if it throws CoreDeviceError 4000):
xcrun devicectl device install app --device 1B32AB5E-78B3-5127-90D9-DF7A73153D81 \
  /tmp/afterimage-device-build/Build/Products/Debug-iphoneos/groupRoll.app
# Launch (phone must be UNLOCKED; install works regardless):
xcrun devicectl device process launch --device 1B32AB5E-78B3-5127-90D9-DF7A73153D81 \
  com.ethanbayard.afterimage

# Deploy backend (keep storage rules deployed!):
cd ~/Desktop/Afterimage && firebase deploy --only storage,firestore:rules,functions
```

## Gotchas already solved (still true)
- Deployed Storage rules must stay deployed (default deny-all broke uploads once).
  They now allow `image/*` (<12MB) AND `video/*` (<200MB) under album shot paths.
- **DEBUG builds sign out on EVERY new build** (`signOutIfFreshBuild()` keys off the
  executable's mod date). It was temporarily disabled during the alignment loop and
  is RESTORED — if you're iterating on-device UI and the login friction hurts,
  comment out the call in `AuthService.init` (and restore before committing).
- Firestore shot-create rules don't whitelist fields — `videoURL` passes with no
  rules change.
- "Glare not showing" on phone = iPhone Reduce Motion / Reduce Transparency (intended).
- dSYM upload warnings for Firebase/grpc libs are harmless.
- App icon needs the FULL explicit size set in `AppIcon.appiconset`.
- First `devicectl install` of a session may fail with `CoreDeviceError 4000` — retry.
- More history in `SESSION_LOG.md` and `MORNING_BRIEF.md`.
