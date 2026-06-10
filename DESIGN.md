# Design System: Afterimage

> Source of truth for Afterimage's visual language. Anyone (human or AI) generating
> new screens, components, or copy for this app must align to this document.
> Last revised after the "taste-skill" pass.

---

## 1. Visual Theme & Atmosphere

**Mood.** Dimly lit. Cinematic. Physical. Anticipatory. Imperfect. Alive.
The reference is *not* Silicon Valley minimalism. The references are Kodak
disposable cameras, HBO *Euphoria* title cards, old contact sheets,
Wong Kar-wai color grading, dusty shoeboxes of Polaroids, darkroom chemistry.

**Emotional keywords.** Anticipation. Nostalgia. Warmth. Mystery. Memory.
Chemical process. Surviving moments. *Never*: clean, sterile, optimized,
creator-focused, productivity-like.

**Active design dials.**
- `DESIGN_VARIANCE`: 6 (intentional asymmetry, never artsy-chaos)
- `MOTION_INTENSITY`: 6 (fluid cinematic; perpetual micro never)
- `VISUAL_DENSITY`: 4 (balanced; airy on Profile, denser on the Rolls feed)
- `ART_DIRECTION`: 9 (every surface is curated, not utilitarian)
- `TEXTURE_STRENGTH`: 7 (film grain on cards; sprocket strips; warm shadows)
- `COLOR_PALETTE_DISCIPLINE`: 10 (no off-palette colors, ever)
- `NON_GENERICITY`: 10 (must always feel specifically Afterimage)

---

## 2. Color Calibration

All values are exact `Color(red:green:blue:)` decimals as defined in
`Theme/Palette.swift`. **Never** use pure `#000000` or pure `#ffffff` —
every color in the system is tinted toward warm brown.

### Backgrounds (warm charcoal, never true black)
| Token              | Hex      | Use                                     |
|--------------------|----------|-----------------------------------------|
| `background`       | `#0E0B0A` | Root app background, modal underlays.  |
| `surface`          | `#141110` | Cards, sheets, elevated containers.    |
| `surfaceElevated`  | `#1A1715` | Inner cores of double-bezel components.|
| `border`           | `#292319` | Hairlines, separators, faint edges.    |

### Typography (muted cream, never true white)
| Token            | Hex      | Use                                  |
|------------------|----------|--------------------------------------|
| `textPrimary`    | `#F0E7DA` | Headlines, body, primary text.       |
| `textSecondary`  | `#C6B8A4` | Subtitles, captions, supporting copy.|
| `textTertiary`   | `#73685D` | Labels, hints, timestamps.           |

### Accents (used sparingly)
| Token       | Hex       | Use                                          |
|-------------|-----------|----------------------------------------------|
| `gold`      | `#C8A96B` | Identity. Primary CTAs, contributor badges, "developed" states. Aged Leica brass — never bright yellow gold. |
| `goldDeep`  | `#B8924F` | Deeper variant for shadows on gold elements. |
| `red`       | `#A61E1E` | "Developing" indicator, presence gating. Darkroom safe-light. |
| `darkRed`   | `#8E1B1B` | Reveal-stage ripples, urgent countdowns.     |
| `success`   | `#788C73` | Confirmations only. Aged sage, never iOS green. |

### Banned colors
- `#000000` pure black
- `#FFFFFF` pure white
- Any blue, purple, teal, neon, or "AI gradient" hue
- Any saturated yellow gold (this is not Bitcoin)
- Multiple competing accents (we have exactly one: gold)

---

## 3. Typography Architecture

Afterimage uses **three** type families. No others.

### Display & Labels — `Bebas Neue`
- Use for: album titles, section headers, process strips, button labels, eyebrow tags.
- Treatment: condensed sans, **uppercase**, generous tracking (`2–6pt`).
- Sizes:
  - Hero / album title: `36pt`, tracking `3`
  - Section header: `13pt`, tracking `4`
  - Eyebrow / process strip: `12–13pt`, tracking `2–3`
  - Button label: `15–16pt`, tracking `3`

### Body & Editorial — `Times New Roman` (italic preferred)
- Use for: moment notes, comment bodies, subtitles, copy that should feel literary.
- Treatment: italic by default for short copy. Roman for longer paragraphs.
- Sizes:
  - Comment body: `15pt italic`, line-spacing `2pt`
  - Subtitle / kicker: `12–13pt italic`
  - Caption: `11pt italic`

### Numerics & Process Codes — `Menlo` (monospace)
- Use for: timestamps, shot counters, frame numbers, "PROCESS C-41", percentage readouts.
- Sizes: `9–11pt`, tracking `1–2`.
- All numbers anywhere data-heavy should be tabular-figure (`Menlo`).

### Banned fonts
- `Inter`, `SF Pro`, `Roboto`, `Arial`, `Open Sans`, `Helvetica` — anywhere
- Any other serif (Georgia, Palatino, etc.) — Times is the one allowed serif
- Any rounded display fonts (`Rubik`, `Nunito`, etc.)
- Any handwriting / script faces

