# Afterimage — Full Session Log

_A complete record of everything done in this working session: a feature pass, the
migration from sample-only to a live Firebase backend, the go-live setup, and a
full strip of all sample/demo data. Ends with current state + open items._

---

## Part 1 — Feature changes (UI pass)

**Removed**
- Voice notes (docs only), Year in Rolls, Face tagging, photo pinch/zoom, the profile search bar, and the camera "choose a roll" picker page.

**Added / fixed**
- **Captions vs comments** split — comments broadcast to the whole roll; captions are the author's note written at shutter time, printed on the photo.
- **Profile = feed** — roll rows render as the exact film-strip cards from the feed (identity header + stats kept).
- **Smooth pan loop** — film strip driven by one monotonic clock (no backward "hard reset"); sprockets phase-locked.
- **Movie mode** — crossfade (later changed to hard cuts, see Part 4), bigger X, orientation-aware motion (vertical frozen, horizontal pan-then-zoom).
- **Camera** — opens immediately on the last-used roll with a top roll-selector.

---

## Part 2 — Real Firebase backend (migration)

Migrated the whole app from baked-in sample data to live Firebase (project `afterimage-671e4`).

**App (Swift)**
- Auth + profiles: `UserService`, `UserProfile`, `ProfileSetupView` (claim a unique `@handle`), real `ContentView` gate.
- Albums: live list + create / join-by-invite-code / rename / leave / delete. `Album` gained `inviteCode`, `previewURLs`, `shotCount`, lat/lng/`locationName`.
- Shots + GPS: capture uploads to Storage; GPS stamped on the first shot.
- Comments: real Firestore thread.
- Social: `FriendService`, `ActivityService`, `NotificationService`, `SocialModels.swift`, `PersonRef`. Friends, activity rail, notifications, map, On-This-Day all wired to real data.
- Push: FirebaseMessaging linked; `AppDelegate` + `PushRegistry`; FCM token saved to the profile; entitlements + Background Modes added.

**Backend**
- Cloud Functions (`functions/`, TypeScript): `onShotCreated`, `onCommentCreated`, `onAlbumCreated`, `onReactionChanged`, `onFriendRequestCreated`, `onFriendRequestUpdated`, `scheduledRevealCheck`.
- Security: `firestore.rules`, `storage.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc`.

---

## Part 3 — Go-live setup (completed)

Firebase project **`afterimage-671e4`**.

1. `firebase login` ✓
2. Blaze plan — already active (free-trial credit) ✓
3. Email/Password sign-in — enabled ✓
4. `firebase deploy --only firestore,storage,functions` — rules + storage + indexes + all 7 functions deployed ✓ (functions needed a couple retries while Google provisioned Eventarc — normal).
5. Push: APNs key created in the Apple Developer portal and uploaded to Firebase.
   - Key file: `AuthKey_6W8J7T7WTF.p8` (Downloads — download-once)
   - **Key ID:** `6W8J7T7WTF` · **Team ID:** `TM7HX4FKWA`
   - Xcode push capability + Background Modes added by editing the project directly; signing was already Automatic with Team `TM7HX4FKWA`.

---

## Part 4 — Strip ALL sample data + clean slate (latest pass)

Goal: behave like a shipped App Store app — no fake data, no developer features, fresh empty database.

**Decisions (from owner):** email+password login (relabeled "Email"/"Password"); wipe the live DB; camera always open with no ✕; slideshow hard cuts; glare must track scroll; keep tutorial tips + bookmarks + the cinematic voice; remove the Design Gallery, demo labels, InjectionIII, the `AppConfig` flag.

**Done**
- Deleted `Sample/SampleData.swift`, `SampleDataExtras.swift`, `ActivityStore.swift`, `SampleSessionShots.swift`, `SlideshowCaptions.swift`, `AppConfig.swift`, and the entire `Gallery/` folder. (Kept `SavedShotsStore.swift`.)
- Removed every `AppConfig.useSampleData` branch across ~20 files (kept the real path), all `SampleData`/`SampleSessionShots`/`ActivityStore`/`SlideshowCaptions`/`.isSample` references, all "demo:" toasts, the "demo mode" label, and InjectionIII (imports, modifiers, and the SPM package itself).
- Relocated the real `Album` display helpers (`filmStock`, `soundtrack`, `mapCoordinate`, `mapLocationName`, `stripPreviewURLs`, `displayShotCount`) into `Models/Album.swift`.
- Recreated shared UI (`SectionLabel`, `AvatarCircle`) that had lived in the deleted Gallery folder, in `Components/SharedUI.swift`.
- Sign-in labels → **Email / Password**.
- Camera renders **inline** (always open, no ✕) — `CameraTabView` no longer uses a fullScreenCover.
- Slideshow `transition(to:)` is now an **instant hard cut** (previous frame held until the next loads — no fade, no flash).
- Bookmarks: `SavedShotsStore` now stores id + photoURL + roll name so the profile **SAVED** rail works for real shots.
- Comment-row avatars resolve via `UserService` by uid.
- **grep verified: zero references** to `SampleData` / `AppConfig` / `Inject` remain. **BUILD SUCCEEDED.**
- **Firestore wiped** (`firebase firestore:delete --all-collections --force`): `albums`, `users`, `usernames`, `invites`, feed, notifications — all gone.
- Clean app rebuilt for the iPhone (device id `1B32AB5E-78B3-5127-90D9-DF7A73153D81`), old copy uninstalled, fresh copy installed. Verified it runs on the **simulator**: boots to onboarding → sign-in, no sample data, no crash.

