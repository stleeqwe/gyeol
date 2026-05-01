> Translated from Korean (see *.ko.md backup). Source: ordiq Stage 3 output.

# Gyeol — Design System

> ordiq Stage 3 output. Tokens extracted from 17 screenshots + aligned with `결_화면설계_v2.md` §15 visual tokens.

**Domain Design Profile: Consumer (intimate / serious)**

This is neither a SaaS product nor a portfolio app. While a serious marriage/long-term relationship user in the Korean market spends 30 minutes to an hour writing difficult answers, the app should feel like a *calm, substantial companion*. Casual dating app tones (bright gradients, chips, rich illustration) conflict with this app's identity.

## 1. First Impression (Phase 1 anchor)

First impression across 17 screenshots:
- **Weight**. Beige background + black primary + serif Korean headline = "long-standing trustworthiness."
- **Whitespace**. Little information per screen. Only one question shown at a time.
- **Serif-style headline + sans-serif body**. The single character "결" feels like a seal.
- **Formal register + short sentences**. *"답변이 끝났습니다" (Your answer is complete), "결을 통해 연결되었습니다" (You've been connected through Gyeol)*.

This impression is the Critic comparison anchor — to prevent designs from drifting toward *liveliness / vibrancy / colorfulness*.

## 2. 3-Layer Synthesis

| Layer | Decision |
|-------|----------|
| Table Stakes | iOS HIG compliance (safe area, dynamic type, dark mode), Apple Sign In black button recommended form, FaceID option, VoiceOver |
| Trending | Influence from minimal Korean tech apps (Toss, Karrot in part). However, *bright color card gradients* are rejected — conflict with app tone |
| First Principles | "Hard questions + an escape hatch" identity. Calm tone. User answers = protagonist. UI is background. |

## 3. Color Palette

### 3.1 Light

| Token | Hex | Role |
|-------|-----|------|
| `bg.primary` | `#F0EAE0` | App background (beige) |
| `bg.elevated` | `#FFFFFF` | Cards / modals |
| `bg.subtle` | `#E8E2D7` | Input area disabled / mic inactive |
| `text.primary` | `#1A1A1A` | Body, headlines |
| `text.secondary` | `#6B6760` | Supporting text, placeholder |
| `text.tertiary` | `#9C9890` | Meta (1/6 counter) |
| `text.disabled` | `#C5C0B5` | Inactive text |
| `accent.primary` | `#1A1A1A` | CTA black |
| `accent.contrast` | `#FFFFFF` | Text on CTA |
| `divider` | `#D8D2C5` | Dividers |
| `border.subtle` | `#D8D2C5` | Card border |
| `feedback.recording` | `#C44545` | Red dot (recording) |
| `state.alignment` | `#1A1A1A` | "alignment" dot |
| `state.compromise` | `#6B6760` | "compromise" dot |
| `state.boundary` | `#A05A2C` | "boundary check" dot |

### 3.2 Dark

| Token | Hex | Role |
|-------|-----|------|
| `bg.primary` | `#1A1A1A` | App background |
| `bg.elevated` | `#262626` | Cards / modals |
| `bg.subtle` | `#2F2F2F` | Input inactive |
| `text.primary` | `#F0EAE0` | Body |
| `text.secondary` | `#A8A39A` | Supporting |
| `text.tertiary` | `#7A766F` | Meta |
| `text.disabled` | `#5A5650` | Inactive |
| `accent.primary` | `#F0EAE0` | CTA beige (inverted) |
| `accent.contrast` | `#1A1A1A` | Text on CTA |
| `divider` | `#3A3A3A` | Dividers |
| `border.subtle` | `#3A3A3A` | Card border |
| `feedback.recording` | `#E06060` | Red dot |

## 4. Typography

### 4.1 Font Families

- **Headline / seal**: Apple SD Gothic Neo Heavy (Korean) — system Korean serif tone. *Serif* impression is consistent with app identity.
- **Body / UI**: SF Pro Text (Latin) + Apple SD Gothic Neo Regular/Medium/SemiBold (Korean)
- **Numbers / timestamps**: SF Mono — for recording timer display, etc.

### 4.2 Type Scale

| Token | Size / LineHeight / Weight | Usage |
|-------|---------------------------|-------|
| `display.brand` | 80 / 96 / Heavy | "결" seal |
| `display.subBrand` | 11 / 14 / Medium / 0.3em letter-spacing | "GYEOL" sub-label |
| `headline.lg` | 22 / 32 / SemiBold | Domain question head ("당신은 죽음 이후에…" — Do you believe something exists after death…) |
| `headline.md` | 18 / 26 / SemiBold | Card main headline |
| `headline.sm` | 16 / 24 / SemiBold | Modal title |
| `body.lg` | 15 / 24 / Regular | Body text (multi-line) |
| `body.md` | 14 / 22 / Regular | Card body |
| `body.sm` | 13.5 / 21 / Regular | Supporting text |
| `label.md` | 13 / 18 / Medium | Domain labels, status |
| `caption` | 11 / 14 / Medium | 1/6 counter, meta |
| `cta` | 16 / 22 / SemiBold | CTA button |

### 4.3 Korean Line-Break Principles

- Break at *semantic units*. e.g. *"당신은 죽음 이후에 무언가가 있다 / 고 생각하시나요?"* (Do you believe / something exists after death?)
- Avoid awkward token splits: *"하시나 / 요?"* (Do / you?) is prohibited.
- iOS UILabel `lineBreakStrategy = .hangulWordPriority` enabled

## 5. Spacing Scale (8pt base)

| Token | Value | Usage |
|-------|-------|-------|
| `space.xxs` | 4 | Adjacent text |
| `space.xs` | 8 | Label ↔ body |
| `space.sm` | 12 | Head ↔ body |
| `space.md` | 16 | Body paragraphs / card padding |
| `space.lg` | 24 | Modal padding / screen horizontal margin |
| `space.xl` | 32 | Between sections |
| `space.xxl` | 48 | Top of screen spacing |
| `space.section` | 64 | Large section separation (above seal) |

## 6. Radius / Shadow / Border

| Token | Value | Usage |
|-------|-------|-------|
| `radius.sm` | 8 | Mic button / input chip |
| `radius.md` | 12 | Recording banner / input area |
| `radius.lg` | 18 | Modal |
| `radius.xl` | 24 | Card |
| `radius.cta` | 12 | Primary CTA button |
| `border.width.thin` | 1 | Divider, card border |
| `shadow.subtle` | `0 1 4 rgba(0,0,0,0.04)` | Card |
| `shadow.elevated` | `0 4 16 rgba(0,0,0,0.08)` | Modal (light) |

Dark mode: `shadow.subtle/elevated` not used. Use explicit `border.subtle` instead.

## 7. Motion

| Token | Curve / Duration |
|-------|-----------------|
| `motion.swift` | easeInOut / 200ms — button state |
| `motion.standard` | easeInOut / 300ms — modal appear |
| `motion.calm` | easeInOut / 450ms — card expansion |
| `motion.pulse` | easeInOut / 1600ms infinite — mic active |
| `motion.recording-dot` | easeInOut / 1200ms infinite — recording red dot |
| `motion.waveform` | easeInOut / 1200ms infinite, stagger 0–300ms — voice amplitude |

Principle: *smooth but not long*. This app values *calm dwell* over *fast reaction*. That said, excessively long animations feel heavy.

## 8. Components

### 8.1 PrimaryButton (CTA)

- Background: `accent.primary`
- Text: `accent.contrast`, `cta` token
- Height: 56pt
- Radius: `radius.cta`
- Horizontal padding: `space.lg`
- Pressed: opacity 0.85
- Disabled: bg `text.disabled`, same glyph

### 8.2 SecondaryButton (Text Link)

- Background: transparent
- Text: `text.secondary`, `body.md / Medium`
- Pressed: opacity 0.6
- Usage: "Explain more simply", "Skip this domain", "Take a break"

### 8.3 MicButton

| State | Background | Icon | Animation |
|-------|-----------|------|-----------|
| Inactive | `bg.subtle` | `text.secondary` mic | — |
| Active (recording) | `accent.primary` | `accent.contrast` mic | pulse 1.6s |
| Permission denied | `bg.subtle` | `text.disabled` mic-slash | — (tap shows settings guidance) |

Size 40×40, radius 50% (circle).

### 8.4 RecordingBanner

- Left red dot 8×8 + pulse 1.2s
- Label "듣고 있습니다" (Listening) `body.sm`
- Right timestamp `SF Mono 13`
- Background `bg.subtle`, radius 12, padding (10, 16)

### 8.5 Waveform

- 25 bars, width 2.5, gap 3
- Color `accent.primary` opacity 0.7
- Animation `motion.waveform`, stagger
- Silent state: paused + bars 1.5px uniform (idle baseline)

### 8.6 ProgressBar (Interview 1/6)

- Height 2pt
- bg `divider`, fill `text.primary`
- Fills left→right. Duration `motion.standard`

### 8.7 ChoiceChip (skip reason)

- Radio style. Background transparent, border 1pt `divider`
- Selected: border `text.primary`, left `●`

### 8.8 MatchCard

- Background `bg.elevated`
- Radius `radius.xl`
- Padding `space.lg`
- Top-left small dot + label (state.alignment / compromise / boundary color)
- Head `headline.md`
- Body `body.md`
- Divider followed by *unified core identity*

### 8.9 ChatBubble

- Own message: bg `accent.primary`, text `accent.contrast`, right-aligned
- Partner message: bg `bg.subtle`, text `text.primary`, left-aligned
- Radius 18 (both top corners; same-sender side is 4)
- System message ("결을 통해 연결되었습니다" — You've been connected through Gyeol): centered, `text.secondary`, `body.sm`

### 8.10 Modal

- Width 320 (24pt horizontal margin)
- bg `bg.elevated`
- Radius `radius.lg`
- Padding 24
- Title `headline.sm`
- Body `body.sm`, line-height 1.55, `text.secondary`
- Action row — left (cancel `text.secondary`), right (primary action `accent.primary`)
- 1pt divider between the two actions

## 9. 13-Screen Mapping

| # | Label | `결_화면설계_v2.md` § | Key Components |
|---|-------|----------------------|----------------|
| 1 | Onboarding gate | §2 | display.brand "결", body.lg, PrimaryButton |
| 2 | Apple Sign In | §3 | Apple Sign In standard button, body.sm |
| 3 | Domain interview (open question) | §4 | ProgressBar, label, headline.lg, SecondaryButton (avoidance) |
| 4 | Answer input — keyboard | §5 | Header question paraphrase, MicButton, multi-line text, helper, PrimaryButton |
| 4·A | Voice input permission | §5 | iOS system modal |
| 4·B | Voice input recording | §5 | MicButton active, RecordingBanner, Waveform, "Stop recording" |
| 4·C | Voice input done, edit | §5 | MicButton inactive, helper "음성으로 받은 텍스트입니다…" (This text was received via voice), PrimaryButton |
| 5 | Follow-up question generating | §6 | "당신의 답을 읽고 있습니다" (Reading your answer), dot loader |
| 6 | Follow-up question (conversational) | §7 | Previous answer prefix, Gyeol follow-up question, answer input + MicButton |
| 7 | Domain end | §8 | "답변이 끝났습니다" (Your answer is complete), next domain hint, PrimaryButton + secondary |
| 9 | Explicit dealbreaker input | §10 | Per domain. Free text + expandable examples. Can leave selection empty. |
| 10 | Self review (before publishing) | §11 | 6 domain Gyeol cards + unified core identity + dealbreakers. PrimaryButton "발행하기" (Publish) |
| 11 | Match candidate list | §12 | MatchCard scroll |
| 12 | Candidate card expanded | §13 | Card headline, alignment areas, areas of difference, per-domain labels, [Interested] |
| 13 | Chat room | §14 | ChatBubble, input bar |

## 10. Active Verification (Phase 3 plan)

iOS Simulator (iPhone 15) light/dark mode, all 13 screens:
- VoiceOver Korean speech verification
- Dynamic Type Large support (no text clipping)
- iPhone SE (3rd gen) narrow screen fit

## 11. DAI Self-Score

| Dimension | Score | Rationale |
|-----------|-------|-----------|
| Cohesion (0.30) | 9 | Consistent across 17 screenshots. Beige + black + serif Korean all aligned. |
| Originality (0.25) | 8 | Weightier than Korean tech apps; serif headline distinct from other matching apps; single character "결" seal |
| Craft (0.25) | 7 | Korean-first line breaks + 4-step voice detail + dual-mode tokens (Dark/Light) |
| Intuitiveness (0.20) | 8 | One screen, one question / primary CTA clear / avoidance options clearly secondary |

**DAI = (9×0.30)+(8×0.25)+(7×0.25)+(8×0.20) = 2.70+2.00+1.75+1.60 = 8.05 → PASS (≥7).**

Hard-fail gate — Cohesion ≥5, Craft ≥5 required.
