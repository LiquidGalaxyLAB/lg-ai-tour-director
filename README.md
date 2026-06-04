## LG AI Tour Director 

<img width="3375" height="3375" alt="image" src="https://github.com/user-attachments/assets/a9676877-a9b9-4f1c-a345-fc00a6142e27" />


The project is an AI-powered cinematic tour generation system for Liquid Galaxy. A user can enter prompts like “historical places in Pune,” and the system automatically generates immersive tours with structured locations, KML camera paths, narration, subtitles, synchronized Google Maps preview, and an cinematic video export using Veo.

This system follows a Flutter-first architecture. The application directly communicates with Gemini, Google Maps APIs, Wikimedia Commons, and Liquid Galaxy. Tour generation, validation, KML generation, and deployment are handled entirely inside the Flutter application.

## Repository Structure

```text
lg-ai-tour-director/
├─ .env                # local environment (ignored)
├─ .env.example        # example env variables to copy
├─ .gitignore
├─ docs/               # design docs, API spec, deployment notes
├─ assets/             # logos, sample KMLs, demo prompts
├─ scripts/            # helper scripts for local dev and deployment
├─ shared/             # JSON schemas and shared assets
├─ plan-proposal/      # GSoC proposal and planning notes
├─ .github/            # CI workflows (Flutter CI)
└─ flutter_app/        # Flutter frontend
   ├─ pubspec.yaml
   ├─ lib/
   │  ├── features/
   │  ├── services/
   │  │   ├── gemini/
   │  │   ├── maps/
   │  │   ├── media/
   │  │   ├── validation/
   │  │   ├── geojson/
   │  │   ├── storage/
   │  │   ├── tts/
   │  │   └── veo/          (future)
   │  ├── kml/
   │  │   ├── generator.dart
   │  │   ├── assembler.dart
   │  │   └── scenes/
   │  ├── lg/
   │  │   ├── ssh_client.dart
   │  │   ├── deployment.dart
   │  │   ├── relaunch.dart
   │  │   ├── reboot.dart
   │  │   ├── shutdown.dart
   │  │   └── logo.dart
   │  ├── models/
   │  │   ├── tour.dart
   │  │   ├── scene.dart
   │  │   ├── location.dart
   │  │   ├── narration.dart
   │  │   └── rig_config.dart
   │  ├── repositories/
   │  │   ├── tour_repository.dart
   │  │   ├── lg_repository.dart
   │  │   ├── maps_repository.dart
   │  │   └── library_repository.dart
   │  └── shared/
   └─ test/
```

