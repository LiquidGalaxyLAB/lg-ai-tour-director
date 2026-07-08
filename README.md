# LG AI Tour Director

<img width="3375" height="3375" alt="image" src="https://github.com/user-attachments/assets/a9676877-a9b9-4f1c-a345-fc00a6142e27" />

<p align="center">
  <b>AI-powered cinematic geographic tours for the Liquid Galaxy rig.</b><br/>
  Type a prompt, get a narrated, flown-through tour on Google Earth — generated entirely on-device.
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
- [Screenshots](#screenshots)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Configuring an AI model](#configuring-an-ai-model)
  - [Connecting to Liquid Galaxy](#connecting-to-liquid-galaxy)
- [Project Structure](#project-structure)
- [Roadmap](#roadmap)
- [Mentors](#mentors)
- [Author](#author)
- [Acknowledgements](#acknowledgements)

---

## About

**Tour Director** is a **pure-Flutter** application that turns a single natural-language
prompt — for example *"historical places in Pune"* or *"exciting spots to visit in Dubai"* —
into an **immersive, narrated, cinematic tour** on a **Liquid Galaxy** rig.

The user describes a place or theme; an AI model extracts the most fitting real-world
locations; the app geocodes them, fetches imagery, builds the camera paths, and flies the
rig's Google Earth through each landmark while narrating the journey on the device. An
**on-device companion** view keeps the phone in sync with the rig, and every tour can be
**saved, replayed, and exported as KML**.

There is **no backend**. Everything — the AI calls, geocoding, image resolution, KML, and
SSH control of the rig — runs inside the Flutter app. The app talks directly to the LLM
provider, mapping/imagery services, and the Liquid Galaxy master over SSH.

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
```

1. **Prompt → locations.** The prompt is sent to a configured LLM, which infers the
   *intent* behind it (fun / historical / scenic / foodie …) and returns 4–6 fitting,
   real, geographically distinct landmarks plus a short tour title.
2. **Enrichment.** Each location is geocoded (native geocoder with an OpenStreetMap
   fallback) and matched with an image (Wikipedia → Unsplash → a themed fallback).
3. **Preview.** The user previews the tour, then starts it on the rig.
4. **Flight.** The app drives the rig's Google Earth camera through a cinematic path
   (opening overview → approach → 360° orbit per landmark) and shows an **info card** on
   the right-most screen for each stop.
5. **Companion + narration.** The phone mirrors the tour scene-by-scene with narration
   (text-to-speech) and subtitles, paced to stay in sync with the rig.
6. **After the tour.** Save it to your library, replay it on the rig later, or export/share
   the KML.

---

## Features

**AI tour generation**
- Natural-language prompt → curated, intent-aware set of real landmarks + a short tour title.
- **Bring-your-own model** — works with **any OpenAI-compatible endpoint**: OpenRouter,
  a local **Ollama** / **LM Studio** server, **Groq**, **Together.ai**, and more. One-tap
  presets and a "Test Connection" check.
- Clear, actionable error messages (bad key, out of credit, wrong model, rate limit) with
  an in-app **AI Setup Guide**.
- Voice input — dictate the prompt with on-device speech-to-text.

**Location & media**
- Geocoding via the platform's native geocoder with an OpenStreetMap (Nominatim) fallback.
- Image resolution chain: Wikipedia → Unsplash → a thematic fallback, cached per location.
- Images shown both **in the app** and **on the rig**.

**Liquid Galaxy control (over SSH)**
- Connect to the rig from the app; **auto-sends the logo** to the left-most screen on connect
  and **clears it on disconnect**.
- Cinematic camera flight through each landmark (opening overview, approach, and orbit).
- **Info card** deployed to the right-most screen per stop (image + title + description),
  rendered on-device and shown as a pixel-perfect, undistorted overlay.
- **Advanced controls**: Relaunch / Reboot / Shutdown, Set / Reset Refresh, Send / Clear
  Logo, plus developer test actions.
- Robust SSH handling: auto-reconnect, clean teardown, and a proper **End Tour** that stops
  the rig and clears the overlays.

**On-device experience**
- Companion tour view (current scene, narration subtitles, live progress) paced to the rig.
- **"Return to tour" banner** — leave the tour screen and the tour keeps running on the rig;
  a persistent banner with live progress brings you back.
- **Saved** library (persisted) and **Tours** history; replay on the rig, or export / share
  the KML from the device.
- A celebratory **post-tour recap** (Thank You + Save KML).
- Light and dark themes, branded app icon and splash.

---

## Screenshots

<img width="489" height="752" alt="image" src="https://github.com/user-attachments/assets/b7cf33a0-f8ef-4928-9fae-7359fc3043be" />

---

## Architecture

Tour Director is **Flutter-first with no server**. The APK contains everything:

- **AI** — the app calls the configured LLM endpoint directly (OpenAI-compatible
  `/chat/completions`). Testers supply their own base URL + key + model.
- **Geocoding & media** — native geocoder / OpenStreetMap, Wikipedia and Unsplash, all
  called from the app.
- **KML & flight** — camera views and info-card overlays are built as KML on-device and
  deployed to the rig's web root.
- **Rig control** — SSH / SFTP straight to the Liquid Galaxy master; the camera is driven
  via the proven `flytoview=` query hook.

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
| Narration | flutter_tts · speech_to_text |
| Geocoding | geocoding · OpenStreetMap (Nominatim) |
| Storage | shared_preferences |
| Sharing | share_plus · url_launcher |
| UI | google_fonts (Plus Jakarta Sans) |

---

## Getting Started

### Prerequisites

- **Flutter 3.41+** and **Dart 3.11+** ([install guide](https://docs.flutter.dev/get-started/install))
- An **Android device or emulator** (recommended for the SSH / rig features)
- A **Liquid Galaxy** rig (3, 5, or 7 screens) reachable on the same network
- An **API key** for any OpenAI-compatible AI provider (e.g. [OpenRouter](https://openrouter.ai)),
  or a local model (Ollama / LM Studio)

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
```

### Configuring an AI model

Open **Settings → AI Configuration** and either tap a **preset** or enter your own:

| Field | Example |
|-------|---------|
| API Base URL | `https://openrouter.ai/api/v1` (or `http://localhost:11434/v1` for Ollama) |
| API Key | your provider key (leave empty for local models) |
| Model ID | `deepseek/deepseek-chat`, `openai/gpt-4o-mini`, `llama3`, … |

Tap **Test Connection**, then **Save**. That's it — no key ships in the app.

### Connecting to Liquid Galaxy

1. Make sure your phone and the rig are on the **same network** (VirtualBox rigs: use a
   **Bridged** adapter).
2. **Settings → LG Connection** → enter the master **IP**, **port** (default `22`), **username**
   / **password** (default `lg` / `lg`), and the **screen count**.
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
│   ├── models/          # tour, location, saved-tour models
│   ├── providers/       # Riverpod state (SSH, tour, theme, library)
│   ├── services/        # LLM client, media (Wikipedia/Unsplash), geocoding
│   ├── lg/              # LGService + SSH client (rig control)
│   ├── kml/             # camera views, info-card + logo overlays
│   ├── screens/         # home, generation, preview, active tour, saved, settings…
│   └── shared/          # reusable widgets
└── assets/              # logos, icon, .env
```

---

## Roadmap

Planned / in-progress work beyond the midterm:

- Real **Google Maps** preview (currently a branded placeholder).
- **AI film export** (Veo) with an in-app video player.
- Live KML-driven active tour + richer scene control (Pause / Skip).
- Re-enabling location auditing once geocoding coverage is consistent.
- Additional narration voices, subtitles, and language options.

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
