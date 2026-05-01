> English translation of 결_화면설계서_v2.md. Korean original is the authoritative source — this version is a faithful translation for non-Korean-speaking maintainers.

# Gyeol — Screen Design Document (v2)

> This document is v2, incorporating (1) the voice input option and (2) strengthened pre-disclosure for skip and private domains. The 13 screens from v1 are preserved as-is; only the changed areas are specified in this v2.

> Areas changed v1 → v2: §5 Screen 4 (answer input) — voice input split into 4 sub-screens, §7 Screen 6 (follow-up questions) — microphone button added, §10 Screen 9 (explicit dealbreaker input) — no changes (already specified in v1), §4 avoidance options modal — pre-disclosure strengthened. All other screens are unchanged from v1.

> A standalone v2 integrated document will be written in the next cycle. This cycle operates on *v1 + these v2 changes*.

> **Key changes v1 → v2**: see §3.

---

## 1. Change Area 1 — Screen 4 Answer Input (Voice Input 4 Sub-Screens)

The single Screen 4 from v1 §5 is expanded into *4 sub-screen stages for the voice input interaction flow*.

### 1.1 Screen 4 (Default — Keyboard Input)

v1 Screen 4 body + the following addition:
- *Microphone icon* in the upper right of the input area (SF Symbol mic, inactive icon on a subtle background)
- Tapping the microphone switches to Screen 4·A or 4·B

### 1.2 Screen 4·A — Voice Input Permission Request (new in v2)

**Purpose**: shows the iOS system permission modal on first microphone tap.

**Components**:
- Modal title: *"'Gyeol' Would Like to Access Speech Recognition"*
- Modal body: *"Please allow microphone and speech recognition access so you can enter answers by voice. Voice is processed entirely on-device and is not transmitted externally."*
- Actions: *Don't Allow* / *Allow*

**Rationale**: separate from PIPA Article 23 sensitive data consent, microphone and speech recognition are iOS system permissions. Stating *on-device processing* explicitly builds trust.

### 1.3 Screen 4·B — Voice Input Recording in Progress (new in v2)

**Purpose**: the user is answering by voice. Provides sufficient visual feedback.

**Components**:
- Microphone icon in *active state*: accent color fill + pulse animation (1.6-second cycle)
- *Listening* banner: red dot pulse animation + text + recording timer (e.g., 00:23)
- Input area: real-time transcribed text + blinking cursor
- Screen bottom: voice amplitude visualization (waveform, 25 bars)
- *Submit answer* button changes to *Stop recording* button (square stop icon)

**1-minute limit bypass**:
- Auto-restarts the session as the 1-minute mark approaches
- Appears as *continuous recording* to the user
- Waveform and timer display cumulative time

**60-second silence auto-stop**:
- Auto-stops after 60 seconds of silence
- Toast on stop: *"Stopped due to 60 seconds of silence."*

### 1.4 Screen 4·C — Voice Input Ended, Editable (new in v2)

**Purpose**: user reviews and edits the voice transcription result.

**Components**:
- Microphone icon returns to inactive state
- Transcribed text inserted into the input area as-is
- Keyboard can be shown (on user tap)
- Helper text: *"This is the text received by voice. Feel free to edit as needed."*

**Free combination supported**:
- Voice → keyboard edit → add more voice input — all possible
- Text is accumulated

### 1.5 Screen 4 Design Tokens

Microphone button:
- Size: 40×40
- Background (inactive): `bg.subtle`
- Background (active): `accent.primary`
- Icon color (inactive): `text.secondary`
- Icon color (active): `bg.primary`
- Pulse animation: 1.6 s ease-in-out infinite

Recording banner:
- Red dot: `#C44545`, 8×8, pulse 1.2 s
- Background: `bg.subtle`
- Radius: 12 pt

Waveform:
- 25 bars, width 2.5 px, gap 3 px
- Color: `accent.primary`, opacity 0.7
- Animation: 1.2 s ease-in-out infinite, per-bar delay 0.0–0.3 s

---

## 2. Change Area 2 — Screen 6 Follow-Up Questions (Microphone Button Added)

Microphone button added to Screen 6 from v1 §7.

**Components**:
- Microphone icon in the upper right of the answer input area (same pattern as Screen 4)
- Tapping the microphone transitions to the same recording-in-progress state as Screen 4·B
- Interaction flow is identical to Screens 4·A, 4·B, and 4·C

---

## 3. Change Area 3 — Avoidance Options Modal (Pre-Disclosure Strengthened)

Pre-disclosure strengthened for the *skip reason selection modal* in v1 §4.5 and the *restart auxiliary menu* in v1 §11.6.

