# Leftover / TODO

Things intentionally deferred. The app is feature-complete and this is the "later" list.

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

These are display-only or show a snackbar and do nothing functional yet:

- **Tour Preferences → Narration Voice** dropdown
  (`lib/screens/settings/tour_preferences_screen.dart`, `comingSoon: true`).
  Disabled; TTS uses the device's default voice. Real voice selection is
  OS/device-dependent.
- **Saved tab → "Offline" & "Curated" filter chips**
  (`lib/screens/saved/saved_screen.dart`, `_stubFilters = {2, 3}`). Chips are
  disabled; only the working filters function. The playlist-category grid
  (Museums/Temples/…) is decorative too.
- **Narration subtitles** — the subtitle toggle/voices area is display-only.
  TTS narration itself works; the on-screen subtitle options are not wired.

To "finish" these: either wire the real feature, or hide the control so nothing
reads as unfinished. 

---

## 3. OS push notifications (tried, then removed)

In-app celebratory **SnackBars** fire on three events (tour designed, tour
complete, AI film ready) and work fine. We prototyped real **OS notifications**
(`flutter_local_notifications`) with the app logo as the badge, but removed the
whole pipeline — the permission flow wasn't behaving reliably in the time we had.

If revisited, the notes that matter:
- Request the permission **after the first frame** (a live Activity must exist);
  requesting it in `main()` before `runApp()` never shows the dialog.
- Needs core-library **desugaring** in `android/app/build.gradle.kts` and the
  `POST_NOTIFICATIONS` manifest permission.
- Use a monochrome status-bar icon (Android silhouettes the launcher icon).

---

## 4. Other known deferrals

- **Broader device coverage** — the store APK is `--split-per-abi` **arm64-v8a**
  only (~43 MB). It covers virtually every modern phone (Android 7.0+, 64-bit) but
  not 32-bit (`armeabi-v7a`) or x86 devices. Build those splits too if wider
  coverage is ever needed.


