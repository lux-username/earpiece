# Earpiece — a voice AI assistant, and knowing when to stop

**What it is:** A push-to-talk AI assistant for a Bluetooth earpiece. Tap the earbud, ask a question out loud, hear a spoken answer — no screen, no wake word, and the microphone stays off until you deliberately ask.

## The idea

I wanted the assistant I actually use — one that can reason and search the live web — available the instant I needed it, in my ear, summoned by a discreet tap rather than a phone in my hand or a voice assistant announcing itself across a dinner table. Privacy was the point: the mic is off by default and engages only on a deliberate tap, made visible by iOS's own orange recording dot.

## What I built

A working iOS app, tested on real hardware (Sony LinkBuds Open), running the full loop:

> earpiece tap → record → speech-to-text → reasoning with live web search → text-to-speech → spoken answer

Along the way I:

- **Reverse-engineered how iOS routes earpiece button presses** — it doesn't, officially, so the app claims the system "Now Playing" role with a loop of silent audio and defends it against every other app that tries to steal it.
- **Handled the real-world failure modes** — incoming calls, Bluetooth re-routing, and the screen locking, each of which quietly broke the trigger until handled.
- **Treated latency as an engineering problem** — measured it as a three-stage pipeline rather than guessing, then cut the felt delay by streaming the spoken answer as it was generated instead of waiting for the whole audio clip.
- **Enforced behavior the AI wouldn't reliably follow on its own** — e.g. never reading web URLs aloud — in code, rather than by asking the model nicely.

I kept a detailed build log throughout: every dead end, every honest workaround, every "what I'd do differently."

## The turn

Partway through, I hit the more valuable realization: as a *product*, this shouldn't exist. "General-purpose AI in your ear" is a feature that Apple, Google, and OpenAI will each fold into hardware people already own — faster, cheaper, eventually free. Long-press Siri already does the job. The dedicated AI gadgets that tried this (Humane, Rabbit) raised hundreds of millions and failed for exactly that reason: you can't out-feature the platform that owns the device.

I reasoned my way there from a working prototype — in a couple of weeks, for the cost of an API bill — before pouring real time or money into a dead end.

## What it actually demonstrates

Two things, and the second matters more than the first:

1. **I can take a vague "wouldn't it be cool if…" to a working, hardware-tested system** — and understand each layer I touch: the model API, the audio stack, the network pipeline, and the platform's hard limits.
2. **I can tell a dead product from a live one, with evidence, and stop.** Killing your own idea on time is the rarest and most expensive-to-lack skill in product work.

## Where it's going

Not the trash — and the final twist is the most useful part. After building the prototype, I ran a structured research pass on a sharper question: could I keep the discreet earpiece interaction but point it at the *real* ChatGPT — memory, connectors, the assistant I already use — instead of maintaining my own? The answer: **not on iOS, and every wall this project hit turned out to be the same one** — Apple won't grant a third-party app the earpiece, microphone, and lock-screen access the idea needs. But the thing iOS forbids ships openly on Android, where ChatGPT can be the default assistant, launched from the earbud, with no always-listening hotword (which is exactly the privacy gate I wanted).

So the conclusion isn't "build more." It's that the goal lives one platform over, and the honest next step is a 20-minute test on an Android phone — not another line of iOS code.

The prototype was never the destination. It was how I learned what was worth building — and, in the end, that the real blocker was a platform choice, not the code.
