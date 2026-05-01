> English translation of 결_핵심질문체계_설계문서_v7.md. Korean original is the authoritative source — this version is a faithful translation for non-Korean-speaking maintainers.

# Gyeol — Core Question Framework Design Document (v7)

> This document is v7, adding (1) pre-disclosure of what is shown to match partners for skip and private domains, and (2) a voice input option. The document structure and questions for the 6 domains are unchanged from v6.

> Areas changed in v6 → v7: §11 avoidance options updated, §11.5 voice input option (new), §13 sensitive data handling updated with voice data. The remaining §1–§10, §12, and §14 are unchanged from v6 — *refer to the v6 standalone document*. A full v7 re-incorporation is planned for the next cycle.

> **Key changes v6 → v7**: see §15.

---

## §11. Avoidance Options (updated in v7)

Gyeol is an app that *faces difficult questions while also leaving room to step back*. Users are not forced to engage with domains they cannot answer.

### §11.1 "Explain more simply" (same as v6)

If a question is abstract or difficult, *reduce the depth level*. Ask the same core question in more everyday language.

Up to 3 levels. Beyond that, guide the user toward the avoidance options in §11.3.

### §11.2 Depth Metadata (same as v6)

A person who answered a simplified question and a person who answered the original question are not at the same depth level. `depth_level: 1/2/3` metadata is attached, and depth differences are adjusted during matching.

### §11.3 Three Avoidance Options (updated in v7 — pre-disclosure included)

**(1) "Explain more simply"** — reduces depth level

**(2) "Skip this domain"** — skips the entire domain.

Reason selection (pre-defined enum):
- Don't want to share
- Not yet settled on this
- Judged it as unimportant
- Other

**Pre-disclosure added in v7**: the following notice is shown in the reason selection modal:

> The selected reason will be visible to your match partner.  
> Example: *"This domain was not answered — reason: don't want to share"*

This pre-disclosure ensures users understand that *the skip reason itself is a signal* before making their selection.

Free-text input is not accepted. Selecting *Other* does not expose any additional information.

**(3) "Answer, but keep this domain's analysis private"** — the user answers, the analysis is stored for personal self-understanding only, and it is not entered into the matching pool.

**Pre-disclosure added in v7**: the following notice is shown when selecting private storage:

> The analysis content for this domain will not be shared with match partners.  
> However, candidates you are shown will see the status: *"This domain is kept private."*  
> This domain will not count as published for matching pool eligibility.

**Rationale**: if users do not understand the distinction between *the analysis content* and *the fact of keeping it private*, trust can break down. When choosing private, users must be clearly informed that *the fact of it being private is shown to the other party*.

### §11.4 Avoidance Options Pre-Disclosure Mechanism (new in v7)

All three options *explicitly state the consequences at the moment of selection*. Users should not discover unexpected exposure after making a choice.

**Implementation**:
- Avoidance option modal default: option + one-line summary of what will happen
- Expanded via *View details*: full impact (matching pool eligibility, partner visibility, self-review domain) explained
- Auto-expands only on the *first selection*. Defaults to collapsed on repeat selections

**Example — private storage modal (v7)**:

```
[Modal]

The answer for this domain will be stored privately.

What this means:
· The analysis content will not be shared with match partners.
· Candidates you are shown will see only the status: "This domain is kept private."
· This domain will not count as published for matching pool eligibility.
· The more domains you keep private, the fewer matches you may receive.

[Cancel]      [Keep private]
```

### §11.5 Voice Input Option (new in v7)

Given the nature of Gyeol's answers — *long answers, thinking out loud slowly* — it is common. A voice input option is provided in addition to keyboard input.

#### §11.5.1 Voice Input SDK Decision

**Apple Speech Framework (SFSpeechRecognizer) as primary + iOS system dictation natural support**.

Rationale:
- Standard SDK since iOS 10+, supports Korean (ko-KR), free.
- On-device mode (iOS 13+, A9 chip or later): no network required, data residency requirements met.
- External STT APIs (Google Cloud, Whisper) rejected — cost + burden of sending sensitive data externally.

