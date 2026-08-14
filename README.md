<p align="center">
  <img src="Banner.png" alt="AI Tour Director" width="100%"/>
</p>

<p align="center">
  <b>AI-powered cinematic geographic tours for the Liquid Galaxy rig.</b><br/>
  Type a prompt, get a narrated, flown-through tour on Google Earth — and an optional AI-generated film of it — all on-device.
</p>

<p align="center">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.41-02569B?logo=flutter&logoColor=white"/>
  <img alt="Dart" src="https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white"/>
  <img alt="Material 3" src="https://img.shields.io/badge/Material%203-757575?logo=materialdesign&logoColor=white"/>
  <img alt="Riverpod" src="https://img.shields.io/badge/State-Riverpod%203-4c51bf"/>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20Web-3DDC84?logo=android&logoColor=white"/>
  <img alt="GSoC 2026" src="https://img.shields.io/badge/GSoC-2026-F9AB00?logo=googlesummerofcode&logoColor=white"/>
  <img alt="Liquid Galaxy" src="https://img.shields.io/badge/Liquid%20Galaxy-Org-4285F4"/>
</p>

---

## Table of Contents

- [About](#about)
- [How It Works](#how-it-works)
- [Features](#features)
- [The AI Film Pipeline](#the-ai-film-pipeline)
- [Gallery](#gallery)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuring an AI model](#configuring-an-ai-model)
  - [Configuring the AI Film (video)](#configuring-the-ai-film-video)
  - [Connecting to Liquid Galaxy](#connecting-to-liquid-galaxy)
- [Project Structure](#project-structure)
- [Roadmap](#roadmap)
- [GSoC 2026](#gsoc-2026)
- [Mentors](#mentors)
- [Author](#author)
- [Acknowledgements](#acknowledgements)

---

## About

**Tour Director** is a **pure-Flutter** application that turns a single natural-language
prompt — for example *"historical places in Pune"* or *"exciting spots to visit in Dubai"* —
into an **immersive, narrated, cinematic tour** on a **Liquid Galaxy** rig, and can then
generate an **AI film** of that tour.

The user describes a place or theme; an AI model extracts the most fitting real-world
locations; the app geocodes them, fetches imagery, builds the camera paths, and flies the
rig's Google Earth through each landmark while narrating the journey on the device. An
**on-device companion** view keeps the phone in sync with the rig, and every tour can be
**saved, replayed, exported as KML**, or turned into a short **AI-generated cinematic film**.

There is **no backend**. Everything — the AI calls, geocoding, image resolution, KML,
SSH control of the rig, and on-device video stitching — runs inside the Flutter app. The
app talks directly to the LLM provider, the mapping/imagery services, the video provider,
and the Liquid Galaxy master over SSH. Users bring their own API keys, which never leave
the device.

> Built for **Google Summer of Code 2026** with the **Liquid Galaxy** organisation.

---

## How It Works

```
Prompt  ─▶  AI model        ─▶  Geocoding        ─▶  Media           ─▶  KML + camera
 "..."      (locations +        (coordinates for      (Wikipedia →        (fly-to views,
            a tour title)        each landmark)        Unsplash →          info balloons)
                                                       themed fallback)
                                                                             │
                                       On-device companion  ◀────────────────┤
                                       (scene stepping,                      ▼
                                        narration, subtitles)         Liquid Galaxy rig
                                                                      (Google Earth flight
                                                                       + logo + info card)
                                                                             │
                                                            Optional ▼
                                                       AI Film (per-location clips →
                                                       FFmpeg stitch → save + play)
```

1. **Prompt → locations.** The prompt is sent to a configured LLM, which infers the
   *intent* behind it (fun / historical / scenic / foodie …) and returns 4–6 fitting,
   real, geographically distinct landmarks plus a short tour title and a rich narration.
2. **Enrichment.** Each location is geocoded (native geocoder with an OpenStreetMap
   fallback) and matched with an image (Wikipedia → Unsplash → a themed fallback).
3. **Preview.** The user previews the tour on an interactive map, then starts it on the rig.
4. **Flight.** The app drives the rig's Google Earth camera through a cinematic path
   (opening overview → approach → smooth 360° orbit per landmark) and shows an **info card**
   on the right-most screen for each stop.
5. **Companion + narration.** The phone mirrors the tour scene-by-scene with narration
   (text-to-speech) and subtitles, paced to stay in sync with the rig.
6. **After the tour.** Save it to your library, replay it on the rig later, export/share the
   KML — or generate an **AI film** of the tour and play it in your device's video player.

---

## Features

**AI tour generation**
- Natural-language prompt → curated, intent-aware set of real landmarks + a short tour title.
- **Bring-your-own model** — works with **any OpenAI-compatible endpoint**: OpenRouter,
  a local **Ollama** / **LM Studio** server, **Groq**, **Together.ai**, and more. One-tap
  presets and a "Test Connection" check.
- Rich, unified narration — the same text is spoken on the phone and shown on the rig's info card.
- Clear, actionable error messages (bad key, out of credit, wrong model, rate limit) with
  an in-app **AI Setup Guide**.
- Voice input — dictate the prompt with on-device speech-to-text.

**Location & media**
- Geocoding via the platform's native geocoder with an OpenStreetMap (Nominatim) fallback.
- Image resolution chain: Wikipedia → Unsplash → a thematic fallback, cached per location.
- Images shown both **in the app** and **on the rig**.

**Liquid Galaxy control (over SSH)**
- Connect to the rig from the app, or **scan a QR code** to fill the connection details.
  The logo is **auto-sent** to the left-most screen on connect and **cleared on disconnect**.
- Cinematic camera flight through each landmark (opening overview, approach, and a smooth
  full 360° orbit).
- **Info card** deployed to the right-most screen per stop (image + title + description),
  rendered on-device and shown as a pixel-perfect, undistorted overlay.
- **Advanced controls**: Relaunch / Reboot / Shutdown, Set / Reset Refresh, Send / Clear
  Logo, plus a debug-only developer test suite.
- Robust SSH handling: one persistent connection, auto-reconnect, clean teardown, and a
  proper **End Tour** that stops the rig and clears the overlays.

**On-device experience**
- Companion tour view (current scene, narration subtitles, live progress) paced to the rig.
- **"Return to tour" banner** — leave the tour screen and the tour keeps running on the rig;
  a persistent banner with live progress brings you back. A separate banner restores a
  *generated-but-not-yet-started* tour if you navigate away.
- **Saved** library (persisted) and **Tours** history (every run).
  - Saved detail includes a **full-screen swipeable Highlights Gallery** of every stop.
  - Tours history includes a **details view** and a one-tap **Generate again**.
  - Replay a saved tour on the rig, or export / share its KML from the device.
- An in-app **sample film showcase** on Home, and a celebratory **post-tour recap**.
- **8 languages** (English, Spanish, French, German, Portuguese, Hindi, Arabic, Chinese)
  with runtime switching.
- Light and dark themes, branded app icon and splash.

**AI Film (AI-generated video)**
- Turns a completed tour into a short cinematic video — one AI clip per location, stitched
  together on-device with FFmpeg.
- **Multiple providers**, bring-your-own key — see [The AI Film Pipeline](#the-ai-film-pipeline).
- **Robust to failures**: if a provider runs out of credits mid-way, it stops spending and
  still stitches the clips it produced, with a clear message. Cancelling never keeps spending.
- Saves to the phone Gallery and plays back in the device's **native video player** (any format).
- A one-tap **"Test AI Film"** runs the whole pipeline on 3 sample locations — no rig needed.

---

## The AI Film Pipeline

The AI Film feature generates a short cinematic clip for each location, then stitches them
into a single film — entirely on-device.

- **Bring-your-own API key.** The user supplies their own video-provider key; it stays on
  the device and any cost is billed directly by the provider.
- **On-device stitching** with FFmpeg (no re-encode) — no server involved.
- **Native playback** — the finished film opens in whatever video app the device has
  (Google Photos, MX Player, VLC), full-screen with proper controls.

**Supported providers** (approx. cost, 720p, verified Aug 2026 — billed by the provider):

| Provider / model | Approx. cost | Notes |
|---|---|---|
| **fal.ai — LTX Video** | ~$0.02 / clip | Cheapest — best for testing |
| **fal.ai — MiniMax Hailuo 02** | ~$0.045 / s | Good balance |
| **fal.ai — WAN 2.2** | ~$0.08 / s | Open-source model |
| **fal.ai — Kling v3** | ~$0.084 / s | Best quality — recommended for a demo |
| **Google Veo 3** | $0.40 / s (Fast $0.15/s) | Native audio; needs Google Cloud billing |
| **Runway Gen-4 Turbo** | ~$0.05 / s | |
| **Kling (direct API)** | ~$0.09 / s | Prepaid packages |
| **Local (vLLM-Omni)** | **Free** | Your own NVIDIA GPU |

See [Configuring the AI Film (video)](#configuring-the-ai-film-video) for setup steps.

---

## Gallery

> _Rig photos and demo captures are being added — space reserved below._

<!-- ───────────────────────── RIG SCREENSHOTS (add after rig test) ─────────────────────────
     Drag each photo into a GitHub issue/PR comment to get a hosted URL, then paste it here.
-->
<!-- RIG PHOTO 1 — full tour on the 3-screen rig -->
<!-- ![Tour on the Liquid Galaxy rig](PASTE_URL_HERE) -->

<!-- RIG PHOTO 2 — info balloon + logo overlay -->
<!-- ![Info card + logo on the rig](PASTE_URL_HERE) -->

**App screenshots**

<img width="489" alt="Tour Director app" src="https://github.com/user-attachments/assets/b7cf33a0-f8ef-4928-9fae-7359fc3043be" />

**AI Film samples**

<!-- Drag an .mp4 into a GitHub issue/PR comment to get a playable URL, then paste it here. -->
<!-- https://github.com/user-attachments/assets/PASTE_VIDEO_URL_HERE -->
<!-- AI FILM SAMPLE 1 -->
<!-- AI FILM SAMPLE 2 -->

---

## Architecture

Tour Director is **Flutter-first with no server**. The APK contains everything:

- **AI (text)** — the app calls the configured LLM endpoint directly (OpenAI-compatible
  `/chat/completions`). Testers supply their own base URL + key + model.
- **AI (video)** — a provider-agnostic layer (fal.ai, Veo 3, Runway, Kling, local vLLM,
  custom) generates per-location clips; FFmpeg stitches them on-device.
- **Geocoding & media** — native geocoder / OpenStreetMap, Wikipedia and Unsplash, all
  called from the app.
- **KML & flight** — camera views and info-card overlays are built as KML on-device and
  deployed to the rig's web root; the camera is driven via the proven `flytoview=` hook.
- **Rig control** — SSH / SFTP straight to the Liquid Galaxy master over one persistent
  connection.

State is managed with **Riverpod** and navigation with **go_router** (a four-tab shell:
Home · Saved · Tours · Profile). Persistence uses **SharedPreferences**.

---

## Tech Stack

| Area | Choice |
|------|--------|
| Framework | Flutter 3.41 · Dart 3.11 · Material 3 |
| State | Riverpod 3 (Notifier / code-gen) |
| Navigation | go_router (StatefulShellRoute) |
| Rig I/O | dartssh2 (SSH / SFTP) |
| Networking | dio |
| AI video | provider layer + ffmpeg_kit_flutter_new (on-device stitch) |
| Video playback | open_filex (native player) · video_player (in-app previews) |
| Narration | flutter_tts · speech_to_text |
| Geocoding | geocoding · OpenStreetMap (Nominatim) |
| Media save | saver_gallery |
| QR | mobile_scanner |
| Localization | easy_localization (8 languages) |
| Storage | shared_preferences |
| Sharing | share_plus · url_launcher |
| UI | google_fonts (Plus Jakarta Sans) |

---

## Getting Started

### Prerequisites

- **Flutter 3.41+** and **Dart 3.11+** ([install guide](https://docs.flutter.dev/get-started/install))
- An **Android device or emulator** (recommended for the SSH / rig / video features)
- A **Liquid Galaxy** rig (3, 5, or 7 screens) reachable on the same network
- An **API key** for any OpenAI-compatible AI provider (e.g. [OpenRouter](https://openrouter.ai)),
  or a local model (Ollama / LM Studio)
- *(Optional, for AI Film)* a video-provider key (e.g. [fal.ai](https://fal.ai)) or a local GPU

### Installation

```bash
git clone https://github.com/KabirKhanuja/lg-ai-tour-director.git
cd lg-ai-tour-director/flutter_app

flutter pub get
flutter run          # pick your Android device / emulator
```

To build a release APK:

```bash
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk

# Or a leaner per-architecture APK (recommended for distribution):
flutter build apk --split-per-abi
```

### Configuring an AI model

Open **Settings → AI Configuration** and either tap a **preset** or enter your own:

| Field | Example |
|-------|---------|
| API Base URL | `https://openrouter.ai/api/v1` (or `http://localhost:11434/v1` for Ollama) |
| API Key | your provider key (leave empty for local models) |
| Model ID | `deepseek/deepseek-chat`, `openai/gpt-4o-mini`, `llama3`, … |

Tap **Test Connection**, then **Save**. No key ships in the app.

### Configuring the AI Film (video)

Open **Settings → AI Film**:

1. Turn **AI Film** on.
2. Pick a **provider** (fal.ai is the simplest — one key, many models).
3. Paste your **API key** and choose a **model** (LTX Video is cheapest for testing;
   Kling v3 is best for a demo).
4. Set the **clip duration** and **Save**.

To try it without running a full tour: **Settings → Advanced LG Controls → Test AI Film (3 clips)**.

### Connecting to Liquid Galaxy

1. Make sure your phone and the rig are on the **same network** (VirtualBox rigs: use a
   **Bridged** adapter).
2. **Settings → LG Connection** → enter the master **IP**, **port** (default `22`), **username**
   / **password** (default `lg` / `lg`), and the **screen count** — or tap **Scan QR to Connect**.
3. Tap **Connect** — the status dot turns green and the logo appears on the left-most screen.
4. Generate a tour on **Home**, preview it, then **Start** to fly it on the rig.

> If the logo or info card doesn't appear live, tap **Set Refresh** once in
> **Advanced LG Controls** (it enables live overlay updates on the slave screens).

---

## Project Structure

```
flutter_app/
├── lib/
│   ├── core/            # theme, routes, constants
│   ├── models/          # tour, location, saved-tour, video models
│   ├── providers/       # Riverpod state (SSH, tour, theme, library, AI film)
│   ├── services/        # LLM client, media (Wikipedia/Unsplash), geocoding, video providers
│   ├── lg/              # LGService + SSH client (rig control)
│   ├── kml/             # camera views, info-card + logo overlays
│   ├── screens/         # home, generation, preview, active tour, saved, tours, settings…
│   └── shared/          # reusable widgets
└── assets/              # logos, icon, translations, sample video, .env
```

---

## Roadmap

Planned / in-progress work:

- Generate the AI film **in parallel** with the tour, so it's ready by the time the tour ends.
- Live KML-driven active tour + richer scene control.
- Re-enabling location auditing once geocoding coverage is consistent.
- Live-testing the remaining video providers (fal.ai is verified end-to-end).
- Additional narration voices and subtitle options.

---

## GSoC 2026

> _Final deliverables are being finalised — space reserved below._

- **Demo Day video:** <!-- DEMO VIDEO LINK — add before submission -->
- **Work Product Submission:** <!-- WPS LINK — add before submission -->
- **Worklog:** maintained through the coding period.

---

## Mentors

- **Andreu Ibáñez** — Liquid Galaxy Org Director
- **Yash Raj Bharti**
- **Vedant Singh**

## Author

**Kabir Khanuja** — [github.com/KabirKhanuja](https://github.com/KabirKhanuja)

## Acknowledgements

Built for **Google Summer of Code 2026** with the **[Liquid Galaxy](https://www.liquidgalaxy.eu/)**
organisation. Thanks to the Liquid Galaxy community for the rig, tooling, and guidance.
