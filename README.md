# 📌 Gyeongju Hanjeok (경주한적)

> An AI service that treats real-time congestion as a constraint in course generation, recommending quiet, less-crowded travel courses around Gyeongju.

### Service: https://onesto.re/0001009267

<br>

## Overview

Gyeongju has clear time-of-day and day-of-week patterns in how visitors concentrate at specific attractions, so congestion has a major impact on trip satisfaction. Instead of dummy data, this project combines real APIs from the Korea Tourism Organization, the Korea Meteorological Administration, Kakao, Naver, YouTube, and OpenAI to automatically generate a travel course that reflects the user's current location, weather, real-time congestion, and preferences — and lets the course be adjusted mid-trip through chatbot conversation alone.

<br>

## Approach

* **Data used**: Korea Tourism Organization Korean tourism info (KorService1), forecasted visitor concentration rate (TatsCnctrRateService), related/hub attraction info, tourist photo gallery, KMA short-term forecast (VilageFcstInfoService_2.0), Kakao Local/Navi/Walking, Naver Search/DataLab, YouTube Data API
* **Core processing**: Treats congestion, weather, travel distance, and user preference as a multi-objective function and generates course candidates with NSGA-II; tourism text is embedded and searched semantically via RAG
* **Tech/architecture**: FastAPI backend (course recommend/modify/recalculate APIs, auth, community/friends/notifications, admin, push notifications, email-based password reset) + Flutter frontend (map, chatbot, community, QR check-in)
* **Overall approach**: When the congestion of the next destination exceeds a threshold, an alternative is automatically searched for; when the user makes a natural-language request such as "drop this place" or "add one more cafe," the chatbot instantly reconstructs the course

<br>

## Results

* Recommends 1-3 real-time courses based on location, weather, congestion, and preference (`/api/v1/courses/recommend`)
* Supports excluding, adding, replacing, and reordering places via natural language (`/api/v1/courses/modify`)
* Automatically finds an alternative when the next destination's congestion score exceeds 8 (`/api/v1/courses/recalculate`)
* Location-based etiquette guidance near cultural heritage sites; visit auto-completed after a 10-minute stay within 50m (QR check-in)
* Community, friend invites, completed-trip history, notifications, Firebase push notifications, Gmail-API password reset, and an admin API for managing users/reports/posts

<!-- Add screenshots or course recommendation result images here if needed. -->

<br>

## Tech Stack

### Languages  ![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)  ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)  ![SQL](https://img.shields.io/badge/SQL-4479A1?style=flat-square&logo=mysql&logoColor=white)

### Backend  ![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)  ![Uvicorn](https://img.shields.io/badge/Uvicorn-2A9D8F?style=flat-square&logoColor=white)  ![Pydantic](https://img.shields.io/badge/Pydantic-E92063?style=flat-square&logo=pydantic&logoColor=white)

### Frontend / Mobile  ![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)  ![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)  ![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white)

### External APIs & AI  ![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=flat-square&logo=openai&logoColor=white)  ![Kakao](https://img.shields.io/badge/Kakao-FFCD00?style=flat-square&logo=kakaotalk&logoColor=000000)  ![Naver](https://img.shields.io/badge/Naver-03C75A?style=flat-square&logo=naver&logoColor=white)  ![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white)  ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)  ![Gmail](https://img.shields.io/badge/Gmail%20API-EA4335?style=flat-square&logo=gmail&logoColor=white)

### Database  ![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)  ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)

### Development & Environment  ![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)  ![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)  ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)  ![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=flat-square&logo=visualstudiocode&logoColor=white)

<br>

## Project Structure

```text
gyeongju_hanjeok/
├── backend/            # FastAPI server
│   ├── app/            # API routers, services, domain logic
│   ├── tests/          # pytest tests
│   ├── scripts/        # smoke tests, DB migration, and other ops scripts
│   └── README.md       # backend setup/run guide
└── frontend/           # Flutter app
    ├── lib/            # screens, state, services, models
    ├── android/        # Android build config
    ├── assets/         # fonts, images, icons
    └── README.md       # frontend setup/run guide
```

<br>

## Notes

### Getting Started

```bash
# Backend
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
cp .env.example .env   # then fill in the keys
python -m uvicorn app.main:app --reload

# Frontend
cd frontend
cp .env.example .env   # then fill in BACKEND_BASE_URL, Kakao keys, etc.
flutter pub get
flutter run
```

See [`backend/README.md`](backend/README.md) for the API application steps and the full endpoint list.

### Files excluded from this repository

| Item | Reason |
| --- | --- |
| Loose `*.txt` files at the repo root | Personal working notes/planning docs kept outside `backend/` and `frontend/` |
| `.env`, `key.properties`, `*.jks` | API keys and signing secrets — only templates (`.env.example`, `key.properties.example`) are provided |
| `.venv/`, `build/`, `.dart_tool/`, `android/.gradle/`, `android/.kotlin/` | Regenerable local build/dependency artifacts |
| `backend/data/*.db` | Local SQLite database file |
| `backend/gyeongju-hanjeok-deploy/` | A separate deployment mirror with its own git history, managed independently |
| `flutter_lib_backups/`, `*.bak`, `*.zip`, `build_release_error.txt` | Empty backup folder, temporary backup/zip files, build error log |
| `frontend/.idea/` | IDE settings |

### Lessons learned / Future improvements

* Tourism API fields differ by attraction type, so operating hours and admission fees are merged from whatever fields are actually available
* The official APIs don't provide reviews or ratings, so the review term in the recommendation formula is fixed at a neutral 0.5 — it can be swapped out once a real review provider is chosen
* Kakao walking directions require partner approval, so the default falls back to coordinate-based distance and walking speed

<br>

## License

Copyright © 2026 Hyunjin Hwang. All rights reserved.

This repository is provided for viewing and portfolio evaluation purposes only.

No permission is granted to copy, modify, distribute, sublicense, publish, or commercially use any part of this project, including its source code, assets, documentation, design, or other contents, without prior written permission from the copyright holder.

If you want to use this project or any portion of it, please obtain written permission from the repository owner in advance.
