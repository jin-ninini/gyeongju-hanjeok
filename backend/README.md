# 📌 Gyeongju Hanjeok Backend

> FastAPI backend that treats real-time tourist congestion as a hard constraint when generating Gyeongju travel courses.

<br>

## Overview

This is the backend for 경주한적 (Gyeongju Hanjeok), a service that recommends quiet, less-crowded travel courses around Gyeongju. **No dummy tourism data is included** — the service calls real APIs from the Korea Tourism Organization, the Korea Meteorological Administration, Kakao, Naver, YouTube, and OpenAI, and combines them with community-reported, real-time crowd observations.

<br>

## Approach

* **Required API applications** — apply for each service separately at the Korean public data portal (data.go.kr); holding a general auth key for `PUBLIC_DATA_SERVICE_KEY` does not guarantee approval for every service below:
  * Korea Tourism Organization Korean tourism info `KorService1`
  * Forecasted visitor concentration rate `TatsCnctrRateService`
  * Related tourist-attraction info `TarRlteTarService1`
  * Municipal hub attraction info `LocgoHubTarService1`
  * Tourist photo gallery `PhotoGalleryService1`
  * KMA short-term forecast `VilageFcstInfoService_2.0`
* **Separately issued keys**: Kakao Developers REST API key, OpenAI API key, Naver Search API + DataLab API client ID/secret, YouTube Data API v3 key
* **Optional integrations**: Firebase Admin SDK (push notifications), Gmail API OAuth credentials (password-reset email)
* **Tech/architecture**: FastAPI + SQLAlchemy (SQLite locally, PostgreSQL in production), NSGA-II multi-objective course optimizer, OpenAI-embedding RAG search, APScheduler daily sync job

> Kakao walking directions may require partner approval. By default, driving directions use the Kakao API while walking distance is computed from real coordinates and walking speed. Once approved, set `ENABLE_KAKAO_WALKING_API=true` in `.env`.

<br>

## Results

* Real-time course recommendation (1-3 candidates) driven by congestion, weather, distance, and preference, generated with NSGA-II
* Natural-language course editing (exclude / add / replace / reorder places)
* Automatic alternative search when a destination's congestion score exceeds 8
* Place-based cultural-heritage etiquette guidance, and automatic visit completion after a 10-minute stay within 50m (QR check-in)
* Community posts (course reviews, live crowd reports, travel logs), friends, shared routes, companion requests, notifications
* Firebase push notifications and Gmail-API password reset
* Admin API for managing users, reports, and community posts/comments
* RAG-based semantic search over synced official tourism content

<br>

## Tech Stack

### Languages  ![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)  ![SQL](https://img.shields.io/badge/SQL-4479A1?style=flat-square&logo=mysql&logoColor=white)

### Framework  ![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)  ![Uvicorn](https://img.shields.io/badge/Uvicorn-2A9D8F?style=flat-square&logoColor=white)  ![Pydantic](https://img.shields.io/badge/Pydantic-E92063?style=flat-square&logo=pydantic&logoColor=white)  ![SQLAlchemy](https://img.shields.io/badge/SQLAlchemy-D71F00?style=flat-square&logoColor=white)

### External APIs & AI  ![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=flat-square&logo=openai&logoColor=white)  ![Kakao](https://img.shields.io/badge/Kakao-FFCD00?style=flat-square&logo=kakaotalk&logoColor=000000)  ![Naver](https://img.shields.io/badge/Naver-03C75A?style=flat-square&logo=naver&logoColor=white)  ![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white)  ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat-square&logo=firebase&logoColor=black)  ![Gmail](https://img.shields.io/badge/Gmail%20API-EA4335?style=flat-square&logo=gmail&logoColor=white)

### Database  ![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)  ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)

### Testing & Environment  ![pytest](https://img.shields.io/badge/pytest-0A9EDC?style=flat-square&logo=pytest&logoColor=white)  ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)  ![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)

<br>

## Project Structure