### Typographic anti-patterns
- All-caps subheaders **except** in Bebas Neue (intentional editorial voice).
- Title Case Headers — use either UPPERCASE Bebas Neue or sentence case italic Times.
- 4+ line headlines — keep titles to 1–3 lines.
- Orphan words on the last line — rephrase or shorten.
- More than two weights per surface.

---

## 4. Components

### 4.1 Cards (Double-Bezel / Doppelrand)

Premium cards are never flat. Wrap every hero card in a nested outer shell
+ inner core with concentric radii. Implemented as `.doubleBezel(...)`.

- Outer shell: subtle bg (`white/3` or `gold/6` for gold-themed), hairline border, larger radius (16–18pt).
- Inner core: opaque `surface`, smaller radius (`outer - padding - 1`).
- Apply to: Year in Rolls card, Design Gallery card, all Profile feature cards.

### 4.2 Buttons

- **Primary CTA**: Capsule shape, filled `gold`, black text in Bebas Neue
  16pt tracking 3, `pressEffect()`, `warmShadow()`. Never use `cornerRadius: 6`
  on a primary CTA — capsules read as buttons, rectangles read as cards.
- **Button-in-button trailing icon**: If a CTA has a trailing icon (`→`, `▶`),
  the icon must be nested inside its own circle pill flush with the right edge
  (`Circle().fill(.black.opacity(0.18))` for gold-bg buttons).
- **Secondary**: Capsule outline only, no fill, `red` or `textSecondary` stroke.
- **Tertiary**: Plain text link in `gold` italic, no background.
- **Tactile feedback**: every interactive element scales to `0.97` and lifts
  `1pt` on press via `.pressEffect()`. No instant state flips.

### 4.3 Comments — Scrapbook Margin Annotations

- No card backgrounds. Margin annotations only.
- Left vertical rule (gold for contributors, faded ink for non-contributors).
- Avatar at `22pt` inline with the username.
- Username in Bebas Neue `13pt` tracking 2, gold if contributor.
- Body in Times New Roman italic 15pt with `2pt` line spacing.
- Mentions (`@username`) auto-highlighted in gold semibold via `MentionText`.
- "Re: shot 03" reference chip in mono 10pt, gold.
- Reply threading via indent-only (no connector line).

### 4.4 Album Cards

Two variants. Type is determined by `album.isRevealed`.

**Developing Film Strip (`DevelopingFilmStripCard`)**:
- Bebas Neue title + LCD shot counter top.
- Sprocket strip → red darkroom glow frames → sprocket strip.
- Footer with pulsing red "DEVELOPING" dot, italic countdown,
  live ticker, members strip, gold "PREVIEW SUNRISE" pill.
- Subtle film grain canvas overlay.

**Revealed Roll Card (`RevealedRollCard`)**:
- Process strip: `01` box + `PROCESS C-41` + location chip + date stamp.
- Album title at Bebas Neue 36pt, tracking 3.
- Avatars row (all contributors visible, no overflow) + shot count.
- 3×3 polaroid grid: photos with cream borders, **no per-tile rotation**,
  **single container shadow**.
- Sprocket strip footer with frame number annotations (`6`, `→ 6A`).
- Subtle film grain overlay.

### 4.5 Inputs

- Capsule shape. `surface` background, hairline border.
- Label above input in Bebas Neue 11pt tracking 2 textTertiary.
- Helper text below, italic Times 11pt textTertiary.
- Error text in `red`, inline below the input.
- Focused state: gold border, no glow.

### 4.6 Empty / Loading / Error states

Every screen must define these explicitly.
- **Empty**: composed view with icon + 1-line headline (Bebas Neue) + italic-serif body + primary CTA.
- **Loading**: "Winding film…" copy with skeleton blocks matching layout, not generic spinners.
- **Error**: red inline message, never modal alerts. "Couldn't post" / "Upload failed — try again."

---

## 5. Layout Principles

- **Spacing scale**: only use `4 / 8 / 12 / 16 / 24 / 32 / 48` pt. Nothing else.
- **Section vertical rhythm**: 22–28pt between major sections inside a scroll view.
- **Card internal padding**: `12–14pt` consistent.
- **Touch targets**: minimum `44 × 44pt` for any interactive element.
- **Single-column** everywhere. No multi-column layouts on mobile.
- **No carousel pagination dots** as the primary navigation. Native scroll only.
- **No bottom-sheet half-modals** for input — use full sheets for any form.
- **`min-h-[100dvh]`** equivalent in SwiftUI: use `.frame(maxHeight: .infinity)`
  inside a `GeometryReader`, never hardcode height.

### Banned layouts
- 3-equal-card horizontal row as a feature grid
- Edge-to-edge sticky navbar pinned to top (we have a floating gold logo + bell icons inline)
- Symmetrical centered hero
- Generic infinite-scroll feed pattern (Rolls feed is curated card-per-roll, not endless)

---

## 6. Motion Philosophy

Three canonical curves in `Theme/Motion.swift`. No other curves allowed.

