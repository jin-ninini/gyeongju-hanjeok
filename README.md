# 📍 Gyeongju Hanjeok (경주한적)

> 실시간 혼잡도를 코스 생성의 제약조건으로 사용해, 사람이 몰리지 않는 한적한 경주 여행 코스를 추천하는 서비스입니다.

<br>

## Overview

경주는 특정 관광지에 방문객이 몰리는 시간대·요일이 뚜렷해 혼잡도가 여행 만족도에 큰 영향을 줍니다. 이 프로젝트는 더미 데이터가 아닌 한국관광공사·기상청·카카오·네이버·YouTube·OpenAI의 실제 API를 조합해, 사용자의 현재 위치·날씨·실시간 혼잡도·선호를 반영한 여행 코스를 자동으로 생성하고, 여행 중에도 챗봇 대화만으로 코스를 조정할 수 있게 하는 것을 목표로 합니다.

<br>

## Approach

* **사용한 데이터**: 한국관광공사 국문 관광정보(KorService1), 관광지 집중률 방문자 추이(TatsCnctrRateService), 연관/중심 관광지 정보, 관광사진 정보, 기상청 단기예보(VilageFcstInfoService_2.0), 카카오 로컬/내비/도보, 네이버 검색·데이터랩, YouTube Data API
* **주요 처리 방식**: 혼잡도·날씨·이동거리·사용자 선호를 다목적 함수로 두고 NSGA-II로 코스 후보를 생성, 관광 정보 텍스트는 임베딩 후 RAG 방식으로 의미 검색
* **사용한 기술/구조**: FastAPI 백엔드(코스 추천·수정·재계산 API, 인증, 커뮤니티/친구/알림) + Flutter 프론트엔드(지도, 챗봇, 커뮤니티, QR 체크인)
* **전체적인 접근 방식**: 다음 방문지의 혼잡도가 임계값을 넘으면 자동으로 대체지를 탐색하고, 사용자는 자연어로 "이 장소는 빼고", "카페 하나 추가해줘" 같은 요청을 하면 챗봇이 코스를 즉시 재구성

<br>

## Results

* 위치·날씨·혼잡도·선호 기반 코스 1~3개를 실시간으로 추천 (`/api/v1/courses/recommend`)
* 자연어 요청으로 장소 제외·추가·교체·순서 변경 지원 (`/api/v1/courses/modify`)
* 다음 방문지 혼잡도가 8점을 초과하면 대체지를 자동 탐색 (`/api/v1/courses/recalculate`)
* 문화재 인근 위치 기반 에티켓 안내, 50m 이내 10분 체류 시 방문 완료 처리(QR 체크인)
* 커뮤니티, 친구 초대, 완료한 여행 기록, 알림 기능 제공

<!-- 필요한 경우 스크린샷이나 코스 추천 결과 이미지를 추가합니다. -->

<br>

## Tech Stack

### Languages

![Python](https://img.shields.io/badge/Python-3776AB?style=flat-square&logo=python&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-4479A1?style=flat-square&logo=mysql&logoColor=white)

### Backend

![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white)
![Uvicorn](https://img.shields.io/badge/Uvicorn-2A9D8F?style=flat-square&logoColor=white)
![Pydantic](https://img.shields.io/badge/Pydantic-E92063?style=flat-square&logo=pydantic&logoColor=white)

### Frontend / Mobile

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white)

### External APIs & AI

![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=flat-square&logo=openai&logoColor=white)
![Kakao](https://img.shields.io/badge/Kakao-FFCD00?style=flat-square&logo=kakaotalk&logoColor=000000)
![Naver](https://img.shields.io/badge/Naver-03C75A?style=flat-square&logo=naver&logoColor=white)
![YouTube](https://img.shields.io/badge/YouTube-FF0000?style=flat-square&logo=youtube&logoColor=white)

### Database

![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white)

### Development & Environment

![Git](https://img.shields.io/badge/Git-F05032?style=flat-square&logo=git&logoColor=white)
![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat-square&logo=github&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white)
![VS Code](https://img.shields.io/badge/VS%20Code-007ACC?style=flat-square&logo=visualstudiocode&logoColor=white)

<br>

## Project Structure

```text
gyeongju_hanjeok/
├── backend/            # FastAPI 서버
│   ├── app/            # API 라우터 · 서비스 · 도메인 로직
│   ├── tests/          # pytest 테스트
│   ├── scripts/        # 스모크 테스트, DB 마이그레이션 등 운영 스크립트
│   ├── integration/    # 커뮤니티/알림 등 기능 통합용 참조 코드
│   ├── sql/            # DB 마이그레이션 SQL
│   └── README.md       # 백엔드 실행/설정 가이드
└── frontend/           # Flutter 앱
    ├── lib/            # 화면(screens) · 상태(state) · 서비스(services) · 모델(models)
    ├── android/        # 안드로이드 빌드 설정
    └── assets/         # 폰트 · 이미지 · 아이콘
```

<br>

## Notes

### 실행 방법 (요약)

```bash
# Backend
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
cp .env.example .env   # 키 입력 후
python -m uvicorn app.main:app --reload

# Frontend
cd frontend
cp .env.example .env   # BACKEND_BASE_URL, 카카오 키 등 입력 후
flutter pub get
flutter run
```

세부 API 신청 절차와 전체 엔드포인트 목록은 [`backend/README.md`](backend/README.md)를 참고합니다.

### 저장소에 포함하지 않은 파일

| 항목 | 이유 |
| --- | --- |
| 루트의 `*.txt` 파일 | `backend/`, `frontend/` 폴더 밖에 있는 개인 작업 메모·기획 문서 |
| `.env`, `key.properties`, `*.jks` | API 키·서명 비밀값 — `.env.example` / `key.properties.example`로 템플릿만 제공 |
| `.venv/`, `build/`, `.dart_tool/`, `android/.gradle/`, `android/.kotlin/` | 재생성 가능한 로컬 빌드/의존성 산출물 |
| `backend/data/*.db` | 로컬 SQLite 데이터베이스 파일 |
| `backend/gyeongju-hanjeok-deploy/` | 자체 git 이력을 가진 별도 배포용 미러 저장소 (독립 관리) |
| `flutter_lib_backups/`, `*.bak`, `*.zip`, `build_release_error.txt` | 빈 백업 폴더, 임시 백업/압축 파일, 빌드 에러 로그 |
| `frontend/.idea/` | IDE 설정 파일 |

### 알게 된 점 / 향후 개선

* 관광공사 API는 관광지 유형별로 필드가 달라 운영시간·입장료 등은 존재하는 필드를 통합해서 처리 중
* 공식 API가 리뷰·별점을 제공하지 않아 추천식의 리뷰 항목은 중립값(0.5)으로 고정 — 실제 리뷰 공급자가 정해지면 해당 클라이언트만 교체하면 됨
* 카카오 도보 길찾기는 제휴 파트너 승인이 필요해 기본값은 좌표 기반 거리·보행속도로 대체 계산