```text
backend/
├── app/                 # API routers, services, domain logic
│   ├── main.py          # FastAPI app assembly (thin entry point)
│   ├── api.py            # core /api/v1 course/place/journey routes
│   ├── compat_api.py     # Flutter-compatible route aliases
│   ├── auth_api.py, auth_service.py       # signup/login/session
│   ├── password_reset_api.py, email_service.py  # Gmail-API password reset
│   ├── admin_api.py      # admin: users/reports/posts moderation
│   ├── community_api.py  # community posts/comments/recommendations
│   ├── friend_api.py, shared_route_api.py, companion_request_api.py
│   ├── notification_api.py, notification_service.py
│   ├── push_api.py, push_service.py       # Firebase push notifications
│   ├── chatbot_knowledge.py  # chatbot heritage/etiquette knowledge base
│   ├── clients.py        # external API clients (TourAPI, Kakao, Naver, KMA, OpenAI, YouTube)
│   ├── services.py       # course generation, scoring, RAG sync
│   ├── optimizer.py      # NSGA-II implementation
│   ├── enrichment.py     # place description/content enrichment
│   ├── geo.py, location_policy.py         # distance/grid math, fixed service anchor
│   ├── db.py             # SQLAlchemy models
│   ├── schemas.py        # Pydantic request/response models
│   └── config.py         # environment-driven settings
├── tests/                # pytest suite
├── scripts/              # smoke test, config check, SQLite→Postgres migration
├── data/                 # local SQLite DB (gitignored)
└── README.md
```

<br>

## Notes

### Getting Started

```bash
cp .env.example .env   # then fill in the keys
pip install -r requirements-dev.txt
python -m uvicorn app.main:app --reload
```

On Windows, `run_backend.bat` (or `run_backend.ps1`) does the same after `.env` is filled in. Open `http://127.0.0.1:8000/docs` to browse the live API.

Push notifications and password-reset email are optional — leave their env vars empty to keep those two features disabled without affecting the rest of the API.

### API Reference

**Core course/place engine** (`/api/v1/...`)

* `GET /health` — key configuration and DB status
* `GET /api/v1/places`, `GET /api/v1/places/{place_id}` — real tourist places around the fixed Gyeongju service anchor
* `POST /api/v1/courses/recommend` — congestion/weather/distance/preference-based NSGA-II course generation (1-3 candidates)
* `POST /api/v1/courses/modify` — natural-language place exclude/add/replace/reorder
* `POST /api/v1/courses/recalculate` — alternative search when the next place's congestion exceeds 8
* `GET /api/v1/content/{place_id}` — Naver blog / YouTube content for a place
* `GET /api/v1/etiquette/place/{place_id}` — place-based cultural-heritage etiquette tips
* `POST /api/v1/journeys`, `GET /api/v1/journeys/{id}`, `POST /api/v1/journeys/{id}/visits` — start a course, auto-complete a visit (on-device verification, not GPS)
* `GET /api/v1/congestion/{place_name}` — raw concentration-rate lookup
* `GET /api/v1/weather/current` — current KMA observation for the service anchor
* `GET /api/v1/insights/related`, `GET /api/v1/insights/hubs` — related/hub attraction data
* `POST /api/v1/rag/search` — semantic search over synced official tourism content
* `POST /api/v1/admin/sync` — refresh the Gyeongju place DB and RAG embeddings

**Flutter-compatible aliases** (no `/api/v1` prefix, same behavior): `GET /places`, `GET /places/{place_id}`, `GET /congestion/now`, `GET /congestion/{place_id}`, `POST /routes/recommend`, `POST /routes/recommend/refresh`, `POST /routes/replace-stop`, `POST /chat/modify-course`, `POST /chat/ask`, `GET /etiquette/place/{place_id}`, `POST /visits/check-in`, `GET /weather/current`, `GET /contents/place/{place_id}`

**Auth** (`/auth`): `POST /signup`, `POST /login`, `GET /me`, `PATCH /consents`, `POST /logout`

**Password reset** (`/auth/password-reset`): `POST /request` (send code by email), `POST /verify` (code → reset token), `POST /confirm` (set new password)

**Friends** (`/friends`): `GET /friends`, `POST /friends/requests`, `POST /friends/{friendship_id}/accept`, `DELETE /friends/{friendship_id}`, `POST /friends/invites`, `GET /friends/invites/{token}`, `POST /friends/invites/{token}/claim`, `GET /invite/{token}`

**Shared routes & companions** (`/shared-routes`): `GET|POST /shared-routes`, `GET|PUT /shared-routes/{id}`, `POST .../members/by-code`, `DELETE .../members/{membership_id}`, `POST .../invites`, `POST /invites/{token}/claim`, `GET /route-invite/{token}`; companion requests: `POST .../companion-requests`, `GET .../companion-requests/outgoing`, `GET /shared-routes/companion-requests/incoming`, `POST .../companion-requests/{id}/accept|reject`

