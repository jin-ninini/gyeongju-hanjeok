# 📌 Gyeongju Hanjeok (경주한적)

> AI travel service that treats real-time congestion as a constraint and recommends quiet, less-crowded courses around Gyeongju.

**Service**: https://onesto.re/0001009267

<br>

## Overview

Visitors to Gyeongju crowd into the same attractions at predictable times, and that congestion drives down trip satisfaction. Gyeongju Hanjeok combines live public and commercial APIs with community crowd reports to generate courses that reflect weather, congestion, distance, and preference. Users then adjust a course mid-trip through chatbot conversation alone.

<br>

## Approach

- **Data**: Korea Tourism Organization APIs (tourism info, visitor concentration forecast, related/hub attractions, photo gallery), KMA short-term forecast, Kakao Local/Navi, Naver Search/DataLab, YouTube Data API, and community live crowd reports
- **Processing**: Congestion score blends official concentration data, time of day, Naver popularity, weather, and regional adjustment; community reports add a separate, capped signal
- **Model**: NSGA-II multi-objective optimizer generates course candidates; an OpenAI-embedding RAG answers place and heritage questions from synced official content
- **Architecture**: FastAPI backend (courses, auth, community, friends, notifications, admin) with a Flutter Android client (map, chatbot, community, QR check-in)

<br>

## Results

| Feature | Endpoint | Behavior | Requires (`.env`) |
|---|---|---|---|
| Course recommendation | `POST /api/v1/courses/recommend` | Returns 1-3 candidates scored by quietness 45%, preference 30%, distance 25% | `PUBLIC_DATA_SERVICE_KEY`, `KMA_SERVICE_KEY`, `KAKAO_REST_API_KEY`, `NAVER_CLIENT_ID/SECRET` |
| Natural-language editing | `POST /api/v1/courses/modify` | Excludes, adds, replaces, or reorders places from a chat request | Course recommendation keys, `OPENAI_API_KEY` |
| Mid-trip recalculation | `POST /api/v1/courses/recalculate` | Finds an alternative when the next stop's congestion exceeds 8 | `PUBLIC_DATA_SERVICE_KEY` |
| Visit check-in | `POST /api/v1/journeys/{id}/visits` | Completes a visit from on-device QR verification, without sending GPS | Course recommendation keys (to start a journey) |
| Heritage Q&A | `POST /api/v1/rag/search` | Searches synced official tourism content semantically | `OPENAI_API_KEY`, `PUBLIC_DATA_SERVICE_KEY` |
| Push notifications | `/notifications/device-tokens` | Sends Firebase push notifications to registered devices | `FIREBASE_PROJECT_ID`, `FIREBASE_SERVICE_ACCOUNT_JSON` |
| Password reset | `/auth/password-reset` | Emails a reset code through the Gmail API | `GMAIL_CLIENT_ID/SECRET`, `GMAIL_REFRESH_TOKEN` |
| Auth & community | `/auth`, `/community` | Handles signup, login, posts, comments, and live crowd reports | None |

- Features with keys listed above return 503 or stay disabled until those keys are set in `backend/.env`
- The backend never receives the user's live GPS coordinate; requests use a fixed Gyeongju service anchor
- Community live reports influence routing by at most 20%, so the official congestion score is never overwritten
- Friends, shared routes, notifications, and an admin API run alongside the course engine without extra keys

<!-- Add app screenshots or course recommendation images here. -->

<br>

## Tech Stack

| Category | Stack |
|---|---|
| Languages | ![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)  ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white) |
| Backend | ![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)  ![Uvicorn](https://img.shields.io/badge/Uvicorn-2A9D8F?style=flat-square&logoColor=white)  ![Pydantic](https://img.shields.io/badge/Pydantic-E92063?style=flat-square&logo=pydantic&logoColor=white)  ![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-D71F00?style=flat-square&logo=sqlalchemy&logoColor=white) |
| Mobile | ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)  ![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white) |
| NLP & LLM | ![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=flat-square&logo=openai&logoColor=white) |
| External APIs | ![Kakao](https://img.shields.io/badge/Kakao-FFCD00?style=flat-square&logo=kakaotalk&logoColor=000000)  ![Naver](https://img.shields.io/badge/Naver-03C75A?style=flat-square&logo=naver&logoColor=white)  ![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white)  ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)  ![Gmail](https://img.shields.io/badge/Gmail%20API-EA4335?style=flat-square&logo=gmail&logoColor=white) |
| Database | ![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)  ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white) |
| Development & Environment | ![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)  ![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)  ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)  ![pytest](https://img.shields.io/badge/pytest-0A9EDC?style=flat-square&logo=pytest&logoColor=white)  ![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=flat-square&logoColor=white) |

<br>

## Project Structure

```text
gyeongju-hanjeok/
├── backend/                  # FastAPI server
│   ├── app/                  # API routers, services, optimizer, external API clients
│   ├── tests/                # pytest suite
│   ├── scripts/              # Config check, smoke test, SQLite → PostgreSQL migration
│   ├── data/                 # Local SQLite DB (gitignored)
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── README.md             # Backend guide and full API reference
├── frontend/                 # Flutter app
│   ├── lib/                  # Screens, state, services, models
│   ├── assets/               # Fonts, images, icon, splash
│   ├── android/              # Android build and signing config
│   └── README.md             # Frontend guide
└── README.md
```

<br>

## Getting Started

Requires Python 3.12+ and a Flutter SDK with Dart 3.10+.

```bash
# Backend
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                # Fill in the API keys
python -m scripts.check_config                      # Shows which keys are configured
python -m uvicorn app.main:app --reload             # API docs at http://127.0.0.1:8000/docs
```

```bash
# Backend with Docker (reads backend/.env)
cd backend
docker compose up --build
```

```bash
# Frontend
cd frontend
cp .env.example .env                                # Set BACKEND_BASE_URL and Kakao keys
flutter pub get
flutter run                                         # Android emulator or device
```

- The server starts without any keys; see the `Requires (.env)` column in [Results](#results) for what each feature needs
- Use `http://10.0.2.2:8000` as `BACKEND_BASE_URL` on the Android emulator and the PC's LAN IP on a physical device
- See [`backend/README.md`](backend/README.md) for required API applications and the full endpoint list, and [`frontend/README.md`](frontend/README.md) for release signing

<br>

## Notes

- Tourism API fields differ by attraction type, so operating hours and admission fees merge from whatever fields exist
- Official APIs provide no reviews or ratings, so the review term stays at a neutral 0.5 until a review provider is added
- Kakao walking directions need partner approval, so walking distance falls back to coordinates and walking speed
- Secrets (`.env`, `key.properties`, `*.jks`), local databases, and build artifacts stay out of the repository; only `.example` templates are committed

<br>

## License

Copyright © 2026 Hyunjin Hwang. All rights reserved.

This repository is provided for viewing and portfolio evaluation purposes only.

No permission is granted to copy, modify, distribute, sublicense, publish, or commercially use any part of this project, including its source code, assets, documentation, design, or other contents, without prior written permission from the copyright holder.

If you want to use this project or any portion of it, please obtain written permission from the repository owner in advance.
