# 🗺️ Gyeongju Hanjeok Frontend

> Flutter client for 경주한적 — a map-first travel app that turns real-time congestion-aware course recommendations into a day of quiet sightseeing around Gyeongju.

<br>

## Overview

This app is the mobile client for the Gyeongju Hanjeok backend. It lets a user sign up, get a congestion-aware course recommendation, adjust that course by chatting in natural language, follow it on a map, check in at each stop with a QR scan, and share the trip with friends through a community feed — all backed by the FastAPI service in [`../backend`](../backend).

<br>

## Approach

* **Structure**: screens own UI only; `AppController` (a single `ChangeNotifier`, exposed app-wide via an `AppScope` inherited widget) holds app state; `AppRepository` talks to the backend through `ApiClient` (Dio); `LocationService` and `StorageService` wrap device GPS and local persistence
* **Entry point**: `main.dart` stays thin — it loads `.env`, initializes the Kakao SDK, locks portrait orientation, wires up `AppController`, and hands off to `AppShell`/`LoginScreen`
* **Navigation flow**: `main.dart` → `_AppBootstrap` picks between a loading screen, `LoginScreen`, a fatal-error screen, or the authenticated `AppShell` (bottom-tab shell around home/map/course/chatbot/community)
* **Backend integration**: reads `BACKEND_BASE_URL` from `.env` at runtime, so the same build can point at a local server, LAN IP, or a deployed Railway instance
* **Kakao integration**: Kakao Flutter SDK for map navigation hand-off and native share/invite links
* **Visit verification**: QR scanning (`mobile_scanner`) and QR generation (`qr_flutter`) for on-device check-in, matching the backend's GPS-free visit-completion policy

<br>

## Results

* **Home** — category browsing and "currently less crowded" place suggestions
* **Map** — course stops plotted on a map with live navigation hand-off to Kakao
* **Course** — congestion-aware course recommendation, natural-language editing, and mid-trip recalculation
* **Chatbot** — conversational course editing and cultural-etiquette Q&A
* **Community** — course-review / live-crowd-report / travel-log posts, comments, recommendations, and "follow this course"
* **Saved places / saved courses** — bookmarking for later
* **QR check-in** — on-site visit verification without exposing GPS to the backend
* **Auth & consent** — signup, login, terms/privacy/location/notification consent screens
* **My page & notifications** — profile, completed trips, friends, and app notifications

<br>

## Tech Stack

### Languages  ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)

### Framework  ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)  ![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white)

### Networking & State  ![Dio](https://img.shields.io/badge/Dio-0175C2?style=flat-square&logoColor=white)  ![flutter_dotenv](https://img.shields.io/badge/flutter__dotenv-02569B?style=flat-square&logoColor=white)

### Integrations  ![Kakao](https://img.shields.io/badge/Kakao-FFCD00?style=flat-square&logo=kakaotalk&logoColor=000000)  ![Geolocator](https://img.shields.io/badge/Geolocator-4285F4?style=flat-square&logoColor=white)  ![WebView](https://img.shields.io/badge/WebView-4285F4?style=flat-square&logoColor=white)

### Development & Environment  ![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)  ![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)  ![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=flat-square&logo=visualstudiocode&logoColor=white)

<br>

## Project Structure

```text
frontend/
├── lib/
│   ├── main.dart              # app entry point (thin: env, Kakao SDK, bootstrap)
│   ├── core/                  # env access, theme, legal document text
│   ├── models/                # place, route_plan, community, friend, chat_message, ...
│   ├── screens/                # one file per screen (home, map, course, chatbot, community, ...)
│   ├── services/               # api_client, app_repository, chat_repository, location, storage, kakao_invite
│   ├── state/                  # app_controller.dart (single ChangeNotifier app state)
│   ├── widgets/                # shared UI components
│   └── data/                   # bundled preview/sample data for offline UI states
├── assets/                     # fonts (MaruBuri, WantedSans), images, icon, splash
├── android/                    # Gradle project, signing config
└── README.md
```

<br>

## Notes

### Getting Started

```bash
cp .env.example .env   # fill in BACKEND_BASE_URL and the Kakao keys
flutter pub get
flutter run
```

Backend connection address by target:

* Android emulator: `http://10.0.2.2:8000`
* iOS simulator: `http://127.0.0.1:8000`
* Physical device: `http://<PC's LAN IP>:8000`

### Environment Variables (`.env`)

| Key | Purpose |
| --- | --- |
| `APP_MODE` | build/runtime mode flag |
| `BACKEND_BASE_URL` | base URL of the FastAPI backend |
| `BACKEND_CONTRACT` | which backend route contract to target (`/api/v1/...` vs. compat aliases) |
| `KAKAO_JAVASCRIPT_KEY`, `KAKAO_MAP_BASE_URL`, `KAKAO_NATIVE_APP_KEY` | Kakao SDK / map integration |
| `DEFAULT_LATITUDE`, `DEFAULT_LONGITUDE` | fallback map center before GPS is available |
| `CONGESTION_REFRESH_MINUTES` | client-side polling interval for congestion refresh |

### Android Release Signing

The signing config is intentionally kept out of git. To build a release APK/AAB locally:

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Generate or place your release keystore (`.jks`) next to it, matching `storeFile` in `key.properties`.
3. Fill in `storePassword`, `keyPassword`, and `keyAlias`.

`android/key.properties` and `*.jks` stay gitignored — see the root [`README.md`](../README.md) for the full list of files excluded from the repository.

### Known Limitations

* The app deliberately never sends the user's live GPS coordinate to the backend for course/place requests — see the backend's [GPS / Location Privacy Policy](../backend/README.md#gps--location-privacy-policy). GPS is only used locally for map centering, sorting, and QR/on-device visit verification.
* `.env` is bundled as a Flutter asset (`flutter.assets: - .env`) so it can be read at runtime via `flutter_dotenv`; this means a release build embeds whatever is in `.env` at build time, so no production secret should be a client-only key without backend-side scoping.

<br>

## License

Copyright © 2026 Hyunjin Hwang. All rights reserved.

This repository is provided for viewing and portfolio evaluation purposes only.

No permission is granted to copy, modify, distribute, sublicense, publish, or commercially use any part of this project, including its source code, assets, documentation, design, or other contents, without prior written permission from the copyright holder.

If you want to use this project or any portion of it, please obtain written permission from the repository owner in advance.