**Community** (`/community`): `POST /images`, `GET /images/{id}`, `POST|GET /posts`, `GET /posts/mine`, `GET|PATCH|DELETE /posts/{id}`, `POST /posts/{id}/report`, `POST /posts/{id}/hide`, `POST|DELETE /posts/{id}/recommend`, `GET|POST /posts/{id}/comments`, `PATCH|DELETE /comments/{id}`, `POST|DELETE /posts/{id}/save-course`, `GET /saved-courses`, `GET /posts/{id}/course-copy`, `GET /places/{place_id}/live-summary`

**Notifications & push** (`/notifications`): `GET /notifications`, `GET /notifications/unread-count`, `PATCH /notifications/{id}/read`, `PATCH /notifications/read-all`; device tokens (`/notifications/device-tokens`): `POST ""`, `POST /unregister`

**Admin** (`/admin`, admin role required): `GET /users`, `PATCH /users/{id}/active`, `GET /reports`, `DELETE /reports/{key}`, `GET /posts`, `GET /posts/{id}/comments`, `DELETE /posts/{id}`, `DELETE /comments/{id}`

### Flutter Connection Addresses

* Android emulator: `http://10.0.2.2:8000`
* iOS simulator: `http://127.0.0.1:8000`
* Physical device: `http://<PC's LAN IP>:8000`

### Testing

```bash
pip install -r requirements-dev.txt
pytest
python scripts/smoke_test.py
```

`smoke_test.py` requires the server to already be running, and the course-recommendation integration test only passes once the real API applications above are approved.

### Community Post Types & Live-Report Integration

The community feature supports three post types, all connected back to the course/congestion engine rather than being a plain board:

* `course` — a completed-course review; preserves a `course_snapshot` at post time plus rating and travel date
* `live` — an on-the-spot crowd report for a place (`place_id`, `crowd_percent`, `observed_at`); only observations from the last 6 hours may be submitted
* `travel` — a general travel log, optionally linked to places via `related_place_ids`

All `/community/*` endpoints require `Authorization: Bearer <access_token>`. Congestion is shown in 5 bands, matching the home screen: 0-20 blue (very quiet), 20-40 green (quiet), 40-60 yellow (moderate), 60-80 crimson (crowded), 80-100 red (very crowded).

`GET /community/posts/{id}/course-copy` does not just replay the old course — it returns both the post-time `course_snapshot` and the place data as it stands now (`current_places`), with `requires_live_refresh: true` telling the client to call the course-recommend/recalculate API again so current congestion and travel conditions are reflected. The response also includes `source_place_names`, `include_food`, `include_cafe`, `suggested_available_minutes`, and a ready-to-send `same_course_request_patch` — the client adds the current start coordinate and travel mode and posts it to `/routes/recommend`, which keeps the original places as `required_place_names` while recomputing everything else live.

### Course & Congestion Scoring Rules

These rules (informally called "V2.4.4") are the backend's scoring contract and were deliberately kept unchanged while community features were layered on top:

* **Congestion score** components: baseline 35%, time-of-day 15%, Naver popularity 6%, Naver momentum 4%, weather 5%, official concentration-rate data 25%, regional adjustment up to 10%, with a capacity factor applied last.
* **Course place score**: quietness 45% + preference match 30% + distance from the start point 25%.
* Restaurants/cafes are scored separately from sightseeing preference and are not used to hard-filter the search radius; the radius is never used as a global hard filter for places in general either — only a per-mode safety cap prevents abnormal long jumps late in a course (walking 6km, transit 14km, car 20km).
* Required/pinned places always take priority over general candidate filtering.

**Community live reports** feed a *separate, capped* signal rather than overwriting the official score:

* `congestion_score` — the official V2.4.4 result, never overwritten by community data
* `community_congestion_score` — aggregated from `live` reports in the last 2 hours, with freshness decaying linearly and older reports contributing less
* `routing_congestion_score` (a.k.a. `routing_quiet_score` in Flutter-compatible responses) — the value actually used for course generation, mixing the official score with the capped community signal
* Community influence is capped by report count: 1 report ≤ 8%, 2 ≤ 12%, 3 ≤ 16%, 4+ ≤ 20% (and often smaller once freshness decay is applied)
* The same `routing_congestion_score` is used consistently for the 45% quietness term, priority-candidate selection, restaurant/cafe quietness scoring, and mid-trip recalculation

