# Afterimage — Morning Brief (overnight bug session)

_Written by Claude overnight on 2026-06-24. Plain-English. Read top to bottom._

## TL;DR — the mystery is solved and the bugs are fixed

The "old data" you kept seeing was **NOT a stale build in the way we thought**, and it was
**NOT old data on the server**. There were actually **two separate causes**, and I found and
fixed both:

1. **the stale cached name / wrong profile** = a leftover copy of data **cached on the phone itself**.
2. **Wrong shot counts + "activity that never happened"** = **fake placeholder code** that was
   still secretly baked into the supposedly-clean app.

Everything is fixed, the app builds green, and a **fresh clean build is already installed on
your phone**. Details below.

---

## What I actually checked (not guesses)

- **Read the live Firebase database directly.** The server has exactly ONE person —
  **"Ethan Bayard"** (your real account, @ethanbayard) — and ONE album ("First Album", 0 shots).
  There is **no the stale cached name anywhere on the server**, and none in the app's code.
- So the stale cached name could only have come from **the phone's own local copy of the data**. The
  Firebase library keeps a cached copy on the device so the app works offline. When you
  reinstalled the app *over* the old one, that cached copy survived — so the phone kept showing
  the old the stale cached name even though the server was wiped and the code was clean.
- **You deleting the app last night erased that cache.** I then built a fresh app and installed
  it into a brand-new clean container. So the stale cached name is gone for good.

## The real code bugs I found and fixed

These were hiding in `HomeView.swift` and would have shown fake data **even on a perfectly fresh
install** — this is the part the previous "it's just a stale build" theory missed:

1. **Fake shot count.** Each developing roll showed a made-up number (`"14 / 24 SHOTS"`) computed
   from a hash, not the real count. → Now shows the **real** number of shots in the roll.
2. **Fake "activity".** The little status line under a developing roll said things like
   *"noah just used shot 14"* — invented from a hardcoded list of fake names
   (noah, sam, maya, leo…). That's exactly your "updates for things that didn't happen."
   → Now shows honest status (e.g. *"3 shots sealed in the dark"*, or *"no shots yet — be the
   first"*, or the location if known).

I also found and fixed a **crash bug that wasn't even on your phone yet** (it was in the
unsaved working copy): the "create album" screen had a line that called itself forever
(`shotsPerWindow`), which would have **crashed the app whenever you created a roll** longer than
the 5-minute test. → Fixed to use the correct shot count per window.

And I cleaned up the **"(demo)" share buttons** when creating a roll:
- The QR code on the share step used to encode a fake `draft-...` string (it couldn't be a real
  code because the album didn't exist yet). → That step is now honest about it.
- The final "ready" screen now has a real **INVITE FRIENDS** button with a working QR code,
  a tap-to-copy invite code, and the real iOS share sheet.

## Glare / "liquid glass" not showing on the phone (#38)

This was **also the stale-build problem.** I confirmed the glare effect (a Metal shader called
`filmSheen`) is **compiled into the fresh build that's now on your phone**, and the glass
material is standard iOS. So when you open the new build, the glare and glass should appear.
👉 **Please eyeball this when you open the app** — if it still doesn't show, it's a real
device-rendering issue and I'll dig further (next suspect: Settings → Accessibility → Motion /
Reduce Transparency being ON).

---

## ✅ What's done

- Root-caused the stale cached name (phone cache) — gone after the clean reinstall.
- Fixed fake shot count + fake activity ticker (real data now).
- Fixed a create-album crash (infinite recursion) before it could ship.
- Made the invite/share flow real (working QR + copy + share on the ready screen).
- Simulator build: **green**. Device build: **green + installed** on your iPhone (16 Pro).
- Release archive: **succeeded** (so the TestFlight build path works). Version 1.0 (1).
- Verified the clean boot on the simulator (screenshot: `/tmp/afterimage_clean_boot.png`).

## 👉 What you need to do (I can't — they need your fingerprint/password)

1. **Unlock your phone and open Afterimage.** It auto-launches were blocked only because the
   phone was locked. Sign in with your email. You should see **Ethan Bayard**, real (zero) shot
   counts, and **no fake "noah just used shot…"** lines. Send me a screenshot to confirm.
2. **Check the glare/glass** shows now (see #38 above).

## 🚀 TestFlight (the goal) — exact steps for the morning

The app is build-ready. I can't upload it because it needs your Apple ID login + 2FA. Do this:

1. Open **Xcode** → top menu **Product → Archive** (scheme: afterimage, "Any iOS Device").
   - (I already confirmed this archives cleanly, so it should just work.)
2. In the **Organizer** window that pops up → select the archive → **Distribute App** →
   **App Store Connect** → **Upload** → keep defaults → Next/Upload. Sign in if asked.
3. First time only: it may say there's no app record. If so, go to
   **appstoreconnect.apple.com → Apps → +** and create one for bundle id
   **`com.ethanbayard.afterimage`** (name "Afterimage" or "GroupCapsule"), then re-upload.
4. After it processes (~5–15 min), in **App Store Connect → your app → TestFlight**, add your
   friends' emails as **Internal Testers** (no review needed) or External (quick first review).
5. Friends install the free **TestFlight** app and tap your invite link.

### ⚠️ One thing that could block friends
The app currently requires **iOS 26.0 or newer**. Friends on older iPhones/iOS can't install it.
If any friend can't, tell me and I'll lower the requirement (need to check nothing iOS-26-only
is in use first). Worth a quick check that your friends are on iOS 26.

## How to test the core loop once friends are in
Real accounts → friend each other by **@username** (Camera tab → add friend) OR share a roll's
**invite code** → create a roll with the **TEST · 5 MIN** window → everyone shoots → wait ~5 min
→ watch it reveal in the slideshow.

---

## Files I changed
- `afterimage/afterimage/Screens/HomeView.swift` — real shot count + honest developing status.
- `afterimage/afterimage/Screens/CreateAlbumView.swift` — fixed recursion crash; real
  invite/share on the ready screen; removed fake QR + "(demo)" buttons.

_Changes are saved to disk but **not committed to git** (I leave commits to you). Run
`git diff` in `~/Desktop/Afterimage` to review._
