# Leftover / TODO

Things intentionally deferred. The app is feature-complete and demoable without
these; this is the "later" list.

---

## 1. Generate the AI Film in PARALLEL with the tour (biggest UX win)

**Now:** the flow is sequential — the rig tour runs first (~5 min), THEN post-tour
kicks off film generation (~5–15 min). So the user waits tour + film back-to-back.

**Idea:** start `generateFilm(locations)` the moment the tour starts (on "Yes,
make a film") and let it run in the background while the rig flies. By the time
the tour ends, the film is done or nearly done — hides the whole tour duration.

**Why it's doable:** `generateFilm` only needs the `locations` list (available at
Preview), not the running tour. `aiFilmProvider` is app-scoped, so the generation
Future keeps running across screen changes. It does NOT touch the DO-NOT-TOUCH
orbit/SSH code.

**What it needs:**
- Fire `generateFilm()` at tour start instead of at post-tour.
- A small non-intrusive progress chip on the Active Tour screen (not the current
  full-screen progress page).
- Post-tour reads the already-running/finished job instead of starting fresh.
- Decide cancel semantics: if the user stops the tour early, keep generating or
  abort (and stop spending)?
- Quiet error surface (banner) if the film fails mid-tour — must not hijack the
  tour UI.

**Caveat:** Kling generation (~5–15 min) is usually longer than the tour (~5 min),
so it won't be *instant* at post-tour, but it's a big net win.

---

## 2. "Coming soon" / stubbed buttons (deliberately not wired)

These show a "Coming soon" badge or a snackbar and do nothing functional yet:

- **Tour Preferences → Narration Voice** dropdown
  (`lib/screens/settings/tour_preferences_screen.dart:104`, `comingSoon: true`).
  Disabled; TTS currently uses the device's default voice. Real voice selection
  is OS/device-dependent.
- **Saved tab → "Offline" & "Curated" filter chips**
  (`lib/screens/saved/saved_screen.dart:31`, `_stubFilters = {2, 3}`). Chips are
  disabled; only the working filters function.
- **LG Connection → "Scan QR to connect"**
  (`lib/screens/settings/lg_connection_screen.dart:245`). Shows the snackbar
  `qr_connect_coming_soon` ("QR connect — coming soon"); no QR scanning yet.
  Manual IP/user/pass connection works.
- **Narration subtitles** — subtitle toggle/voices area is display-only
  (`narration_subtitles` section). TTS narration itself works; on-screen subtitle
  options are not wired.

To "finish" these: either wire the real feature, or hide the control so nothing
reads as unfinished. Low risk either way — none block a demo.

---

## 3. Other known deferrals

- **AuditorService** — still bypassed in `generation_screen.dart` because geocoding
  is flaky (it would drop valid locations). Re-enable with a safe fallback once
  geocoding is reliable.
- **Video providers** — only **fal.ai** is live-tested. Veo 3, Runway, Kling
  direct, vLLM-Omni, Custom are code-correct (right exception type, structurally
  correct endpoints) and fail gracefully, but not verified against their live APIs.
- **APK size** — release APK is ~117 MB (universal, all ABIs; FFmpeg is the bulk).
  Use `flutter build apk --split-per-abi` and ship the `arm64-v8a` one (~50 MB),
  or `flutter build appbundle` for the Play Store.
- **Switch AI Film to Kling v3 before the real demo** — phone currently has LTX
  saved from testing (LTX = cheap test model; Kling v3 = demo quality).