#### §11.5.2 Interaction Pattern

**Default**: keyboard input  
**Voice option**: microphone icon (SF Symbol mic) in the upper right of the input area

**Voice input flow**:
1. Tap microphone icon → permission request modal (first time only)
2. Permission granted → recording begins
   - Microphone icon in active state (pulse animation)
   - *Listening* banner + recording timer + red dot animation
   - Voice amplitude visualization (waveform) at bottom of screen
   - Real-time text transcription (text appears as the user speaks)
3. Recording ends (user taps *Stop recording* button, or 60-second silence auto-stop)
4. Transcribed text is inserted into the input area
5. User can freely edit with keyboard

#### §11.5.3 1-Minute Limit Bypass

Apple Speech Framework has a 1-minute limit per session.

**Bypass mechanism**:
- *Auto-restarts the session* as the 1-minute mark approaches + accumulated text is preserved
- Appears as *continuous recording* to the user
- Or the user pauses → taps the microphone again to restart (natural feel)

#### §11.5.4 Voice Data Policy

- On-device mode used → no voice data sent externally
- Only the transcribed text is sent to the Gyeol backend (Supabase)
- Privacy policy explicitly states: *voice processing happens on-device and the raw voice audio is never sent externally*

#### §11.5.5 Permission Handling

- iOS permissions: `NSSpeechRecognitionUsageDescription` and `NSMicrophoneUsageDescription` required in Info.plist
- On permission denial: microphone icon disabled; keyboard input only
- Do not force re-request from users who denied permission (their choice)

---

## §12. Onboarding Gate (same as v6)

Same as v6 §12.

---

## §13. Privacy and Sensitive Data Handling (updated in v7)

Given the nature of data collected by Gyeol, PIPA Article 23 (sensitive data handling principles) applies directly.

**(1) Separate consent** — sensitive data consent separate from general membership signup consent (same as v6).

**(2) Minimal collection / purpose limitation** — prohibited from use for any purpose other than matching (same as v6).

**(3) Encryption** — raw answers, analysis text, core_identity, and explicit_dealbreakers all encrypted in storage and in transit (same as v6).

**(4) Right to deletion** — users may delete per-domain or all data at any time (same as v6).

**(5) Notice of no AI training use** — Gyeol's answer data is not used as training data for external AI systems (same as v6).

**(6) Private option** — the third avoidance option in §11.3 is a natural extension of sensitive data protection principles.

**(7) Voice data processing (new in v7)** — Apple Speech Framework on-device mode used. Voice is transcribed directly to text on the user's device without being sent to external servers. Only the transcribed text is sent to the Gyeol backend. Must be stated explicitly in the consent form.

**(8) Raw quote isolation (new in v7)** — direct quotes from user answers are isolated in the *answer_evidence* area. Raw quotes are not included in the *summary* exposed to match partners (see AI Prompts v7 §1.3, §2.1).

---

## §14. v6 → v7 Changes

### §14.1 Avoidance Options Pre-Disclosure (§11.3, §11.4)

v6: the *consequences* of skip/private selection were not stated  
v7: modals explicitly state *the impact on partner visibility*. Users will not discover unexpected exposure.

### §14.2 Voice Input Option Added (§11.5)

Apple Speech Framework based. On-device mode + 1-minute limit bypass + free keyboard editing.

### §14.3 Voice Data Processing Explicitly Stated (§13)

PIPA consent form explicitly states: *voice data processed on-device + no external transmission*.

### §14.4 Raw Quote Isolation Explicitly Stated (§13)

Aligned with AI Prompts v7. summary is public_safe; raw quotes are isolated in answer_evidence.

### §14.5 Unchanged Areas

- §1 app identity
- §2–§9 core questions for the 6 domains (open questions, lens tools, follow-up question mechanisms for each domain)
- §10 explicit dealbreaker input (new section from v6, unchanged)
- §12 onboarding gate
- Analysis tone principles
- General output data visibility scope

A standalone integrated v7 document will be written in the next cycle. This cycle operates on *v6 + these v7 changes*.