---

## Current state & open items

✅ Codebase: clean, real-only, builds green. Simulator boots correctly to onboarding → sign-in.
✅ Database: empty / fresh.

⚠️ **Reported on the physical phone:** still seeing sample data, and the glare / "liquid glass" effects not showing — while the simulator shows them. This strongly suggests **the phone is still running an older build** (the fresh clean build's auto-launch failed earlier with error 10002 because the phone was locked, so the previously-installed sample build may still be what's opening). **Fix:** delete the Afterimage app from the phone by hand (long-press → Remove App → Delete), then reinstall the fresh build (rebuild from Xcode with the phone selected, or have it pushed over cable). After that the phone should match the simulator.

ℹ️ Auth *login* accounts were not bulk-deleted (no CLI for it). Harmless now (no data); to remove: Firebase Console → Authentication → Users → select → Delete.

ℹ️ Create-roll **share** step: iMessage/AirDrop/Copy buttons are still placeholders ("(demo)") — Copy could be wired to copy the real invite code.

---

## How to give the app to your friends

The app is now real, so the question is distribution. The standard path:

1. **TestFlight (recommended).** In Xcode: **Product → Archive** → **Distribute App → App Store Connect → Upload**. Then in **App Store Connect → TestFlight**, add your friends as testers by email (internal testers need no review; external testers need a quick first-build review). They install Apple's free **TestFlight** app and tap your invite link.
2. **Ad-hoc / direct install.** Requires registering each friend's device UDID in your developer account and building an ad-hoc IPA — fiddlier than TestFlight, only good for 1–2 people.
3. Each friend signs up (Email/Password), claims a handle, and you connect via **@username search** or a roll's **invite code / QR**.

Before inviting friends, make sure the **phone build matches the simulator** (see the ⚠️ above) so everyone's on the clean real app.

---

## Handy commands

- Build + run on the connected iPhone: select the phone in Xcode's device bar, press ▶︎ (Cmd+R). First run on a new device: trust the developer in iPhone → Settings → General → VPN & Device Management.
- Redeploy functions after edits: `cd ~/Desktop/Afterimage && firebase deploy --only functions`
- Redeploy rules: `firebase deploy --only firestore:rules,storage`

---

_Sample-only beta → live, clean, real app — in one session._ 🎬

---

## Round 7 — overnight bug session (2026-06-24)

**The "stale data" mystery — fully root-caused (two causes, not one):**
1. **the stale cached name phantom = on-device Firebase cache.** Read the live Firestore directly: server
   has only the real **"Ethan Bayard"** user + one "First Album" (0 shots). the stale cached name was a
   leftover in the phone's local Firestore offline cache, which survives reinstall-over-the-top.
   Deleting the app clears it → fixed by the clean reinstall.
2. **Fake data was still in the "clean" code.** `HomeView.swift` developing card used a hash-based
   `fakeShotCount` and a fabricated `ticker` ("noah just used shot 14" from a hardcoded name list)
   → replaced with real `album.displayShotCount` + honest status. This caused "wrong shot counts"
   and "activity that never happened," and it would show on ANY fresh install.

**Also fixed:**
- **Create-album crash (latent):** `CreateAlbumView.shotsPerWindow` was infinite self-recursion
  in the working tree (would crash creating any non-test roll). Fixed via `durationOptions` lookup.
- **Demo share buttons:** create-flow share step no longer fakes a `draft-` QR + "(demo)" toasts;
  the ready screen now has a real **INVITE FRIENDS** button (working QR + copy code + iOS share).
- **#38 glare/glass on phone:** confirmed the `filmSheen` Metal shader IS compiled into the device
  build (`default.metallib`) — so this was the stale build too; should render on the fresh install.

**State:** sim build green · device build green + **installed fresh** on the iPhone (clean
container) · Release archive **succeeded** (v1.0/1, min iOS 26.0). Clean boot verified on sim.

**Left for the user:** unlock phone + open app + sign in (confirm clean) · visually confirm glare ·
TestFlight upload via Xcode Organizer (needs Apple ID/2FA). ⚠️ min iOS 26.0 may block friends on
older iOS. Full details: `MORNING_BRIEF.md`.
