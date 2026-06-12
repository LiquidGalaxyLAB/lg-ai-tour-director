# Worklog: Week 1

## Pure-Flutter Architecture Decision
After reviewing the initial project proposal, we decided to pivot from a Client-Server (Flutter + FastAPI) architecture to a **Pure-Flutter** (Flutter-first) architecture. 

**Rationale:**
- **Simplicity:** Managing a separate backend deployment for the Liquid Galaxy system introduces unnecessary complexity. An enterprise application might benefit from Serverpod or FastAPI, but for this GSoC project, keeping everything within the Dart ecosystem inside the main Flutter app is the best approach.
- **Direct Communication:** The Flutter app now directly communicates with all external services (Google Gemini API, Google Maps Geocoding/Places APIs, Wikimedia Commons) and controls the Liquid Galaxy rig over SSH.
- **Maintainability:** A single codebase is easier to maintain and deploy, removing the need for Docker containers and server hosting. 

## RigConfig Design Rationale
We introduced the `RigConfig` model to accurately represent the physical Liquid Galaxy screen layout. 

**Rationale:**
- **Dynamic Calculation:** The `RigConfig.fromScreenCount(int n)` factory dynamically calculates the center screen, left-wing screens, and right-wing screens for any odd number of screens (e.g., 3, 5, 7).
- **Nearest-to-Center Ordering:** The wings are ordered from nearest-to-center to the outermost screens (e.g., for a 5-screen rig: Left=[2,1], Right=[4,5]). This is crucial for properly placing elements like info balloons and logos, which typically go on the outermost screens (`leftScreens.last` and `rightScreens.last`).
- **Flexibility:** Since developers may not have access to a full 5 or 7 screen rig (often testing on 3 screens or single Ubuntu VMs), this model allows for accurate simulation and validation of the screen assignment logic without relying on auto-detection or hardcoded values. Users manually select their screen count in the LG Connection Settings, and `RigConfig` handles the rest.