### 3.1 Skip Reason Selection Modal (strengthened in v2)

Same as v1 + the following explicitly added:

```
[Skip modal — v2]

Please select the reason for skipping this domain.

◯ Don't want to share
◯ Not yet settled on this
◯ Judged it as unimportant
◯ Other

──────

The selected reason will be visible to your match partner.
Example: "This domain was not answered — reason: don't want to share"

[Cancel]      [Confirm]
```

**Difference from v1**: exposure impact is stated *with an example*. Users understand *how they will appear to others* before making their selection.

### 3.2 Private Storage Modal (new in v2)

In v1, the *restart auxiliary menu* had a *keep this domain private* option, but lacked pre-disclosure. v2 introduces a dedicated modal:

```
[Private storage modal — new in v2]

The answer for this domain will be stored privately.

What this means:
· The analysis content will not be shared with match partners.
· Candidates you are shown will see only the status: "This domain is kept private."
· This domain will not count as published for matching pool eligibility.
· The more domains you keep private, the fewer matches you may receive.

[Cancel]      [Keep private]
```

**Rationale**: implements the pre-disclosure requirement from Core Question Framework v7 §11.3 in the UI.

### 3.3 Modal Design Tokens

- Background: `bg.elevated`
- Modal width: 320 pt (24 pt horizontal margin)
- Radius: 18 pt
- Padding: 24 pt
- Title: SemiBold 16 pt, `text.primary`
- Body: Regular 13.5 pt, `text.secondary`, line-height 1.55
- Action buttons:
  - Left (Cancel): `text.secondary`, Medium 15 pt
  - Right (Confirm / Keep private): `accent.primary`, SemiBold 15 pt
  - Divider: `divider` 1 pt

---

## 4. Change Area 4 — Candidate Card Expanded Screen (No Changes, Annotation Only)

The handling of *private domains* and *skipped domains* on the candidate card expanded screen in v1 §13 (Screen 12) was already defined in v1. No changes in v2. The following alignment notes are included:

**Private domain display**:
> *"This domain is kept private."*
>
> (User pre-disclosure: this display is the result of the notification in §3.2 private storage modal)

**Skipped domain display**:
> *"This domain was not answered — reason: {skip_reason}"*
>
> (User pre-disclosure: this display is the result of the notification in §3.1 skip modal)

Users can preview the same display on the self review screen (Screen 10) before publishing. This allows them to see how they will appear to match partners before going live.

---

## 5. Summary of v1 → v2 Changes

### 5.1 Screen 4 Voice Input Split into 4 Sub-Screens

v1: single answer input screen  
v2: 4 stages — keyboard / permission request / recording in progress / voice-ended editing

### 5.2 Screen 6 Microphone Button Added

Same voice input interaction available in follow-up questions.

### 5.3 Avoidance Options Modal Pre-Disclosure Strengthened

- Skip reason selection modal: exposure example explicitly stated
- Private storage modal (new): 4 impacts explicitly stated

### 5.4 Unchanged Areas

- §1 overall flow map
- §2 Screen 1 onboarding gate
- §3 Screen 2 Apple Sign In
- §4 Screen 3 domain interview open question (except avoidance option modal §3 changes)
- §6 Screen 5 follow-up question generating
- §8–§9 Screens 7–8
- §10 Screen 9 explicit dealbreaker input
- §11 Screen 10 self review
- §12 Screen 11 matching candidate list
- §13 Screen 12 candidate card expanded
- §14 Screen 13 chat room
- §15 visual tokens
- §16 priorities
- §17 review requests
- §18 next steps

### 5.5 Screen Priority Update

*4·A, 4·B, 4·C* added to P0 screens:

**P0 (required, updated in v2)**:
- Screen 1 — onboarding gate
- Screen 2 — Apple Sign In + consent
- Screen 3 — domain interview (open question)
- Screen 4 — answer input (default keyboard)
- Screen 4·A — voice input permission request (new in v2)
- Screen 4·B — voice input recording in progress (new in v2)
- Screen 4·C — voice input ended editing (new in v2)
- Screen 5 — follow-up question generating
- Screen 6 — follow-up question (with microphone button)
- Screen 9 — explicit dealbreaker input
- Screen 10 — self review
- Screen 11 — matching candidate list
- Screen 12 — candidate card expanded
- Screen 13 — chat room

**P1 (enhancement)**:
- Screen 7 — domain closing
- Screen 8 — integrated core identity type generating

A standalone v2 integrated document will be written in the next cycle. This cycle operates on *v1 + these v2 changes*.
