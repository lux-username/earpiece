# Earpiece — Build Log

Short log of what was tried, what was janky, and what I'd do differently with real hardware. Part of the portfolio deliverable.

Working title: **Earpiece** *(namespace-checked 2026-05-22 — no App Store collision)*

---

## Entry 1 — 2026-05-22 — The pattern pivot

### The pivot

I started designing this as press-and-hold: squeeze the earpiece, talk while held, release to send. That's the obvious gesture for a privacy-gated mic — it makes the recording window physically visible to the user, the way a walkie-talkie does.

Then iOS told me no.

iOS doesn't expose raw Bluetooth HID button events to third-party apps. The only way to catch a press-and-hold from a consumer earpiece is via Siri — long-press is firmware-locked across nearly every model to summon the OS voice assistant. So the press-and-hold path collapses into: long-press → Siri chime → Siri hands off to an App Intent my app exposes → app starts recording. Siri sits in the middle of the moment that's supposed to be invisible. That defeats the entire pitch — discreet at dinner, no device announcing itself. Siri announcing itself at dinner is the exact opposite.

But iOS *does* surface a subset of Bluetooth button events as **media remote commands** to whichever app holds the active audio session — play/pause, next-track, previous-track. On most earpieces these map to single-tap, double-tap, triple-tap. A double-tap can fire my app directly with no Siri ceremony, as long as the app is holding the active audio session at that moment.

The gesture changed:

- **Was:** press-and-hold to record *(privacy-as-physical-affordance)*
- **Now:** double-tap to start a recording session *(privacy-as-deliberate-trigger)*

The privacy intent survives — one deliberate gesture, single intentional query, mic idle the rest of the time. The implementation actually gets cleaner. The Siri detour is gone.

This is the interesting moment of the project so far. The original gesture was a design statement; the new gesture is the same statement filtered through what the platform actually permits. The kind of thing that doesn't show up in the final demo but explains why the demo is shaped the way it is.

### Supporting decisions

- **Framework:** Native Swift + SwiftUI. The tap-pattern arming needs native iOS audio APIs (`AVAudioSession`, `MPRemoteCommandCenter`, silent-audio keep-alive). Cross-platform tools reach these only via Swift bridge modules — same code, more layers.
- **Distribution:** v1 on my own phone via free Apple ID sideload (re-sign every 7 days from Xcode). No Apple Developer Program yet ($99/yr). Sharing is portfolio-decorative for now; TestFlight is the bridge if v1 proves out.
- **Working title:** *Earpiece*. Namespace-checked — no App Store app currently uses the name. Generic English word, so not registrable as a strong mark, but for a portfolio piece that's fine.

### Competitive context

OpenAI is shipping a behind-the-ear AI device (codenamed *"Sweetpea"*) in late 2026 — same form factor, cloud-routed reasoning. Different name, no collision. The product category is now real, not speculative — which means the privacy-gated press-to-talk framing of this piece lands against an actual reference product, not a hypothetical one. Most entrants in this space (Sweetpea, Samsung Galaxy Buds 4 AI, Soundcore Aerofit 2, OSO, Plaud) are always-listening or wake-word-activated. The deliberate-trigger framing is the differentiator, and it's getting sharper as the category fills in.

### What's janky / what I'd do differently with real hardware

- **iOS is the wrong platform for this product idea, if I'm honest.** Android exposes Bluetooth button events more openly. On real hardware I'd ship Android-first or build a custom BLE peripheral with a known protocol so the gesture isn't subject to firmware roulette.
- **The "active audio session" requirement is a workaround, not a design.** The app has to play silent audio to stay alive and catch the tap. Works today, could break on a future iOS update.
- The double-tap path is a *design* response to a *platform* constraint — that's the portfolio-interesting moment, documented above.

### Next session