| Token              | Curve                                          | Use                                               |
|--------------------|------------------------------------------------|---------------------------------------------------|
| `Motion.expressive`| `cubic-bezier(0.32, 0.72, 0, 1)` 550ms        | Sheet enters/exits, expand/collapse, tab swaps.  |
| `Motion.cinematic` | `cubic-bezier(0.16, 1, 0.3, 1)` 850ms         | Sunrise reveal stages, recap slide advances.     |
| `Motion.tap`       | `spring(response: 0.28, damping: 0.78)`        | Button press, tactile feedback.                  |
| `Motion.weighty`   | `spring(response: 0.55, damping: 0.86)`        | Cards moving in/out — weight, not bounce.        |
| `Motion.staggered(i)` | expressive with `0.06s * i` delay           | Cascade list reveals.                            |

### Motion anti-patterns
- `.easeInOut` — banned. Replace with `Motion.expressive`.
- `.linear` — banned except for explicit flash overlays (90ms).
- Default `.spring()` with no parameters — banned.
- Instant state changes without interpolation.
- Continuous infinite animations on the feed (kills scroll perf).

### Perpetual micro-interactions (where allowed)
- Developing film strip: red dot pulsing (very subtle, 1.4s cycle).
- Sunrise reveal stages: ripple rings.
- Camera live preview: no overlay animations at all (let the moment breathe).

### The shutter ritual (sacred)
1. Heavy haptic (`UIImpactFeedbackGenerator(style: .heavy)`)
2. 90ms white flash overlay
3. 500ms black-out (the frame is gone forever)
4. Return to live preview
5. Toast confirmation, never a popup

---

## 7. Iconography

- **SF Symbols only**. No Lucide, FontAwesome, Phosphor stand-ins.
- Stroke weight: prefer `.regular` or `.medium`. Never `.bold` for icons.
- Use semantic SF Symbol names that match intent:
  - `film.stack.fill` for Rolls tab
  - `camera.fill` for Camera tab
  - `person.crop.circle.fill` for Profile
  - `sunrise.fill` for reveal moments
  - `qrcode.viewfinder` for QR / join
  - `bubble.left.fill` for comments
  - `heart` / `heart.fill` for likes
  - `arrow.up.right` for outbound references
- Avoid cliché icons: `rocket` for launch, `shield` for security, `bell.badge` for new — these are AI tells.

---

## 8. Voice & Copy

- **Sentence case** for most copy. Reserve UPPERCASE for Bebas Neue editorial labels.
- **Italic** for emotional copy ("reveals at sunrise · in 2 days").
- **No exclamation points** in confirmations ("album created", not "album created!").
- **No "Oops"**, "Whoops", or apology language. Be direct: "couldn't post".
- **No filler text**: "Scroll to explore", "Swipe up", "Tap to continue" — banned.
- **No AI copywriting clichés**: "Elevate", "Seamless", "Unleash", "Next-gen",
  "Game-changer", "Delve", "Tapestry", "In the world of...". Plain & specific only.
- **Real names** in sample data: Maddie Frost, Tyler Vance, Sam Kim. Never "John Doe".
- **Organic numbers**: `12` likes, `47.2%`, `+1 (312) 847-1928`. Never `99.99%` or `50%`.

### Tone examples

| Bad                                | Good                                       |
|------------------------------------|--------------------------------------------|
| "Oops! Something went wrong"       | "couldn't post — try again"                |
| "Welcome to Afterimage!"           | "shoot blind. develop together."           |
| "Tap to view your latest album"    | "12 memories · 2 still developing"         |
| "Reveal your moments instantly"    | "reveals at sunrise · in 2 days"           |
| "Friends list"                     | "your friends" / "people in this roll"     |

---

## 9. The "Absolute Zero" Directive (instant fail)

If a generated screen contains any of the following, the design fails review.

- Pure `#000000` background or pure `#ffffff` text
- The Inter font, or any other banned font
- A `Color.blue` / `Color.purple` / iOS-system color anywhere visible
- An `.easeInOut` or `.linear` animation outside the flash ritual
- A 3-equal-card horizontal row layout
- Generic AI copy clichés (see Section 8)
- A pure-black drop shadow (must be warm-tinted via `warmShadow()`)
- Any per-tile photo rotation (we abandoned this — it reads as messy)
- An emoji used in place of an icon in a button or label
- A "loading…" generic spinner (must be a layout-matching skeleton)
- A button with no `pressEffect()` or other tactile feedback
- A card outside the `4/8/12/16/24` spacing scale
- A title using Title Case (must be UPPERCASE Bebas Neue or sentence-case italic)

---

## 10. Source-of-Truth References

- `Theme/Palette.swift` — color tokens
- `Theme/Motion.swift` — animation curves
- `Components/ViewModifiers.swift` — `.pressEffect()`, `.warmShadow()`, `.doubleBezel()`
- `Components/MentionText.swift` — `@username` styling
- `Screens/HomeView.swift::RevealedRollCard` — canonical revealed-roll layout
- `Screens/HomeView.swift::DevelopingFilmStripCard` — canonical developing layout
- `Screens/SunriseRevealView.swift` — the reveal moment, never alter without explicit review
- `Sample/SampleData.swift` — canonical voice + naming conventions in copy
