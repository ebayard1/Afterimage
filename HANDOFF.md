# Afterimage — Handoff (continue in a new chat)

_Last updated 2026-07-22 (evening session). Paste this into a new chat to pick up where we left off._

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
- **Min iOS: 26.0** — ⚠️ friends on older iPhones CANNOT install, even via TestFlight.
  Lowering it is still an OPEN decision.
- **App label on home screen is "groupRoll"** (PRODUCT_NAME), not "Afterimage". User chose to
  KEEP this for now (do not rename unless asked). Built product is `groupRoll.app`.
- Xcode uses `PBXFileSystemSynchronizedRootGroup` → new `.swift`/asset files are auto-included,
  no `project.pbxproj` edits needed.
- Claude auto-memory has a `device-deploy.md` note with the exact build+install commands.

## ✅ Done 2026-07-21/22 session (all compiles clean, installed on the iPhone; NOT committed)

**Film-strip edge print (`Components/RollPostElements.swift`):**
1. **Candle flicker** replaced the old sliding shimmer (which washed white and hard-reset).
   `CandleFlicker` modifier: layered incommensurate sines, ember-orange → warm amber only.
   **Scroll-driven**: ticks only while `\.isFeedScrolling` is true (same env key the glare
   uses), freezes mid-flicker when the feed rests.
2. **Layout flipped**: edge numbers are now OUTERMOST (top/bottom rims), sprocket holes sit
   inside between numbers and photos. Re-punch overlay rebuilt to match (fixed-height spacers).
3. **`FilmBarcode`**: DX-style bars next to numbers. Every 3rd frame column per edge → always
   1–2 in frame. Bottom edge offset by one column (staggered vs top). Bars touch the OUTER rim.

**Albums:**
4. **Leave = instant disappear** — `AlbumService.leave()` optimistically removes the album from
   the local list (restores on failure). If the leaver is the LAST member, the roll deletes
   itself (shots + invite doc + album doc).
5. **`firestore.rules` updated** to allow the sole remaining member (not just creator) to delete
   the album and its shots. ⚠️ **NOT DEPLOYED** — needs `firebase deploy --only firestore:rules`.

**Removed features (per user):**
6. **Film stock / grade — GONE entirely.** Deleted `Models/FilmStock.swift`,
   `Screens/FilmStockPickerSheet.swift`; stripped `filmStockRaw` from Album, `StockPill`,
   `.filmStockGrade()` from all photo views, STOCK stat card, map-pin tint, saved-shot stockRaw.
7. **Sample music — GONE.** Deleted `Models/Soundtrack.swift`, `SoundtrackPickerSheet.swift`,
   `Audio/SlideshowAudioPlayer.swift`, `Resources/recap-placeholder.m4a`; stripped soundtrack
   fields from Album/AlbumService/CreateAlbumView, SoundtrackPill, slideshow audio calls.
   **NEXT STEP (user request): integrate Apple Music (free tier so everyone can use it).**

**Camera — fully rebuilt (`Screens/CameraView.swift`):**
8. The camera screen IS a photoreal device shell: asset **`CameraShell`**
   (source: `~/Downloads/device-final-cutout.png`, 887×1774). Top-anchored, scaledToFit,
   centered; all controls are mapped in the image's pixel space (see `Shell` enum in the file):
   screen cutout `(237,366,441×761)`, flash `(642,153)`, flip `(777,154)` r62,
   shutter `(455,1497)` r122, counter printed at ~`(150,1250)` left of the red LED.
9. Live viewfinder clips INSIDE the white cutout — focus ring, white-flash/black-out shutter
   ritual, and "sealed" confirmation all render inside the glass, never over the shell.
   Capture crops to the cutout's aspect (WYSIWYG).
10. **Caption field removed** (shots upload with empty note — `Shot.note` still exists for the
    slideshow). **Roll selector removed** — ONE album at a time; `CameraView(album:)` +
    `CameraTabView` picks last-used/most-recent developing roll. Frame counter shows
    `taken/24` (`rollCapacity = 24`, hardcoded — matches HomeView's "/ 24 SHOTS").
11. **`Screens/MainTabView.swift` rewritten**: paged TabView (`.page`, no dots) → **swipe**
    between Rolls · Camera · Profile; system tab bar replaced by a compact 40pt icon-only
    bar via `safeAreaInset(edge: .bottom)` so the camera shell gets maximum height.

## ⏳ Open items (in rough priority order)
1. **Deploy Firestore rules** (leave/auto-delete needs it):
   `cd ~/Desktop/Afterimage && firebase deploy --only firestore:rules`
2. **Apple Music integration** for roll soundtracks (user wants the free/no-subscription path —
   likely MusicKit preview clips or user-library playback; design TBD).
3. **Deploy functions** (older change: self-activity on the wire) — `firebase deploy --only functions`.
4. **Commit to git** — branch `feat/full-app-rebuild` has ALL of this uncommitted on disk.
5. **TestFlight**: build 1.0 (3) archive flow was in progress last month (External Testing +
   Public Link recommended). Camera/UI has changed a lot since — bump build number when archiving.
6. **Decision: lower the iOS 26 minimum?**
7. On-device verify of the new camera: shell fit, counter position/size, button hit targets —
   user may want coordinate nudges.

## Build / verify commands
```sh
# Build for the physical iPhone:
xcodebuild -project ~/Desktop/Afterimage/afterimage/afterimage.xcodeproj -scheme afterimage \
  -configuration Debug -destination 'id=00008140-0010396901A2801C' \
  -derivedDataPath /tmp/afterimage-device-build -allowProvisioningUpdates build
# Install:
xcrun devicectl device install app --device 1B32AB5E-78B3-5127-90D9-DF7A73153D81 \
  /tmp/afterimage-device-build/Build/Products/Debug-iphoneos/groupRoll.app
# (launch needs phone UNLOCKED; install works regardless)

# Deploy backend (keep storage rules deployed!):
cd ~/Desktop/Afterimage && firebase deploy --only storage,firestore:rules,functions
```

## Gotchas already solved (still true)
- Deployed Storage rules must stay deployed (default deny-all broke uploads once).
- "Glare not showing" on phone = iPhone Reduce Motion / Reduce Transparency (intended behavior).
- dSYM upload warnings for Firebase/grpc libs are harmless.
- App icon needs the FULL explicit size set in `AppIcon.appiconset` (single 1024 didn't expand).
- DEBUG builds launch signed out on fresh install (`signOutIfFreshBuild()`, DEBUG only).
- More history in `SESSION_LOG.md` and `MORNING_BRIEF.md`.

_All changes saved to disk, NOT committed. `git diff` in `~/Desktop/Afterimage` to review._
