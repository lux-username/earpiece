# Earpiece

A push-to-talk AI assistant for a Bluetooth earpiece, built for iOS. Tap the earbud, ask a question out loud, hear a spoken answer — no screen, no wake word, and the microphone stays off until you deliberately ask.

This repo is a **documented investigation** as much as an app: I set out to build a private AI-in-your-ear assistant, took it to working hardware, and discovered through building and research *why* the idea belongs on a different platform than iOS. The build log is the heart of it.

## Read these first

- **[PROJECT-SUMMARY.md](PROJECT-SUMMARY.md)** — one-page overview: the idea, what I built, and the honest conclusion.
- **[BUILDLOG.md](BUILDLOG.md)** — the full journal: 13 entries of what was tried, what broke, what I'd do differently, and the platform finding that ended it. This is the real deliverable.

## What it does

The working loop, tested on real hardware (Sony LinkBuds Open):

> earpiece tap → record → speech-to-text → reasoning with live web search → text-to-speech → spoken answer

Built in Swift / SwiftUI, talking to OpenAI's API behind a thin provider seam (`AssistantProvider`) so the backend is swappable. Notable bits: a self-healing silent-audio "keep-alive" to catch earpiece taps iOS won't hand over directly; silence-based end-of-recording; streamed answer playback; and a privacy gate that engages the mic *only* on a deliberate tap.

## What I learned (the short version)

1. **A model API is not an assistant** — memory, connectors, and retrieval are the product layer on top, and the gap is the whole game.
2. **The platform owns the hardware.** Every wall this project hit — catching the tap, recording while locked, reaching a real voice assistant — is the same wall: Apple won't grant a third-party app the earpiece + mic + lock-screen access the idea needs. The same capability ships openly on Android.
3. **Know when to stop.** As a product this is a worse Siri, and I reasoned my way there from a working prototype before sinking months into it. The conclusion isn't "build more" — it's that the goal lives one platform over.

## Build it yourself

1. Open `earpiece.xcodeproj` in Xcode (iOS 26+, tested on iPhone + Sony LinkBuds Open).
2. Copy `earpiece/Secrets.example.swift` to `earpiece/Secrets.swift` and paste your own OpenAI API key. `Secrets.swift` is git-ignored — your key never leaves your machine.
3. Build and run on a device (the earpiece-tap flow needs real Bluetooth hardware; the on-screen "Testing mode" toggle drives the loop without it).

## Status

Complete as an iOS investigation. The honest next step toward actually *using* it is a 20-minute test on an Android phone (where ChatGPT can be the default assistant, launched from the earbud) — not more iOS code. See the final BUILDLOG entry.