1. Xcode finishes installing.
2. Create the iOS project (SwiftUI, iOS 26 deployment target).
3. Build the audio-session arming pattern; confirm a double-tap from an earpiece reaches the app.
4. Then: vet a specific earpiece model before purchase (decision #2).

---

## Entry 2 — 2026-05-22 — Hardware: the dinner-table pivot

### What I bought

**Sony LinkBuds Open**, model WFL910B, **$87.69 total** from Amazon Renewed (90-day guarantee). Delivery Monday May 25, 2026.

### Three pivots to get there

This session was supposed to land hardware quickly. It took three iterations, each killed by something the previous round didn't model. Documenting because the iteration is the portfolio-interesting moment — it shows what happens when you try to map a clean design concept onto real consumer-hardware constraints.

**Round 1 — Shokz OpenComm2 ($160, bone-conduction with boom mic).** Specs looked perfect: excellent mic for STT in noise, single-piece bone-conduction form (matched my brief's framing), under budget. **Killed when I pictured it at the dinner table.** A boom mic that hovers near the mouth gets in the way of eating. The demo scenario is "look something up at dinner without pulling my phone out" — a device whose mic is in front of your face while you hold a fork is incompatible with that. I was optimizing on spec sheets and missed the physical envelope. The lesson: when product use is contextual, envelope-test the *physical scenario* before the technical specs. Spec sheets don't tell you about forks.

**Round 2 — Apple AirPods 4 (non-ANC, $129).** Solid on the merits: Apple's H2 chip mic processing is industry-leading for at-ear hardware, open-fit by design, bulletproof iOS integration, cheapest in the shortlist. **Killed by portfolio considerations.** AirPods are ubiquitous — they read as "AI on the earbuds you already own." Flattening for the visual signature of the portfolio piece. The lesson: for portfolio work, *the device is part of the artifact*. Optimizing for tech merit alone can flatten the work's identity.

**Round 3 — Sony LinkBuds Open (WFL910, $87.69 renewed, $180 MSRP).** Open-ring TWS with a literal hole in the middle of the speaker driver. Lands for two reasons:

1. **Visual identity.** The donut ring is unmistakable — nothing else in the consumer market looks like this. The device is now doing real work in the portfolio's signature.
2. **Ambient hearing is actually the best in the category for this use case.** Because the driver ring doesn't occupy the ear canal, conversation across a dinner table sounds the same as if your ears were empty. Other "open-fit" options (AirPods 4, Bose Ultra Open) still partially occupy the ear opening. LinkBuds Open is the most radical "open" you can buy.

### The trade-off I'm accepting

Sony's at-ear mic processing in noise is good-but-not-H2-tier. If restaurant STT struggles in v1 testing, that's a real moment to capture: *we chose distinctiveness over mic processing, here's what it cost us, here's what real custom hardware would solve.*

### The bargain

Amazon Renewed at $81 listed / $87.69 grand total. 55% off the $180 MSRP. 90-day Amazon Renewed Guarantee covers DOA. Frees ~$112 of my $200 cap for API costs and the inevitable small expenses to come. Given my hourly-wage budget reality, the renewed route was a meaningful win — and the kind of small decision worth naming in the log.

### What's janky / what I'd do differently with real hardware

- **Three pivots feels indulgent**, but each was load-bearing. With real custom hardware (a purpose-built earpiece with a beam-formed array mic *and* a distinctive form factor), the visual-vs-mic-quality trade-off would be unforced. We don't have that; we have consumer-shaped options. The trade-off is a platform-and-budget reality, worth flagging.
- **Renewed hardware in a portfolio prototype is fine; in a real product line it wouldn't be.** A shipping product needs consistent known-good supply. For a portfolio piece, the savings beat the consistency.

### Next session

1. Resume Xcode project setup (task #1, paused mid-walkthrough when hardware pivoted).
2. Build the verification app (task #2): log MPRemoteCommandCenter events to figure out which gesture (double-tap vs triple-tap) we'll bind for "start recording."
3. Test with existing BT headphones during the wait — by the time LinkBuds Open arrives Monday, audio-session arming code should already be working.
4. When the package arrives Monday: re-verify with LinkBuds Open specifically. Gesture-to-command mapping may differ slightly per device; we confirm.

---

## Entry 3 — 2026-05-24 — Architecture verified end-to-end

### The headline

The whole project rides on one assumption: that an iOS app holding an active audio session can receive a Bluetooth earpiece's button taps as media-remote commands, in place of the raw HID button events Apple doesn't expose. Today we proved it.

A ~30-line SwiftUI app — silent audio loop + `MPRemoteCommandCenter` handlers + an on-screen log — installed onto my own iPhone (iOS 26.5) and successfully received double-tap events from a pair of Earfun Air Pro 3 earbuds I already owned. The double-tap arrived as `nextTrackCommand` and appeared in the log immediately. Architecture confirmed end-to-end on real hardware, not just in a thought experiment.

Long-press, as predicted, opened Siri and never reached the app. The platform constraint we pivoted on Friday is real on at least one consumer device, and very probably on all of them.

### The tap mapping (Earfun Air Pro 3, iOS 26.5)

- **Single tap** → nothing logged
- **Double tap** → `nextTrackCommand` ← v1 trigger
- **Triple tap** → nothing logged
- **Long press** → Siri opens; silent on our side

Only double-tap fires. Single and triple appear unmapped in Earfun's firmware — almost certainly accidental-press prevention, which is sensible firmware design and bad news for any app that wanted a richer gesture vocabulary. For v1 we only need one gesture, so this is fine. For v2 (cancel-while-recording? replay-last-answer?) the lack of a second discrete gesture would force an in-app workaround. Worth keeping in mind when we get there.

### v1 gesture decision

**Double-tap, bound to `MPRemoteCommandCenter.shared().nextTrackCommand`, starts a recording session.** That's the trigger.

End-of-recording is a v1 design question we haven't resolved yet — silence-detection vs. second double-tap vs. fixed-duration window are all candidates. Next session.

### Two compile errors worth naming

iOS 26 and Swift 6 tightened a few things in ways the documentation hasn't fully caught up on. Both showed up on the very first paste of the logger code.

1. **`ObservableObject` no longer conforms when the class is marked `@MainActor`.** The `objectWillChange` publisher the compiler synthesizes for you has to be reachable from non-main threads; the `@MainActor` annotation contradicts that. Drop the annotation, conformance returns.
2. **`@Published` requires `import Combine` explicitly.** Pre–Swift 6, SwiftUI re-exported Combine for you. Swift 6 stops doing that. The error reads as a missing initializer; the actual fix is the import.

Both errors collapse into one-line fixes once you know what's going on. Filing this here because the next time we paste boilerplate that "should just work," it might be a Swift 6 surface change rather than a real bug in our code.

### iOS's gate sequence for free-sideload apps

To get the app from "build succeeded in Xcode" to "tappable icon on the home screen," iOS made me clear three gates I'd half-forgotten about. Documenting the order so future-me doesn't have to rediscover it:

1. **Pair the phone to Xcode.** Triggers a "Trust This Computer?" prompt on the phone. My first attempt got stuck; the fix was a soft reset — unplug USB, quit Xcode entirely (Cmd+Q, not just close window), replug, reopen, re-tap Trust.
2. **Enable Developer Mode on iPhone** (Settings → Privacy & Security → Developer Mode). One-time toggle per device, requires a phone restart.
3. **Trust the developer profile** (Settings → General → VPN & Device Management → tap my Apple ID → Trust). One-time per Apple ID, until the cert expires — which on a free account is every 7 days.

None of this is *new*, but it's the kind of small accumulated friction that adds 20 minutes to a session if you've never walked the path before.

### What's janky / what I'd do differently with real hardware

- **One usable gesture isn't a lot.** A purpose-built earpiece could expose multiple discrete buttons or pressure-sensitive zones, giving us start/stop/cancel/replay without overloading taps. Consumer earbuds are a single-button compromise that the firmware further restricts.
- **The silent audio loop is a load-bearing hack.** If iOS ever tightens audio-session arbitration (which Apple has hinted at in WWDC discussions about "actively producing audio" detection), this pattern breaks and the trigger stops working overnight. v1 is hostage to Apple's mood about silent audio.
- **Per-device firmware variance.** Earfun leaves single and triple unmapped. Sony's LinkBuds Open might map differently — possibly double-tap is *not* the default for "next track" on Sony's firmware, in which case we either re-bind to whichever command fires there, or remap in Sony's Headphones Connect app. We'll know when the package arrives.

### Next session

1. **LinkBuds Open re-test** when the package arrives. Run the same logger; compare the tap-mapping to the Earfun baseline. Update v1 gesture binding if needed; reach for Sony Headphones Connect to remap if defaults don't match.
2. **Start v1 design.** Now that the trigger is real, the next question is the actual recording loop: where does *double-tap → record start → speech-to-text → LLM → text-to-speech → playback* live in the app structure? Decide the end-of-recording mechanic and rough out the scaffolding.

---

## Entry 4 — 2026-05-27 — The API is not the assistant

### The realization

I'd been carrying an unexamined assumption: that "put an AI in my ear" meant putting *my AI assistant* in my ear — the one that knows my history, can check my calendar, can pull up an email, can look something up on the live web. It can't. Not the way I was picturing.

What our app talks to is a **model API**. What I use every day in the Claude and ChatGPT apps is a *product built on top of* a model API. The gap between those two things is much wider than I'd internalized, and it's the gap that defines what this project actually is.

When you call the raw API, you get the model and almost nothing else:

- **No memory.** The API is stateless. It doesn't remember the last conversation, my preferences, who I am. Every query starts from zero.
- **No connectors.** The assistant apps can reach my email, calendar, files, and other services through built-in integrations. The API has none of that out of the box — it can't see anything about my life unless I hand it over in the prompt.
- **No knowledge past the training cutoff.** No live web. Ask it about something that happened last week and it either doesn't know or guesses. The consumer apps paper over this with built-in search; the bare API doesn't.

And critically: **there is no way to plug our app into the Claude app or the ChatGPT app** where the fully-capable, memory-having assistants actually live. Those are closed products. I can't log my app into my own ChatGPT account and borrow its memory and connectors. The capable assistant and the programmable assistant are two different things sitting behind two different doors, and only one door is open to a third-party app.

### What this means for the project

The earpiece I'm building reaches a **smart but amnesiac, disconnected, frozen-in-time** version of the assistant — not the one in my pocket. That's a real reduction in usefulness and I should stop pretending otherwise. "Look something up at dinner" still works for general-knowledge questions inside the training data. "What's on my calendar tomorrow / did Sarah email me back / what's the score right now" does **not** work, not without building each of those capabilities myself.

The honest nuance: every one of these gaps is *closeable at the API layer* — I could stand up my own memory store, wire in Google Calendar/Gmail APIs as my own connectors, add web search as a tool call. But that's me rebuilding, piece by piece and at real cost, the scaffolding the consumer apps already ship. It's a mountain of scope, and it's explicitly **not** what v1 is. v1 is the honest janky loop: double-tap → record → STT → LLM → TTS → playback. A stateless general-knowledge oracle in your ear. That's the artifact.

### The uncomfortable-but-interesting tension

There's a twist worth naming, because it's the portfolio-interesting part. The whole pitch of this device is **privacy-gated, mic-idle-by-default, one deliberate query** — the deliberate rejection of the always-on, always-connected, always-remembering assistant. So the capabilities I just discovered I *can't* have (persistent memory, standing connections into my personal data) are, to a meaningful degree, the exact things the privacy framing was arguing against in the first place. The limitation and the thesis are pointing the same direction. That doesn't make the device more *useful* — it's still more limited — but it does mean the limitation is on-brand rather than fatal. A stateless, connector-less, deliberate-query assistant is *philosophically consistent* with what this project claims to be.

### What I'd do differently with real hardware / a real budget

- **A real product would build the memory and connector layer.** The reason the consumer apps feel magic is that someone built all the unglamorous plumbing — auth, integrations, a memory store, retrieval. A serious version of this device is mostly that plumbing, with the earpiece as the thin front end.
- **Manage the demo's framing honestly.** When I show this, I should demo questions it can actually answer well (general knowledge, reasoning, "explain this to me") and not stage a "check my calendar" moment that the architecture can't truthfully deliver. The credibility of the portfolio piece depends on not overselling what's behind the ear.

---

## Entry 5 — 2026-05-27 — Picking the provider: OpenAI for the whole stack

### The decision

The voice stack is settled: **OpenAI's API for everything — speech-to-text, the reasoning model, and text-to-speech.** This reverses my earlier lean (Claude as the reasoning brain, with OpenAI only a maybe for v2 voice). Two things flipped it.

**1. Voice is the product, and that's where I'm optimizing.** This device is voice-in, voice-out through an earpiece. There's no screen in the moment of use — the entire felt quality of the thing is how natural the spoken answer sounds and how cleanly my speech gets transcribed. That makes voice naturalness the make-or-break dimension, not a finishing touch. OpenAI's voice models are the stronger option there, so the priority that matters most is the one steering the choice.

**2. One provider beats a stitched-together stack.** Once voice points at OpenAI, routing the reasoning through the *same* provider means one API, one key, one bill, one SDK, one set of docs. The alternative — Claude for reasoning, OpenAI for voice — adds a second integration surface and a second failure mode for a marginal reasoning-quality difference that, for general-knowledge dinner questions, I won't feel. Consolidation wins. The simplest stack that does the job is the right stack for a one-person portfolio build.

This also just pulls forward something Entry 1's plan already flagged as a v2 possibility (OpenAI Realtime for voice). It's now the v1 foundation, not a someday-maybe.

### The web-search check (the reason this was safe to commit to)

Before locking it in, I checked whether moving to OpenAI costs me web search — the one capability from Entry 4 I actually wanted back. It doesn't. OpenAI's **Responses API has a built-in, server-side web-search tool**: you add it to the request, the model decides when to search, runs it on OpenAI's servers, and answers with citations. Same "turn it on, don't build it" story as Claude's, and roughly the same pricing shape (~$10 per 1,000 searches plus the token cost of the search content pulled into context). So the Entry 4 conclusion holds on this stack: **web search is the recoverable exception** among the things the bare API lacks, and the provider switch loses none of it.

### What's janky / what I'd do differently

- **Single-provider simplicity is also single-provider risk.** One key, one bill, one outage, one pricing change, one terms-of-service update, and the whole device is affected. For a portfolio piece that's an acceptable trade; for a real product I'd want the reasoning layer abstracted behind an interface so a provider could be swapped without rewriting the app. Worth building the v1 code with at least a thin seam there, cheaply, so the lock-in is a choice and not concrete.
- **The per-search token block is the quiet cost.** The $0.01-per-search headline isn't the real number — it's that plus several thousand input tokens of retrieved content per search, billed at the model's rate. On an hourly-wage budget with a $200 cap, that's the line to watch once the loop is real and I'm testing repeatedly.

### Next session (unchanged from Entry 3, plus this)

1. LinkBuds Open re-test when the package arrives.
2. Start v1 design — the recording loop, the end-of-recording mechanic, and now: rough out the OpenAI integration (STT → reasoning + web-search tool → TTS) with a thin provider seam so we're not welded to one vendor.

---

## Entry 6 — 2026-05-27 — The recording loop (capture half), and the Xcode 26 template fighting back

### The headline

The tap logger is now a recording loop. Double-tap arms the mic and starts recording; a second double-tap stops it and saves the audio to a file. It compiles clean against the iOS 26.5 SDK. I haven't run it on the phone yet (that's the next sitting), but the whole capture half is written and building.

What it does NOT do yet: the STT → reasoning → TTS → playback handoff. That's stubbed behind one clearly-marked function (`handleFinishedRecording`). I added a temporary "Play last recording" button so I can confirm by ear that the mic actually captured something — that scaffolding goes away once transcription lands.

### The end-of-recording decision (the open question from Entry 3)

I'd left "how does recording stop" undecided — silence-detection vs. a second tap vs. a fixed timer. I went with **second double-tap stops it**, plus a **30-second auto-stop as a safety net**. Reasoning:

- It's symmetric and obvious — the same gesture starts and stops, nothing new to learn.
- It reuses the exact command path I already *proved* works on hardware in Entry 3 (`nextTrackCommand`). No new unknowns.
- Silence-detection is the nicer experience but needs tuning (how quiet, for how long) and would cut people off mid-pause. That's a v1.5 polish, not a v1 risk to take on.
- The 30s cap means a missed stop-tap can't run the mic forever or hand a giant file to a paid API later.

Easy to swap later — the stop trigger is one function. If second-tap feels wrong on real hardware, silence-detection drops in without touching anything else.

### The privacy gate, made concrete

This is the part I care most about getting right, because it's the whole pitch. While armed, the audio session is `.playback` — that category literally *cannot* record, so the mic isn't just unused, it's unavailable. The mic only engages inside `startRecording()`, on a deliberate double-tap, by switching the session to `.playAndRecord`. On stop, it switches straight back. The upshot: iOS's orange mic dot lights *only* while you're holding a query — the privacy gate is visible to the user, not just a claim in a README.

### What's janky / what the Xcode 26 template threw at me

This was most of the session. The new multiplatform app template is locked down by default and fought me three times:

- **The mic was disabled at the build-settings level.** `ENABLE_RESOURCE_ACCESS_AUDIO_INPUT = NO` ships in the template. Recording would've been dead on arrival. Flipped to `YES`.
- **`NSMicrophoneUsageDescription` was missing.** iOS hard-crashes the instant you touch the mic without it. Added it — and wrote the description to actually explain the privacy gate ("records only while you hold a query… off at all other times").
- **Background audio mode can't be set the easy way.** I need `UIBackgroundModes = audio` so the keep-alive survives the screen locking (the real scenario is the phone in a pocket). But `INFOPLIST_KEY_UIBackgroundModes` isn't a key Xcode's auto-generator recognizes — it silently ignored it. Had to add a real `Info.plist` with just that key and let Xcode merge the generated keys into it.
- **The synchronized-folder trap.** Dropping that `Info.plist` inside the `earpiece/` source folder broke the build — "Multiple commands produce Info.plist." The folder is a *file-system-synchronized group*, so anything in it auto-counts as a bundle resource, and Xcode tried to both copy it and process it. Fix was to move `Info.plist` to the project root, outside the synced folder.
- **Network is still switched OFF** (`ENABLE_OUTGOING_NETWORK_CONNECTIONS = NO`). Doesn't matter for recording, but it *will* block the OpenAI calls next milestone. Flagged so it's not a mystery later.

### The one thing only the phone can tell me

Open question I can't answer from the compiler: **does the stop double-tap still reach the app while it's recording** (session in `.playAndRecord`)? Remote commands should still route to the active audio app, but earpiece firmware does its own thing — this is exactly the kind of assumption that only survives contact with real hardware. First thing to check when I run it.

### Next session

1. Run it on the phone — confirm double-tap records, second double-tap stops, and the playback button plays back real captured audio. Watch whether the stop-tap routes during recording.
2. LinkBuds Open re-test when the package arrives (compare tap mapping to the Earfun baseline).
3. Wire in OpenAI: flip network on, add the STT → reasoning(+web-search) → TTS chain behind `handleFinishedRecording`, with a thin provider seam.

---

## Entry 7 — 2026-05-27 — The stop-tap that couldn't, and silence as the answer

### The headline

The recording loop is real on hardware. Tap to start, record, stop, play back — the whole capture half works on the phone, not just in the compiler. But the Entry 6 plan to *stop* with a second tap turned out to be physically impossible, and the workaround we'd parked as "v1.5 polish" became the v1 design.

### What we proved

Ran the build on my phone with the Earfun Air Pro 3 (the LinkBuds Open were still on the charger — so this was a stand-in test, LinkBuds re-test still pending). Recording captures audio, saves it to a file, and the verify-by-ear playback button plays it back correctly. The loop works.

One gesture surprise: on *this* Earfun, **triple-tap** fires the trigger, not double-tap. Single-tap comes through as a `pause` command (logged, unbound); double-tap registers as nothing; triple-tap is what sends the `nextTrack` we bind to. That's different from the Earfun in Entry 3 — per-device, per-firmware tap mapping variance, exactly the roulette I flagged. The app's own diagnostic log (it prints every command it sees) is what let me discover this in about a minute. Worth the few lines it cost to build in.

### The finding — taps die the moment recording starts

This is the Entry 6 open question — *does the stop-tap reach the app while it's recording?* — answered on hardware: **no.** My triple-tap to stop did nothing. The recording only ended when the 30-second safety cap fired.

The why, and it's structural, not a bug:

- **Armed** = audio session `.playback` = Bluetooth in **A2DP** (media/stereo). That's the mode where earpiece taps arrive as media-remote commands, so the *start* tap works.
- **Recording** = `.playAndRecord` (to use the earpiece mic) = Bluetooth forced down to **HFP**, the mono "phone call" profile. In call mode the earpiece's taps are interpreted as *call controls* (answer/hang-up), not media commands — so they never reach the app.

The instant I engage the mic, the Bluetooth profile flips and the tap channel I was relying on goes dead. You cannot have the earpiece mic **and** media-remote taps at the same time, because using the mic *is* what kills the taps. This is a Bluetooth-profile constraint, not an Earfun quirk — so I fully expect the LinkBuds Open to behave the same way. It's not "wait for the real earbuds," it's a property of the platform.

### The design response — silence detection

Entry 6 listed silence-detection as v1.5 polish and chose second-tap-to-stop for v1. This finding inverts that: second-tap is impossible, so silence detection *is* v1. Implemented it as: meter the mic level ~4×/second, and once we've heard speech at least once, stop after 1.5s of continuous quiet — with the 30s cap kept as the runaway backstop (silence *or* 30s, whichever comes first). The "heard speech first" guard means the natural pause before you start talking can't end the recording prematurely.

It worked on the first run, no threshold tuning needed in a quiet room. And honestly the interaction is *better* than tapping twice: one deliberate tap to start, then just stop talking. That's more on-brand for the "one deliberate gesture, nothing ceremonial" pitch than a start-tap/stop-tap pair would have been. The platform took away the option I planned and handed me a nicer one.

### What's janky / what I'd do differently with real hardware

- **The A2DP/HFP split is the root constraint and it's not going away.** A purpose-built earpiece with its own BLE control protocol (or a physical button on a known channel) would let a "stop" gesture survive into the recording state, because it wouldn't be riding the Bluetooth media/call profile at all. Consumer earbuds force the choice; custom hardware wouldn't.
- **Silence detection is room-and-mic dependent, and the demo scenario is a restaurant.** It worked untuned in a quiet room. A noisy table — the actual pitch scenario — may push the noise floor above the threshold (never stops) or swamp quiet speech (cuts off). A real product wants adaptive/relative thresholding, not a fixed dB line. That's a test still ahead, and a likely-interesting failure to capture.
- **The on-screen Start/Stop button is scaffolding**, standing in for a reliable hardware gesture so testing isn't hostage to tap-mapping roulette. It comes out once the LinkBuds start gesture is locked in.
- **Everything here is still Earfun-only.** The LinkBuds re-test (its trigger gesture, and confirming the same taps-die-during-recording behavior) is the first thing next session.

### Next session

1. **LinkBuds Open re-test** once charged: find which gesture fires the trigger, confirm (almost certainly) the same taps-die-mid-recording behavior, and lock the v1 start gesture.
2. **Wire in OpenAI** (still the big one): flip network ON — it's still `NO` in build settings — and build the `STT → reasoning(+web-search) → TTS → playback` chain behind `handleFinishedRecording`, with the thin provider seam.
3. **Noise-test silence detection** in a realistic loud environment; make the threshold adaptive if a fixed line doesn't hold.

---

## Entry 8 — 2026-05-27 — The loop closes: a question in, a spoken answer out

### The headline

It works. I tapped to record, asked "what's the tallest mountain in the world?" out loud, and a few seconds later the earpiece *spoke the answer back to me.* Voice in → transcription → reasoning → speech → voice out, the whole round trip, on the phone. The thing this entire project was pointed at — a question you ask out loud and an answer you hear — exists now. Everything before today was scaffolding around an empty `handleFinishedRecording`. Today that function became the product.

### What got built

The back half of the loop, behind the provider seam I committed to in Entry 5:

- **`AssistantProvider`** — a three-method protocol (`transcribe → respond → synthesize`). The app talks to *this*, never to OpenAI directly. The whole point is that swapping the backend later is one new file, not a rewrite. Entry 5 said "build the seam cheaply so the lock-in is a choice, not concrete" — done.
- **`OpenAIProvider`** — the OpenAI implementation: three raw REST calls (transcription, the Responses API with the built-in web-search tool, and speech), no SDK. Balanced voice-first models: `gpt-4o-mini-transcribe`, `gpt-4o-mini` for reasoning, `gpt-4o-mini-tts`. Each model is a one-line constant.
- **`Secrets.swift`** — API key isolated in one file, kept out of the chat and out of app logic.
- **Pipeline wiring** — `handleFinishedRecording` now kicks off `transcribe → respond → synthesize → play` as an async Task, with a new orange **WORKING…** state and a stage-by-stage on-screen log (Transcribing… / You asked… / Thinking… / Answer… / Speaking…). That log is what made the first run legible instead of a black box.
- **Network flipped on** — `ENABLE_OUTGOING_NETWORK_CONNECTIONS` was `NO` (flagged back in Entry 6); now `YES`.

### A callback to Entry 4

Entry 4 was the gloomy one — the realization that the bare API is "smart but amnesiac, disconnected, frozen-in-time," not the assistant in my pocket. Wiring in web search today recovers one of those three: it's no longer *frozen in time*. It can answer "what happened this week" because the model reaches the live web server-side. The other two gaps — no memory, no personal connectors — are still wide open, and (per Entry 4's twist) still *on-brand* open: a stateless, connector-less, deliberate-query oracle is exactly what the privacy pitch argues for. So what exists today is precisely the honest artifact Entry 4 landed on: a web-connected general-knowledge oracle in your ear, not a stand-in for ChatGPT-with-my-life-plugged-in.

### What's janky / what I'd do differently with real hardware

- **It's a sequential request/response pipeline, and you feel it.** Record fully, *then* transcribe, *then* think, *then* synthesize, *then* play — the latency is the sum of three round-trips, so there's a noticeable silence before the answer starts. A real product would use a streaming/realtime API (OpenAI Realtime) so the answer begins speaking as it's generated and the whole thing feels conversational. v1 is "ask, wait, hear" — fine for a portfolio demo, not phone-assistant-snappy. Strong v1.5 candidate.
- **The system prompt is load-bearing.** Left alone, the model answers in lists and markdown — useless when the output is *spoken*. A paragraph of instructions ("you will be HEARD, not read; one or two plain sentences") is what keeps replies speakable. Worth remembering that the voice quality of the *words* is a prompt problem, not just a TTS problem.
- **Every query is now real money.** STT + reasoning + web search + TTS per question. The web-search per-call cost is the one to watch (Entry 5 flagged ~$10/1k searches plus retrieved-token cost) — it dwarfs the rest. I set a spend limit on the OpenAI account; on an hourly-wage budget, repeated testing is the line item to respect.
- **Secrets in plaintext.** Fine for a one-person prototype on my own phone. The instant this touches a git repo it must be gitignored, and a shipping product would use a backend proxy so the key never lives on-device at all (any determined user can extract a key compiled into an app).
- **Still driven by the on-screen test button, not the earpiece.** The entire loop today ran via the temporary "Start recording" button on the Earfun stand-in. The real gesture trigger and the LinkBuds are still ahead — the product *works*, but it isn't yet *operated the way the product is supposed to be operated.*

### Next session

1. **LinkBuds Open**, finally: confirm the trigger gesture, re-confirm the taps-die-during-recording behavior, and **wire the real gesture to replace the test button** (then remove the button + the verify-by-ear button — the scaffolding's job is done once a tap starts a real query).
2. **Noise-test** (still outstanding from Entry 7): does silence-detection survive a loud room — the actual demo scenario?
3. **Latency**: evaluate the Realtime API for streaming, so the answer doesn't arrive after a dead pause.
4. **Polish**: show the answer text on screen too, harden error handling, and consider re-recording follow-ups (the no-memory limitation means each query is standalone — is that the demo story, or do I fake a little session memory?).

---

## Entry 9 — 2026-05-28 — The LinkBuds, and the day the load-bearing hack actually broke

### The headline

First real test on the actual target hardware — the Sony LinkBuds Open, charged overnight. And the silent-audio keep-alive, the hack I'd flagged as "load-bearing" in Entries 3 and 6, finally broke in exactly the way I was afraid of. The earpiece taps worked in *every other app* but logged *nothing* in mine. Spent the morning diagnosing it, found a clean root cause, and made the keep-alive self-healing. By the end it ran hands-free on the LinkBuds, surviving the interruptions that broke it. But the lesson is the one the log has been muttering for a week: this foundation is patched, not solid.

### The bug

Tapping the LinkBuds (Sony's "Wide Area Tap" — you tap your cheek in front of the ear) controlled music in other apps fine, but produced *zero* log lines in mine. Not a wrong command — *nothing*. That's a different failure from the Earfun, where the app always saw the taps; here the taps weren't reaching the app at all.

The tell was "works in other apps." iOS routes earpiece taps to whichever app currently holds the **"Now Playing"** role, and my app only *pretends* to hold it via a loop of silent audio. The moment I'd played music elsewhere to confirm the buds worked, that app grabbed Now Playing and my silent loop never fought back. Confirmed it cold: force-quit every other audio app, relaunch mine, and the taps came straight back. So the loop was real — it just kept losing a turf war it never re-entered.

### The fix — a self-healing keep-alive

The keep-alive was fire-once: configure session, play silence, done. Now it *reclaims* its slot whenever something steals it. Three triggers, all routed to one `reclaimAudioFocus()` (re-activate the session, restart the silent loop, re-assert Now Playing):

- **Audio-session interruptions** (`AVAudioSession.interruptionNotification`) — a call, a timer, another app's audio. On "ended," reclaim.
- **Route changes** (`routeChangeNotification`) — buds disconnecting/reconnecting.
- **Returning to the foreground** (SwiftUI `scenePhase` → `.active`) — the common case: I left to another app and came back.

Supporting change: the silent loop is now restartable. An `AVAudioEngine` stops on interruption and doesn't restart itself, so I split "build the audio graph once" from "(re)start it," and made the restart idempotent — safe to call on every reclaim, does nothing unless the engine or player actually stopped. After the fix, the exact break-it sequence (play Spotify, pause, come back, triple-tap) recovered on its own with no force-quit. The phone-call interruption case recovers the same way.

### The LinkBuds gesture, while we were here

Confirmed the LinkBuds trigger is **triple-tap** — single-tap doesn't register at all, same shape as the Earfun. Since triple-tap already fires `nextTrackCommand` (what the trigger binds to), there was nothing to re-bind: triple-tap → record → silence-stop → "Thinking" → spoken answer now runs fully hands-free on the real hardware, no on-screen button. Also retired two bits of now-false on-screen copy ("double-tap", "double-tap again to stop").

### What's janky / what I'd do differently with real hardware

- **I made the hack robust; I didn't make it not-a-hack.** The whole "claim Now Playing with silent audio, then defend it against every other app" dance exists only because iOS won't give a third-party app the earpiece's button events directly. Custom hardware with its own BLE control protocol wouldn't be in this turf war at all — the taps would come straight to the app and none of today's code would need to exist. I'm getting good at defending an indefensible position.
- **"Now Playing" arbitration is undocumented and heuristic.** My reclaim is best-effort against behavior Apple has never specified and could change in any iOS release. It works today on iOS 26.5; that's the strongest claim I can make.
- **The reclaim is reactive.** There's a hair-thin window where a tap landing at exactly the wrong instant (after another app played, before the reclaim fires) would miss. Never hit it in testing, but it's there.
- **Foreground reclaim is intentionally silent** (no log line) so app-switching doesn't spam the on-screen log; interruptions and route changes do log. A small observability-vs-noise call.
- **It all still dies if iOS kills the app.** The keep-alive only works while the process lives. Background eviction under memory pressure, or a long stint backgrounded, and the taps go quiet until you reopen the app. A shipping product needs a sturdier answer than "keep a silent sound playing forever."

### Next session

1. **Remove the scaffolding.** The on-screen "Start/Stop (test)" button and the "Play last recording" button have done their jobs — the real triple-tap flow works end-to-end, and STT landed (so verify-by-ear is moot). Strip both; let the hardware gesture be the only way in.
2. **Noise-test silence detection** — still outstanding from Entry 7, and the LinkBuds' open-ring design + Sony's not-H2-tier mic make a loud room the real question.
3. **Latency / Realtime streaming** (Entry 8) — the dead pause before the answer is the next felt-quality gap.
4. **Survive app eviction** — at least detect it and recover gracefully when the user reopens.

---

## Entry 10 — 2026-05-28 — A handful of fixes, and the locked-screen wall

### The session

Came back with a punch-list of rough edges from real use. The small ones landed cleanly; one — recording while the phone is locked — turned into the deepest platform finding yet, after I chased it through three wrong theories before an experiment settled it as an iOS limitation I can't code around without gutting the privacy pitch.

### The small fixes

- **It read URLs out loud.** Web-search answers were citing sources by spelling out the link — meaningless and grating through an earpiece. Added a rule to the spoken-style prompt: never read URLs/addresses aloud, just name a source in plain words if it helps. Then had to *reinforce* it — when I broadened the date fix (below) into a strong "search the web" instruction, the model started reading links again; the new search push was drowning out the older no-URL line. Moving the no-URL rule right next to the search instruction settled it. Lesson: prompt instructions compete, and proximity/emphasis matter. If it ever slips again, the bulletproof answer is to strip URLs from the text in code before TTS, not to keep arguing with the prompt.
- **"Thinking" even when I'd said nothing.** Now says **"I didn't hear that"** instead. Two paths: a *local* shortcut — if the mic never crossed the silence floor, say it immediately and skip the cloud entirely (no API spend) — and a *cloud* path for when something crossed the threshold but transcribed to nothing (a cough, a door).
- **"I can't know today's date — check a calendar."** Training is frozen and there's no clock, so it hedged on anything current. Fixed two ways: hand it the real device date on every call, and — generalized at my request — a standing rule that since it *has* web search it must never claim it can't know something or tell me to look it up myself; it should search and answer.

### The locked-screen investigation (the real story)

The bug: locked/pocketed, a tap would start recording but it never stopped or answered. Walked it down in layers.

1. **Timers (fixed).** `MPRemoteCommandCenter` doesn't promise a thread, and when locked it delivered the tap on a *background* thread — so the stop-timers were scheduled on a run loop that never spins, and recording ran forever. Funnelled every command to main (`onMain`) and pinned the timers to the main run loop in `.common` modes. After this, recording *stopped* when locked (the 30s cap fired). Real fix, confirmed on device.

2. **But it captured silence.** Added a mic-level diagnostic: **peak -120 dBFS** over the whole recording — pure digital silence. The mic wasn't reaching us.

3. **Wrong theory: engine contention.** Guessed the always-on silent keep-alive engine was fighting the recorder for the mic IO, and stopped it during recording. Still -120. Reverted — it didn't help, and adding a restart dependency to the load-bearing keep-alive wasn't worth it. A route log confirmed the *correct* mic was selected (`BluetoothHFP`); selection was fine, delivery wasn't.

4. **The experiment that settled it.** Started recording while *unlocked*, then locked mid-sentence and kept talking: it kept capturing and answered fine. So capture **survives** a lock — it just can't be **started** under one. Root cause: recording forces Bluetooth into its call profile (HFP), which spins up a voice mic link (SCO), and **iOS won't bring that link up for a backgrounded app while the screen is locked.** Started unlocked, the link is already up and persists across the lock.

### Why I'm not "fixing" it

The only software workaround is to keep the mic link warm *continuously* so it's already up when a locked tap lands — which means the mic is engaged all the time, the orange dot never goes out, and the whole "the mic is off until you deliberately ask" pitch collapses. The thing that makes this project special is the thing that makes the workaround unacceptable. Same wall Entries 1 and 9 kept naming: the silent-audio hack can *catch the tap* when locked, but iOS won't let a locked, backgrounded app *engage the mic*. The honest fix is custom hardware that captures its own audio and streams it, sidestepping the iOS microphone entirely.

### What I did instead — fail out loud

Kept the privacy gate untouched and made the failure *useful*. A new dead-input guard watches the mic for the first couple of seconds; if it sees nothing but digital silence (below -100 dBFS — far under any live mic's noise floor, so a working-but-quiet mic never trips it), it concludes iOS withheld the mic, stops early, and speaks **"I couldn't reach the microphone — unlock your phone and ask again."** No more recording 30s of nothing and then confusingly claiming it didn't hear me. It's a graceful boundary, not a fix — but on a screenless earpiece, telling the user what happened *is* the feature.

**Confirmed working on device:** a tap while the phone is locked now triggers the spoken "unlock your phone and ask again" cue within a couple of seconds, instead of the old silent 30-second dead-end. The failure is finally legible.

### What's janky / honest notes

- **The dead-input floor (-100 dBFS) is a heuristic.** It cleanly separates the locked case (-120) from a live mic (well above -90 even in a silent room), but it's a threshold, not a guarantee — biased to never cry wolf on a working mic, at the cost of occasionally missing a genuinely dead one (which then falls through to the old "I didn't hear that").
- **The locked limitation stands.** Hands-free from the pocket only works for a query *started* while unlocked. For the demo, that's the honest envelope.

### Next session (carrying forward from Entry 9)

1. ~~**Remove the scaffolding**~~ — **Resolved (post-Entry 10), with a twist:** the on-screen Start/Stop and "Play last recording" buttons turned out too useful to delete — the whole locked-screen diagnosis leaned on them. So instead of removing them, they're now gated behind a persisted **"Testing mode"** toggle: off by default for a clean demo UI, one tap away when testing. Hiding beat deleting.
2. **Noise-test silence detection** in a loud room.
3. **Latency / Realtime streaming** — the dead pause before the answer.
4. **Survive app eviction** — detect and recover gracefully.

---

## Entry 11 — 2026-05-28 — Streaming the answer, a URL backstop, and static we live with

### The session

A polish round, all driven by real use: chased the latency, finally beat the URL-reading habit, and tracked a static glitch down to a platform behaviour I chose to live with rather than fight. Also turned the test scaffolding into a toggle instead of deleting it (see the Entry 10 item-1 note — hiding beat deleting).

### Streaming TTS — the right fix, a smaller win than hoped

The dead pause before answers (Entry 8) is three sequential, fully-blocking cloud round-trips, and the worst offender was waiting for the *entire* TTS mp3 to download before speaking a word. Fixed that: TTS now requests raw **PCM** (no container, so it streams) and plays each ~0.2s chunk as it arrives on a dedicated audio node — first word out on the first chunk instead of after the whole clip. Audio came back clean.

But I measured before and after instead of assuming, and the numbers humbled the plan. The breakdown was **balanced thirds — STT ~2.2s, reasoning ~2.2s, TTS ~1.7s** — no single villain. Streaming reclaimed the TTS third, but the felt latency is still ~6s, because STT + reasoning dominate and there's a 1.5s silence-detection lead-in before the pipeline even starts. The hard truth: in a REST pipeline you must transcribe the whole question before you can reason about it, so STT is unavoidably upfront — the floor is ~3s no matter how well we stream the rest. The only thing that breaks that floor is a speech-to-speech Realtime API, which I'm **deferring to a possible v2**: it's a real rewrite, and more to the point too expensive to run for a portfolio piece. Streaming TTS was still the right move (it's the structural fix, and it's free); it just isn't the felt-latency cure on its own.

### The URL backstop — when to stop arguing with the prompt

The model kept reading source links aloud, worst on long, search-heavy answers where the no-URL instruction got diluted. I'd already moved that rule next to the search instruction (helped, not enough). This round I stopped trusting the prompt and added the deterministic backstop I'd flagged: **strip URLs from the answer in code** before it's spoken — keep markdown labels, drop bare http/www links, tidy the leftover brackets and punctuation. The lesson restated: prompt steering is a preference, not a guarantee; when correctness matters, enforce it in code. Tradeoffs noted in-line — a slip can leave minor debris ("according to ,"), and a *bare* domain with no http/www still leans on the prompt.

### The static we chose to live with

Streaming exposed a glitch: switch apps *while an answer is reading* and the speech continues, but with a burst of static. Walked it down. The log showed **no reclaim / route / interruption** at that moment — so it isn't our code touching the session. It's iOS reconfiguring audio IO as the app backgrounds, and our *live* playback glitching across that hand-off. Why ours and not a normal music app: the load-bearing keep-alive, again. We run the silent keep-alive loop and the 24 kHz answer (sample-rate-converted by the mixer) on one engine — an unusual graph that's fragile at the background transition.

I chose to **accept and document** it rather than fix it. It's minor and edge-case (tabbing away mid-answer, to a silent app); the candidate fixes are coin-flips that add completion-tracking machinery; and every one of them pokes the keep-alive — the last thing I want to destabilise for a cosmetic gain. It's filed where it belongs: another side effect of claiming Now-Playing with silent audio, the hack the whole project is built on and keeps paying for.

### What's janky / honest notes

- **Latency is still ~6s felt.** Streaming TTS helped the structure, not the number. STT + reasoning are the floor; only Realtime (deferred, cost-gated) makes it conversational.
- **The 1.5s silence lead-in is an untaken cheap win** — dropping it to ~0.8s would shave felt time, at the risk of clipping slow talkers. Didn't do it this round.
- **URL stripping isn't grammar-perfect**, and misses bare domains.
- **Background static is accepted**, not fixed — a known keep-alive side effect.

### A note from this session: the files vanished mid-write

Right as I went to write this entry, the whole `~/Documents` tree threw "Operation not permitted" — code dir, BUILDLOG, everything — mid-session, after a dozen successful edits and builds. Not the code's doing: an OS-level access grant (TCC/iCloud) dropped under the harness. The already-written code survived (writes that landed stayed landed); only this entry was held up. Resolved on a retry once access came back. Noting it because "the tools stopped working" is itself a data point about the dev environment, and future-me will want to know it wasn't a corruption.

### Next session

1. **Trim the silence lead-in** (1.5s → ~0.8s) — the cheap felt-latency win left on the table.
2. **Noise-test silence detection** in a loud room — still outstanding from Entry 7.
3. **Realtime streaming** — the only real latency cure, parked in v2 on cost (see also Appendix A for the other v2 escape hatch).
4. **Survive app eviction** — detect and recover gracefully.

---

## Entry 12 — 2026-05-28 — What it was for: two lessons, and not-dead-just-reframed

### Why this entry exists

Stepped back and asked the uncomfortable question out loud: is this thing actually valuable, or did I just rebuild a worse Siri? Worked it honestly and landed somewhere more useful than either "it's great" or "it's pointless." This is the portfolio read on the whole project — what it was for, and the two things it actually taught me — so the log has an explicit conclusion instead of eleven entries of build notes trailing off.

### The honest product verdict

As a product, this loses, and I won't pretend otherwise. "General-purpose AI in your ear" is something Apple, Google, and OpenAI will each absorb into hardware people already own — faster, cheaper, with the underlying capability racing toward free. Long-press Siri → ChatGPT already does the search-and-reason job, runs when the phone is locked (mine can't — Entry 10), and answers in under a second (mine takes ~6 — Entry 11). The Humane Pin and Rabbit R1 were far more polished swings at exactly this and died for exactly this reason: **you can't out-feature the platform that owns the device.** The portfolio is stronger for saying that plainly than for hiding it.

### Lesson 1 — how these systems actually work

I understand, from hitting each one, the things that stay invisible until you build:

- **A model API is not an assistant** (Entry 4). The thing in my pocket is a *product* on top of a model — memory, connectors, retrieval, all the unglamorous plumbing. The bare API is smart, amnesiac, and disconnected. That gap is the whole game.
- **The platform owns the hardware affordances.** iOS won't hand a third-party app the earpiece's buttons, so the entire app is a hack to claim "Now Playing" with silent audio and defend it (Entries 3, 9) — and it won't let a locked, backgrounded app start the mic at all (Entry 10). The privacy gate I was proud of is real, but built on sand iOS could wash away in any release.
- **Latency has an anatomy.** Not "the API is slow" — three sequential round-trips, and measuring beat guessing every time (Entry 11). The fix that helped (streaming TTS) and the floor that wouldn't move (STT must finish before reasoning starts) both came from the numbers, not hunches.
- **Prompt steering is a preference, not a guarantee.** The model kept reading URLs aloud no matter how I worded the rule; the only reliable fix was stripping them in code (Entry 11). When correctness matters, enforce it in code.

None of that survives as a tutorial. I know it because each one cost me a session.

### Lesson 2 — how to tell when a project isn't feasible

The one I value most. I built the thing, ran it on real hardware, and reasoned my way to "even the polished hardware version is a worse phone, so no one would adopt it" — *before* sinking months or money into it. Killing your own idea with evidence is the rarest instinct in product work and the most expensive one to lack; the Humane founders raised $230M without it. I got there in a couple of weeks for the cost of an API bill. That's what the portfolio should foreground: not "I shipped an app," but "I can tell a dead product from a live one, and show my work."

### Not dead — reframed

The conclusion isn't "throw it away." The *product* was never the point, and the *personal tool* is genuinely feasible — more so now than when I cut it (Entry 4). "For myself" deletes the multi-user productization that priced the original vision out, and MCP turned the connector mountain into a wiring job. The front half of this app (privacy gate, capture, streaming answer) is reusable; the back half grows from "search" into the memory-and-connectors assistant I actually wanted. The build wasn't a detour from the vision — it was the part of the vision that's hard to fake.

### The framing, in one line

*A working voice assistant I built to learn how these systems fit together — and to practice the harder skill of knowing when to stop building one thing and start building the right one.*

---

## Entry 13 — 2026-05-28 — The real question, answered: it was the platform all along

### Why this entry exists

Entry 12 reframed the project from "dead product" to "feasible personal tool." But before building the personal tool, I asked the question that actually matters for my own use: do I even need to build a brain? Could I keep the discreet earpiece interaction and point it at the **real ChatGPT** — the one I already use, with my memory and connectors — instead of maintaining a parallel assistant? I ran a structured, multi-agent research pass (fan-out search → fetch → 3-vote adversarial verification) to settle it with evidence instead of vibes. The answer reframes the whole project one last time.

### The finding: not on iOS — and every wall was the same wall

You **cannot** wire a discreet earbud tap to ChatGPT's full Advanced Voice Mode on iOS. Verified, primary-sourced:

- iOS Shortcuts has **no trigger for an earbud tap** (no media / audio-route / headphone-button trigger — only Bluetooth *connect*). The gesture surfaces only as a media remote command, catchable solely by an app that then *can't* hand off into ChatGPT's voice mode from the background.
- **Siri → ChatGPT is one-shot text** — confirmation-gated, no memory, no connectors, and explicitly cannot launch voice mode. (And it announces itself — the Entry 1 killer.)
- The **only** hands-free route to the real ChatGPT brain is the iPhone **Action button** — a press on the *phone*, not the earpiece. Not discreet, not from the pocket.

And the bigger realization: every wall this project ever hit is **one wall**. The keep-alive hack (Entries 3, 9), the locked-mic failure (Entry 10), and now this — all the same thing. **Apple won't give a third-party app the earpiece + mic + lock-screen access the vision needs.** It's not a skill gap or a build gap. It's a platform decision.

### The other side of that wall: Android lets you do it — pointed at ChatGPT, no less

The same research found the thing iOS forbids ships openly elsewhere. The standout: **on Android, ChatGPT itself can be set as the default digital assistant** (OpenAI, March 2025) — launching into voice mode with its real memory and connectors, and with **no hotword** (a privileged-API limit) which, for this project, *is* the privacy gate: mic off until a deliberate trigger. So the full original vision — discreet trigger → the actual ChatGPT that knows me — is reachable on Android, keeping the LinkBuds I already own.

One honest unknown remains, and it's empirical, not documentable: whether the **LinkBuds tap specifically** routes to ChatGPT (Sony's docs lean Google-bound, and Android gates some trigger paths to privileged apps) and how it behaves locked. That's a 20-minute on-device test, not another search — and even the worst case has Android escape hatches (Tasker) that iOS never offered.

### Where this leaves the project

The iOS app's role is now settled and honest: **it's the investigation that proved the platform was the constraint.** I wanted a private AI earpiece; I built toward it on real hardware, hit wall after wall, then proved with structured research that the walls are all Apple's, and that the goal actually lives one platform over. The next step toward *using* it is an Android test — not more iOS code.

That's the whole arc, and it's a good one: from "wouldn't it be cool if" → a working prototype → "this is a worse Siri" → "the product is dead but the tool is feasible" → "actually the blocker was the platform, and here's exactly where the goal lives." Build, measure, conclude, and know when to change platforms instead of grinding on. That's the portfolio piece.

### Next step (the real one)

1. **Borrow an Android for 20 minutes.** Install ChatGPT, set it as default assistant, map the LinkBuds tap to voice-assist in Sony Sound Connect, test unlocked then locked. That single test resolves the last unknown and tells me whether my own goal is one phone-switch away.

---

## Appendix A — Side path under consideration: a Raspberry Pi "brain" (NOT a decision)

> ⚠️ **Status: exploratory only.** This is a sketch of an alternative we're *thinking about*, not work we're doing or have committed to. Nothing here is built, nothing is bought, and the iOS app remains the actual project. It lives in the log so the reasoning isn't lost if we ever pick it up. **Do not read this as a plan.**

### Why it comes up

Entry 10 ended on a wall: iOS won't engage the Bluetooth mic for a locked, backgrounded app, and the only software workaround (keep the mic warm forever) destroys the privacy pitch. That wall is *iOS-specific*, not Bluetooth-specific. So the recurring "custom hardware" idea from Entries 1 and 9 has a concrete, cheap shape worth writing down: move the brain off the phone onto a tiny Linux box that has no lock screen and no privacy-gated mic.

### The shape of it

- **Board:** Raspberry Pi Zero 2 W (~$15). Bluetooth 4.2 + WiFi built in, full Linux, runs a normal script as a `systemd` service on boot.
- **Topology:** the Pi pairs with the LinkBuds as the **A2DP source** (plays answers) and the **HFP gateway** (pulls the mic). The earbud tap arrives as an **AVRCP "next track"** passthrough — the *same* event we bind to on iOS today, just surfaced on Linux as a `KEY_NEXTSONG` input event.
- **Connectivity:** cheapest is to **tether to the phone's hotspot** — and note the phone becomes a dumb internet pipe, never the audio/mic gateway, so none of the iOS pain returns. A cellular HAT (SIM7600, ~$40–50 + data SIM) would make it phone-independent.
- **Power (to go portable):** LiPo + a PiSugar-style board (~$25–40).
- **Rough cost:** ~$25 bench prototype (tethered, wall power) → ~$60–80 pocketable (battery + hotspot) → ~$120+ with its own cellular.

### What carries over, what changes

The pipeline design ports almost intact — the `AssistantProvider` seam (transcribe → respond → synthesize) is just three REST calls and doesn't care what language it's in. What **disappears** is all the iOS-specific scaffolding: the silent-audio keep-alive, the Now-Playing turf war, `MPRemoteCommandCenter`, and the whole record-session privacy-gate dance. What **appears** is Linux audio plumbing: BlueZ + PipeWire/oFono pairing, A2DP/HFP/AVRCP wiring, and making it all survive a reboot. Net: the *script* gets simpler, the *system* gets fiddlier — a different adventure, not a smaller one.

### The ported loop, sketched (Python, illustrative — untested)

```python
# provider.py — same seam as AssistantProvider.swift, three cloud calls.
class OpenAIProvider:
    def transcribe(self, wav_path: str) -> str: ...   # POST /v1/audio/transcriptions
    def respond(self, question: str) -> str: ...       # POST /v1/responses (web_search tool + dated prompt)
    def synthesize(self, text: str) -> bytes: ...      # POST /v1/audio/speech -> mp3
    # The prompts (spoken-style, no-URLs, dated, "search don't refuse") move over verbatim.

# earpiece.py — replaces EarpieceController. No keep-alive, no Now-Playing claim.
assistant = OpenAIProvider()

def on_trigger():                       # fired by AVRCP "next track" (the earpiece tap)
    bring_up_hfp_mic()                  # THE privacy gate: SCO link only comes up here,
    wav = record_until_silence()        # on a deliberate tap — mic is down the rest of the time
    drop_hfp_mic()                      # gate closes the instant we stop
    speak("Thinking")                   # local cue (espeak/piper), same as the on-device cue
    try:
        q = assistant.transcribe(wav).strip()
        if not q:
            return speak("I didn't hear that")
        play(assistant.synthesize(assistant.respond(q)))   # answer aloud over A2DP
    except Exception as e:
        speak("Something went wrong")    # + log e

def main():
    # Read /dev/input/eventX for KEY_NEXTSONG from the BlueZ-created AVRCP input device,
    # call on_trigger() on each. Runs forever as a systemd service — no lock screen to fight.
    listen_for_tap(on_trigger)
```

### The privacy gate, reconsidered (the interesting part)

On iOS the gate was enforced *and advertised* by the OS: the mic engaged only inside `startRecording()`, and the orange dot was the gate made visible — a trust signal a skeptic could verify. On the Pi we get **stronger control** (we decide exactly when the HFP/SCO mic link comes up, and it can stay down until a tap — see `bring_up_hfp_mic()`), but we **lose the OS-provided proof**. There's no orange dot on a Pi. To keep the privacy *claim* credible we'd have to add our own hard signal — e.g. an LED wired to the mic-link state — so "the mic is off until you ask" is demonstrable, not just asserted. The mechanism improves; the assurance has to be rebuilt by hand.

### Open questions if we ever pick this up

- **HFP mic quality** off BlueZ/PipeWire vs. the iOS capture — is speech clean enough for STT?
- **Reboot/resilience** — does the pairing and audio routing reliably come back unattended?
- **The trust signal** — is a DIY LED actually convincing, or does losing the orange dot quietly weaken the whole pitch?
- **Effort vs. payoff** — this trades an app I can mostly drive for a Linux/Bluetooth integration I'd be learning from scratch. Worth it only if the locked-screen limitation proves fatal to the vision, not just annoying.

---
