# Afterimage — Dev Setup & Runbook

Everything you need to keep the app running on your phone and iterate on it.

---

## Daily workflow (the common case)

You're at home, the Mac and phone are both on. You want to make changes and see them.

1. **Make sure InjectionIII is running** — orange syringe icon in the Mac's menu bar. If it's not there, open `Applications → InjectionIII`. Leave it running. It auto-watches the project folder.
2. **Open Xcode**, make sure the destination dropdown at the top says your iPhone's name (not a simulator).
3. **Plug your phone in** (or trust it's on the same Wi-Fi for wireless debugging).
4. **Hit play (▶)**. App installs and launches on your phone.
5. **Now just edit and save.** Any change to a `.swift` file (colors, fonts, padding, view bodies, modifiers) lands on your phone in under a second. No need to hit play again.

### What requires a full rebuild (⌘R) instead of hot-reload

- Adding a brand-new `.swift` file
- Adding a new `@State` or `@AppStorage` property to an existing view
- Changing how something is initialized (e.g., changing a `struct` to a `class`)
- Anything related to the project file, packages, or capabilities

For all other edits (the vast majority), just save and look at your phone.

---

## The 7-day re-install ritual

Because you're using a free Apple ID (no $99/yr subscription), the app revokes itself after 7 days. The icon goes gray.

**To refresh it:**

1. Plug phone into Mac
2. Open Xcode (the project should still be open from before)
3. Make sure your phone is the destination
4. Hit play (▶)
5. Wait ~30 seconds
6. App is good for another 7 days

Set a calendar reminder for every 6 days if you don't want to be surprised.

---

## First-time setup (already done, for reference)

These are the one-time steps already completed. Documenting in case you need to redo them on a new Mac or phone.

### 1. Apple ID in Xcode

`Xcode → Settings… → Accounts → +` → sign in with `ethanbayard@gmail.com`.

### 2. Signing

Project icon in sidebar → **Signing & Capabilities** → set **Team** to `Ethan Bayard (Personal Team)`. Bundle ID: `com.ethanbayard.afterimage`.

### 3. Developer Mode on the iPhone

On the phone: `Settings → Privacy & Security → Developer Mode → On → Restart → Turn On → enter passcode`.

### 4. InjectionIII (hot reload)

- Installed from Mac App Store
- Project directory set to `/Users/ethanbayard/Desktop/Afterimage/afterimage`
- `Inject` Swift package added in Xcode (`File → Add Package Dependencies → https://github.com/krzysztofzablocki/Inject`)
- Code wired up in `afterimageApp.swift` (bundle loader, DEBUG only) and `ContentView`, `HomeView`, `ProfileView`, `AlbumDetailView`, `SignInView` (each has `@ObserveInjection` + `.enableInjection()`)

---

## Common errors and fixes

### "Signing for 'afterimage' requires a development team"

→ Project icon → Signing & Capabilities → Team dropdown → pick your name.

### "Developer Mode disabled"

→ On the **iPhone**: Settings → Privacy & Security → Developer Mode → On → restart.

### "Untrusted Developer" (when app first launches on phone)

→ On the phone: Settings → General → VPN & Device Management → tap your email → tap **Trust**.

### "No such module 'Inject'" or "Cannot find 'enableInjection' in scope"

→ Xcode menu: `File → Packages → Reset Package Caches`. Then hit play.

### Build seems stuck or weird errors after pulling code

→ Hold **Option** key → click **Product** menu → click **Clean Build Folder**. Then play (▶).

### App installed but Xcode says "could not launch"

→ Just tap the Afterimage icon on the phone's home screen manually. App opens fine.

### Phone not showing up in Xcode destination dropdown

- Unplug + replug the cable
- Make sure phone is unlocked
- `Window → Devices and Simulators` in Xcode — check if your phone is listed there

### "codesign wants to access keychain" popup keeps appearing

→ Type your **Mac login password** and click **Always Allow** (not just Allow). It'll stop asking.

---

## Working away from home

**The hard truth:** InjectionIII (live reload) only works when phone and Mac are on the same Wi-Fi network. There's no workaround.

**What you can do remotely:**

| Goal | Setup | Speed |
|---|---|---|
| Use Claude Code on your home Mac from your phone | Tailscale + Blink Shell SSH | Edits are instant; phone update needs a rebuild |
| Get the rebuilt app onto your phone without coming home | Apple Developer Program ($99/yr) + TestFlight upload | ~15-30 min per update |
| Just queue up edits for when you're back | Same Tailscale + SSH, no TestFlight | Updates land when you next plug into Mac |

### Tailscale + SSH (free, works anywhere)

1. Install Tailscale on Mac and phone (free): [tailscale.com/download](https://tailscale.com/download)
2. Sign in with the same account on both
3. Enable Remote Login on Mac: System Settings → General → Sharing → Remote Login (on)
4. On phone, install **Blink Shell** (or any SSH app)
5. SSH in via the Mac's Tailscale address: `ssh ethanbayard@your-mac-tailscale-name`
6. Run `claude` in the terminal — Claude Code session on the Mac, controlled from your phone

### TestFlight (if you enroll in Apple Developer Program)

Once enrolled, you can:
- Drive Claude Code remotely (via SSH above)
- Tell Claude: "build a release archive and upload to TestFlight"
- Claude runs `xcodebuild archive` + `xcrun altool --upload-app`
- ~15-30 min later, TestFlight pushes a notification to your phone
- Tap Update → installed, no cable needed

This is the only way to truly install updates while away from your Mac without $99/yr there's no workaround.

---

## Project layout

```
~/Desktop/Afterimage/                    ← git repo root
├── .git/
├── DESIGN.md                            ← design system reference
├── IMAGEGEN_PROMPTS.md                  ← image-gen prompts for the brand
├── firestore.rules                      ← (for when you go non-sample mode)
├── DEV_SETUP.md                         ← this file
└── afterimage/                          ← Xcode workspace folder
    ├── afterimage.xcodeproj             ← open this in Xcode
    └── afterimage/                      ← source code
        ├── afterimageApp.swift          ← entry point
        ├── ContentView.swift            ← root view (auth / onboarding / main tabs)
        ├── Models/                      ← Album, Shot, Comment, FilmStock, etc.
        ├── Screens/                     ← every view (HomeView, ProfileView, …)
        ├── Components/                  ← reusable bits (LivingMotion, RollPostElements, …)
        ├── Services/                    ← AlbumService, AuthService, etc.
        ├── Sample/                      ← SampleData (the whole app runs off this)
        ├── Theme/                       ← Palette + Motion
        ├── Gallery/                     ← design gallery + widget mockups
        └── Assets.xcassets/
```

---

## Sample-only mode (what's wired and what isn't)

The whole app currently runs off `SampleData`. No Firestore writes happen.

- ✅ All 7 sample albums (Sam's Birthday, Road Trip, NYE 2025, Beach Day, Festival, Concert, Spring Escape) show up
- ✅ Sample friends, comments, activity events, notifications, locations, soundtracks, film stocks
- ❌ Creating a new roll = demo toast, no actual write
- ❌ Joining a roll via QR/code = demo toast, no actual write
- ❌ Friend requests = local UI state only
- ❌ Rename/delete/leave album = demo toasts

To flip to real mode (when you're ready), the work is documented in the original conversation — basically uncomment ~6 small blocks of code in `CreateAlbumView`, `JoinAlbumView`, `HomeView`, `ProfileView`, `CameraTabView`, and `AlbumSettingsView`.

---

## Onboarding reset

In `ContentView`, there's a `CURRENT_RESET_VERSION` constant. Bump it (1 → 2 → 3) to make every device replay onboarding + clear coach marks on next launch. Set it back when done. This is how to wipe state during testing without uninstalling.

```swift
private static let CURRENT_RESET_VERSION = 1   // ← change this to force a wipe
```

---

## Hot tips

- **Cmd+Shift+O** in Xcode = "Open Quickly" — fastest way to jump to any file by name
- **Cmd+Shift+J** = reveals the current file in the project navigator
- **Cmd+R** = build and run
- **Cmd+B** = just build, don't launch
- **Cmd+.** = stop the running app
- **InjectionIII spinning syringe icon** means it just hot-swapped your code. If it doesn't react when you save, hot-reload isn't working — check that the InjectionIII app has the right project directory.
- **In the Xcode console**, you'll see a 💉 emoji when injection succeeds. If you see no 💉 after saving, something is wrong.

---

## When to come home vs. when you don't have to

| Task | Need to be at Mac? |
|---|---|
| See live design changes | Yes |
| Refresh the 7-day install | Yes (need to plug in) |
| Edit code (via SSH) | No (Mac stays at home, you SSH in) |
| Update app on your own phone over cellular | Only with TestFlight ($99/yr) |
| Send a build to a friend | Only with TestFlight |
| Just use the app offline | No — once installed, it works anywhere |

---

*Last updated: original setup done June 2026. Update this doc when the workflow changes.*
