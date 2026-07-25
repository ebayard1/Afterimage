# Afterimage — Handoff (continue in a new chat)

_Last updated 2026-07-24 (afternoon session). Paste this into a new chat to pick up where we left off._

> **Git state:** on branch `feat/full-app-rebuild`, last feature commit `bfef0a9`
> ("Frame-based button system: press-state art, inpainted shell, REC lamp,
> haptics"). `main` is fast-forwarded to the same tip.
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
- **Xcode project:** `~/Desktop/Afterimage/Afterimage/afterimage.xcodeproj` (scheme `afterimage`)
  — NOTE: the inner project folder was renamed `afterimage` → `Afterimage` on disk
  (2026-07-24) to match git's tracked capitalization; use capital-A paths in git commands.
- **Source:** `~/Desktop/Afterimage/Afterimage/afterimage/`
- **Firebase project id:** `afterimage-671e4` (console name "GroupCapsule"). Bundle id
  `com.ethanbayard.afterimage`. Storage bucket `afterimage-671e4.firebasestorage.app`.
- **Apple Developer Program:** ACTIVE (paid, Individual). **Team ID `TM7HX4FKWA`**.
- **iPhone (devicectl id):** `1B32AB5E-78B3-5127-90D9-DF7A73153D81` ·
  **xcodebuild destination UDID:** `00008140-0010396901A2801C` (iPhone 16 Pro, iOS 26.5.2)
- **Min iOS: 26.0** — ⚠️ friends on older iPhones CANNOT install. (The `.glassEffect`
  tab bar that gated this is GONE — audit for other 26-only API before lowering. OPEN.)
- **App is PORTRAIT-ONLY** (landscape removed in both build configs).
- **App label on home screen is "groupRoll"** (PRODUCT_NAME), not "Afterimage". KEEP for now.
  Built product is `groupRoll.app`.
- Xcode uses `PBXFileSystemSynchronizedRootGroup` → new `.swift`/asset files are auto-included,
  no `project.pbxproj` edits needed.

## Git layout
- `feat/full-app-rebuild` — the working branch, all session commits land here.
- `main` — fast-forwarded to the same tip after each feature commit:
  `git checkout main && git merge --ff-only feat/full-app-rebuild && git checkout feat/full-app-rebuild`
- No remote. See warning at top.
- Untracked junk in the worktree: macOS " 2" duplicate files (`SESSION_LOG 2.md`,
  `firebase 2.json`, `firestore 2.rules`, `functions/* 2.*`) — deliberately NOT
  committed; safe to delete or gitignore.

## ✅ This session (2026-07-24 afternoon) — COMMITTED `bfef0a9`

**Full camera reskin: new shell art + frame-based animated button system.**

- **New shell art** (`CameraShell`, still 904×1740 full-bleed): glossy body with
  speaker grille (bottom-left), thumbwheel with +/− (right edge, both DECORATIVE
  for now), red REC lamp dome, baked "hold to video" caption under the shutter.
  Source files (in `~/Downloads/`): `camera-ui-original-based-red-light-{on,off}-fixed-text.png`
  + `button-contact-sheet-last-column-reversed-preview.png` (1536×2048, 3×4 grid).
- **Green placeholder discs** in the source art mark button positions. They are
  **INPAINTED OUT** of the shipped CameraShell asset (nearest-neighbor fill) so
  green can never peek through. Measured centers (shell px): FLASH (650,154),
  FLIP (786,154), SHUTTER (452,1506); green discs d=129/129/269.
- **10 sliced button frames** (all in `Assets.xcassets` AND `art-sliced/`;
  regenerate with `tools/slice-camera-buttons.py`):
  - `FlipRest`/`FlipPressed` — 2-frame press.
  - `FlashOnRest`/`FlashOnPressed`/`FlashOffPressed`/`FlashOffRest` — a tap runs
    the 4-frame cycle (old rest → old pressed → new pressed [90ms via
    `flashSettleFrame`] → new rest); reverse order when toggling back.
  - `ShutterRest`/`ShutterPressed`/`RecordPressed`/`RecordRest` — tap photo =
    black frames only (red NEVER on a photo); hold 0.32s = RecordPressed one
    beat (120ms, `recordFaceSettled`) → RecordRest steady while recording.
  - ⚠️ Slices are ZERO-margin — the disc exactly fills the PNG canvas — so the
    rendered disc = the SwiftUI frame size. (Round 1 had a 4px margin that
    `scaledToFit` traded for ~2% shrink → green rings on device. Don't repeat.)
  - All frames in a column share the SAME outer diameter (the "pressed" look is
    baked inside the disc), so frames swap 1:1.
- **`FrameSwapButtonStyle`** (in CameraView.swift): instant art swap on
  `isPressed` (mechanical, deliberately no crossfade), opaque black backing
  disc (hit target + peek-through insurance), haptics: rigid 0.8 on press-down,
  light 0.5 on release. Shutter press-down also fires rigid 0.8 in its gesture.
  **ALL white ring / glow press indicators are DELETED** (per Ethan).
- **REC lamp** (`RecLampOn`, rect x683 y1149 221×233 in shell space): the lit
  dome + glow sliced from the light-ON shell via ON/OFF pixel diff, edges
  feathered 16px (round 1's hard crop showed a square seam). Winks 0.35s on
  photo capture (`lampWink`); blinks 1s on / 1s off while recording
  (TimelineView keyed to `recordStart`).
- **REC readout** moved INSIDE the viewfinder glass: top-left, camcorder-style
  "● REC 0:14", dot blinks 1/s.
- Shell map constants (CameraView.Shell): screen (241,368,446×768) — art
  otherwise framed exactly like before (`s = width/904`, full-bleed, no nudge).
  flashDiameter/flipDiameter 134, shutterDiameter 276, shutterRadius 138 (hit).
- Alignment jig still exists (`CameraView.showAlignmentJig`) and now hides the
  overlay buttons when on.

### ⚠️ OPEN BUG — flip button "turns fully green when pressed" (round-1 build)
Reported on the round-1 build. `FlipPressed` is a valid PNG, zero green pixels,
present in the compiled Assets.car (`assetutil` verified) — root cause NOT
found. Round 2's inpainted shell + black backing discs make the symptom
impossible (worst case = dark disc), but **if the pressed flip frame doesn't
show at all** on the current build, the image genuinely isn't resolving —
next step: `devicectl` console logs while pressing, look for "No image named".
**User had NOT yet verified the round-2 build when this handoff was written.**

### Wireless dev loop (no cable needed!)
- Build + install + launch works over Wi-Fi/**personal hotspot** (device shows
  "available (paired)" in `xcrun devicectl list devices`).
- **Verification = user sends iPhone screenshots** — measure them against the
  shell map / alignment jig in Python, fix constants, rebuild. QuickTime
  Screen:iPhone live view (previous loop) requires USB — hotspot can't do it.
- Reminder: DEBUG builds sign out on every fresh install (`signOutIfFreshBuild`).

## ⏳ Open items (in rough priority order)
1. **User verification pass on the round-2 build**: green fully gone, lamp seam
   gone, flip pressed frame (see OPEN BUG above), haptic feel, flash 4-frame
   cycle timing (90ms beat), REC readout placement, lamp blink rhythm (1s/1s —
   user said "every 2 seconds", interpretation unconfirmed).
2. **Set up a git remote and push** — repo exists ONLY on this Mac.
3. **Deploy Firestore rules** (carryover): `cd ~/Desktop/Afterimage && firebase deploy --only firestore:rules`
4. **Deploy functions** (carryover: self-activity on the wire): `firebase deploy --only functions`
5. **Apple Music integration** for roll soundtracks (free/no-subscription path).
6. **TestFlight**: archive 1.0, bump build number (big UI changes since last).
7. **Decision: lower the iOS 26 minimum?** Audit for 26-only API first.
8. Possible nudges: button diameters (134/134/276), flash settle beat (90ms),
   record settle beat (120ms), lamp wink (350ms), hold-to-record threshold
   (0.32s), REC readout padding (16/14), wheel/grille functionality (zoom?).

## Build / verify commands

```sh
# Build for the physical iPhone (works over hotspot):
xcodebuild -project ~/Desktop/Afterimage/Afterimage/afterimage.xcodeproj -scheme afterimage \
  -configuration Debug -destination 'id=00008140-0010396901A2801C' \
  -derivedDataPath /tmp/afterimage-device-build -allowProvisioningUpdates build
# Install (retry once if it throws CoreDeviceError 4000):
xcrun devicectl device install app --device 1B32AB5E-78B3-5127-90D9-DF7A73153D81 \
  /tmp/afterimage-device-build/Build/Products/Debug-iphoneos/groupRoll.app
# Launch (phone must be UNLOCKED; install works regardless):
xcrun devicectl device process launch --device 1B32AB5E-78B3-5127-90D9-DF7A73153D81 \
  com.ethanbayard.afterimage

# Re-slice buttons / re-inpaint shell after any art change:
python3 tools/slice-camera-buttons.py   # reads ~/Downloads sources, writes art-sliced/ + Assets.xcassets

# Deploy backend (keep storage rules deployed!):
cd ~/Desktop/Afterimage && firebase deploy --only storage,firestore:rules,functions
```

## Gotchas already solved (still true)
- Deployed Storage rules must stay deployed (default deny-all broke uploads once).
  They allow `image/*` (<12MB) AND `video/*` (<200MB) under album shot paths.
- **DEBUG builds sign out on EVERY new build** (`signOutIfFreshBuild()` keys off the
  executable's mod date). Comment out in `AuthService.init` if iterating hurts
  (restore before committing).
- Firestore shot-create rules don't whitelist fields — `videoURL` passes with no
  rules change.
- Button slicing: fit circles from the dark disc's TOP edge + max width — NEVER
  centroids (drop shadows pull centers off; bit us twice now).
- Git dir case: repo tracks `Afterimage/` (capital); disk now matches. If git
  add skips untracked files under it, check path capitalization first.
- "Glare not showing" on phone = iPhone Reduce Motion / Reduce Transparency (intended).
- dSYM upload warnings for Firebase/grpc libs are harmless.
- App icon needs the FULL explicit size set in `AppIcon.appiconset`.
- First `devicectl install` of a session may fail with `CoreDeviceError 4000` — retry.
- More history in `SESSION_LOG.md` and `MORNING_BRIEF.md`.
