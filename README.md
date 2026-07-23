# Afterimage

A disposable camera for groups. You shoot, you wait, you reveal together at sunrise.

---

## What it is

Afterimage is an iOS app that turns photo-sharing into a slow, shared ritual.

You start a **roll** with friends — name it, pick a film stock, attach a song, set how long it should develop (1, 2, or 5 days). Everyone in the roll shoots photos into it. You can see what you're aiming at through the camera, but the second you press the shutter the frame disappears — no preview, no retakes, no filters. You wait. The window closes. At the next sunrise, every shot from every person opens at the same moment for the whole group.

That's the whole product. The point isn't to broadcast. The point is to remember together.

---

## The ritual

1. **Load the roll** — name it, pick a film stock, attach a soundtrack, choose how long it develops
2. **Invite** — friends scan a QR or paste a code to join
3. **Shoot blind** — every press of the shutter is permanent. No preview, no retakes
4. **Wait** — the roll develops in the dark. Nobody sees anything, not even you
5. **Reveal at sunrise** — at the next sunrise after the window closes, the whole roll opens at once for everyone in the group
6. **Talk** — comments and captions. The memory is the conversation

---

## Why it exists

Modern photo apps are built around three assumptions:

1. **You should see your photo before it's saved.** So you can re-take it. So you can curate.
2. **You should be able to edit.** Filters, crops, color grades, AI cleanup.
3. **You should post for an audience of strangers.** The algorithm decides who sees it.

Each of these makes the photo *better* but the memory *worse*. The picture you keep is the one that survived ten retakes and a beauty filter. The moment itself is gone.

Afterimage breaks all three. The shutter is final. There are no filters in the moment — you pick a film stock when you load the roll, and that's the only "treatment" applied. And the audience is exactly the people who were there with you. No strangers. No algorithm. No public feed.

The wait is the feature. Anticipation is the medium. The reveal is the payoff.

---

## What's actually in the app

### Surfaces
- **Rolls feed** — every roll you're part of, developing or developed, as a film-strip card
- **Camera** — locked to one roll at a time, no preview, full shutter ritual (flash → blackout → "added to the roll")
- **Profile** — your personal archive, presented as an editorial film ledger
- **Album detail** — the developed roll viewed full-screen, with comments and captions
- **Settings / Friends / Notifications** — the quiet machinery

### Features
- **Film stocks** with real color grades — Kodak Portra 400, Cinestill 800T, Ilford HP5, Lomo Redscale, Polaroid 600, Fuji Superia
- **Soundtracks** — one song per roll, plays under the reveal cinematic
- **Captions** — the shot's author writes a caption as they shoot; it's printed on the frame at reveal
- **Map** — see where every roll was shot
- **Search** — find rolls by name, location, stock, or soundtrack
- **Bookmarks** — save individual shots from other people's rolls
- **Activity rail** — live feed of what your friends are doing (started a roll, revealed one, tagged you)
- **On This Day** — surface a roll from one year ago today

### Things the app deliberately does NOT have
- No public feed
- No followers
- No filters in the camera
- No edit-after-shooting
- No algorithmic ranking
- No emoji reactions on photos — only comments
- No ads
- No analytics

---

## The vibe

**Editorial Luxury.** Warm charcoal background (`#0E0B0A`), tarnished gold accent, film red. Bebas Neue for display type, Times New Roman italic for connective tissue, Menlo for monospace stamps and edge prints.

Every active surface has perpetual micro-motion — sprockets drift like running film, grain twinkles on every card, titles flicker like projector lamps, the developing aperture breathes. The app feels mechanical, not digital.

The voice is literary and patient. Never "elevate your photos" or "unleash your creativity." Words like *roll, develop, reveal, sunrise, frame, sealed* show up everywhere. Words like *post, feed, share, content* never do.

See `DESIGN.md` for the full design system reference.

---

## Status

Currently a **single-developer iOS app in sample-only beta**. The whole app runs off curated sample data — 7 sample rolls, 11 sample friends, threaded comments, soundtracks, locations. No Firestore writes. This is intentional during the design + iteration phase.

The real-mode plumbing is all written and ready to flip on (`AlbumService`, `AuthService`, `ShotService`, `CommentService` all have real Firebase implementations). Switching to real mode is a roughly half-day of work documented in this conversation's history — disable the sample-only stubs in `CreateAlbumView`, `JoinAlbumView`, `HomeView`, `ProfileView`, `CameraTabView`, and `AlbumSettingsView`.

### Tech stack
- **SwiftUI** (iOS 26.5+)
- **Firebase** (Auth, Firestore, Storage) — wired but currently inactive in sample-only mode
- **AVFoundation** — real camera capture + QR scanning
- **MapKit** — for the roll location map
- **Custom motion system** — `TimelineView`-driven perpetual micro-loops, custom cubic-bezier easings, respects `accessibilityReduceMotion`
- **InjectionIII** — hot reload during development (debug builds only)

### Build target
- iPhone, iOS 26.5 minimum
- Built on Xcode 26

---

## Project layout

```
~/Desktop/Afterimage/                    ← git repo root
├── README.md                            ← this file
├── DESIGN.md                            ← design system reference
├── MARKETING.md                         ← positioning, taglines, launch plan
├── DEV_SETUP.md                         ← how to run + iterate on the app
├── IMAGEGEN_PROMPTS.md                  ← image-gen prompts for brand assets
├── firestore.rules                      ← rules for when real-mode flips on
└── afterimage/                          ← Xcode workspace folder
    ├── afterimage.xcodeproj             ← open this in Xcode
    └── afterimage/
        ├── afterimageApp.swift          ← entry point
        ├── ContentView.swift            ← root router (auth / onboarding / main tabs)
        ├── Models/                      ← Album, Shot, Comment, FilmStock, Soundtrack, …
        ├── Screens/                     ← every view (HomeView, ProfileView, AlbumDetailView, …)
        ├── Components/                  ← reusable bits (LivingMotion, RollPostElements, …)
        ├── Services/                    ← AlbumService, AuthService, ShotService, …
        ├── Sample/                      ← SampleData (the whole app runs off this)
        ├── Theme/                       ← Palette + Motion
        ├── Gallery/                     ← 38-screen design gallery + widget mockups
        └── Assets.xcassets/
```

---

## Documentation index

- [**DESIGN.md**](./DESIGN.md) — color tokens, typography, components, motion, voice, "absolute zero" anti-patterns
- [**MARKETING.md**](./MARKETING.md) — positioning, audience, taglines, launch strategy, partnerships
- [**DEV_SETUP.md**](./DEV_SETUP.md) — how to run on your phone, hot reload, troubleshooting, remote dev workflow
- [**IMAGEGEN_PROMPTS.md**](./IMAGEGEN_PROMPTS.md) — paste-ready prompts for generating brand imagery
- [**firestore.rules**](./firestore.rules) — draft security rules for when the app flips to real mode

---

## One-liner pitch

> **Afterimage is a disposable camera for groups. Shoot blind, wait for sunrise, develop together. No retakes, no filters, no algorithm.**

---

*Built solo. Sample-only beta. The ritual comes first.*