### Place Overview Resolution

When the official TourAPI overview is empty for a place, the backend fills it in through this fallback order, using only text that was actually returned by a search (never a fabricated description):

1. Naver local-search (지역검색) description for the exact place
2. Naver web-document search, restricted to trusted domains — `gyeongju.go.kr`, `khs.go.kr` / `heritage.go.kr`, `visitkorea.or.kr`, and `encykorea.aks.ac.kr` (lowest priority) — combined with a Kakao/Daum web-document search added later to catch official pages Naver missed
3. Agreement between 2+ independent blog posts, as a last resort
4. Otherwise the place is marked unconfirmed rather than given a generic, type-based description

An earlier version of the description filter over-matched: any sentence containing "위치한" / "위치해" ("located in/at") was treated as a bare address and discarded, which wrongly emptied out real descriptions such as Geumridan-gil's official copy ("...shops and restaurants are located along..."). The filter was fixed to only drop short, address-only text and keep any description containing substantive tourism/commercial/historical/heritage/sightseeing/experience wording. `GET /places/{id}` also returns the same value twice, as both `description` and an `overview` alias, and includes the discovered official page in `content_links` as an `official_web` entry.

### GPS / Location Privacy Policy

The production backend does **not** accept the user's live GPS coordinate:

* `/places`, `/api/v1/places`, `/weather/current`, and `/api/v1/weather/current` use a fixed Gyeongju service anchor instead of a user-supplied location
* The legacy `/places/nearby` and `/places/nearest-tourist` endpoints were removed
* Course/route request bodies no longer accept `latitude`/`longitude`, `start_latitude`/`start_longitude`, or `current_latitude`/`current_longitude`
* Visit completion (`.../visits`, `/visits/check-in`) accepts an on-device verification result, not a GPS coordinate
* Etiquette lookup is place-based (`/etiquette/place/{place_id}`), not location-based
* Public tourist-place coordinates are still returned in responses — those identify the *place*, not the user

The Flutter app keeps using GPS locally (current-position UI, local distance/sorting, visit verification); the backend simply never receives it.

### SQLite → PostgreSQL Migration

Never commit the SQLite database file — it contains account records and password hashes (already covered by `.gitignore`). The migration script copies password hashes as-is, so existing accounts keep working without a password reset.

```bash
# 1. Dry run
python scripts/migrate_sqlite_accounts_to_postgres.py --sqlite ./data/gyeongju_hanjeok.db --dry-run

# 2. Point at the target Postgres instance for this shell session only
export TARGET_DATABASE_URL="postgresql://USER:PASSWORD@HOST:PORT/railway"

# 3. Apply
python scripts/migrate_sqlite_accounts_to_postgres.py --sqlite ./data/gyeongju_hanjeok.db --apply
```

Migrated: users, consents/public member code, friends/invites, shared routes/members/invites, community posts/comments/recommendations/saved courses, journeys. **Not migrated**: the `places` table — production tourist-place data is owned by the Railway sync process instead.

After migrating, verify a real account end-to-end: log in with its existing email/password, confirm `GET /auth/me` succeeds, log out and back in once more, then restart the app and confirm the session survives — before shipping a release build.

### Known Limitations

* Providing an API key does not call the service unless that specific **API application has been approved**
* If a place has no concentration-rate data, its congestion stays "unknown" — the backend never fabricates a live value
* Since the official APIs provide no reviews/ratings, the review term in the recommendation formula is fixed at a neutral 0.5 until a real review provider is integrated
* Operating hours and admission fees are merged from whatever TourAPI detail fields exist for that attraction type, since the fields differ by category

<br>

## License

Copyright © 2026 Hyunjin Hwang. All rights reserved.

This repository is provided for viewing and portfolio evaluation purposes only.

No permission is granted to copy, modify, distribute, sublicense, publish, or commercially use any part of this project, including its source code, assets, documentation, design, or other contents, without prior written permission from the copyright holder.

If you want to use this project or any portion of it, please obtain written permission from the repository owner in advance.
