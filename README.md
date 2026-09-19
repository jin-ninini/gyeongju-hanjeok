# 경주한적 (Gyeongju Hanjeok)

혼잡도를 코스 생성의 제약조건으로 사용해, 사람이 몰리지 않는 **한적한 경주 여행 코스**를 실시간으로 추천하는 서비스입니다.
더미 관광 데이터를 사용하지 않고 한국관광공사·기상청·카카오·네이버·YouTube·OpenAI의 실제 API를 호출해 코스를 생성합니다.

- **Backend**: FastAPI (Python) — 실시간 혼잡도·날씨·거리 기반 NSGA-II 코스 추천, RAG 기반 관광 정보 검색, 커뮤니티/친구/알림 기능
- **Frontend**: Flutter (Android/iOS) — 지도 기반 코스 확인, 챗봇을 통한 코스 수정, 커뮤니티/QR 체크인 등

## 프로젝트 구조

```
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

## 시작하기

### 1. Backend (FastAPI)

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate / macOS·Linux: source .venv/bin/activate
pip install -r requirements-dev.txt

cp .env.example .env   # Windows: copy .env.example .env
# .env를 열어 API 키(공공데이터포털, 카카오, OpenAI, 네이버, YouTube 등)를 채워주세요.

# 실행
python -m uvicorn app.main:app --reload
# 또는 Windows: run_backend.bat / run_backend.ps1

# 브라우저에서 http://127.0.0.1:8000/docs 확인
```

필요한 API 신청 항목과 전체 엔드포인트 목록은 [`backend/README.md`](backend/README.md)를 참고하세요.

테스트:

```bash
pytest
python scripts/smoke_test.py   # 서버 실행 후 사용
```

### 2. Frontend (Flutter)

```bash
cd frontend
cp .env.example .env
# .env에 백엔드 주소(BACKEND_BASE_URL)와 카카오 키 등을 채워주세요.

flutter pub get
flutter run
```

Android 릴리즈 서명이 필요하다면 `frontend/android/key.properties.example`을 참고해
`frontend/android/key.properties`를 직접 만들고, 키스토어(`.jks`)를 준비하세요. (둘 다 git에는 포함되지 않습니다.)

기기별 백엔드 접속 주소:

- Android 에뮬레이터: `http://10.0.2.2:8000`
- iOS 시뮬레이터: `http://127.0.0.1:8000`
- 실제 휴대전화: `http://PC의-같은-WiFi-IP:8000`

## 이 저장소에 포함하지 않은 파일

작업 중 생성된 파일 중 아래 항목은 저장소에 커밋하지 않도록 `.gitignore`에 정리했습니다.

| 항목 | 이유 |
| --- | --- |
| 루트에 있는 `*.txt` 파일 (`FINAL_CHANGES_*.txt`, `RAG_INTEGRATION_NOTES_*.txt`, `경주한적_*.txt` 등) | `backend/`, `frontend/` 폴더 밖에 있는 개인 작업 메모·기획 문서로, 로컬 참고용으로만 보관 |
| `backend/.env`, `frontend/.env`, `frontend/android/key.properties`, `frontend/android/*.jks` | API 키·서명 비밀값. 각각 `.env.example` / `key.properties.example`을 참고해 로컬에서 직접 생성 |
| `backend/.venv/`, `frontend/build/`, `frontend/.dart_tool/`, `frontend/android/.gradle/`, `frontend/android/.kotlin/` | 로컬 빌드/의존성 산출물 (재생성 가능) |
| `backend/data/*.db` | 로컬 SQLite 데이터베이스 파일 |
| `backend/gyeongju-hanjeok-deploy/` | 자체 git 이력을 가진 별도 배포용 미러 저장소 — 이 저장소와는 독립적으로 관리 |
| `flutter_lib_backups/` | 사용하지 않는 빈 백업 폴더 |
| `frontend/lib/**/*.bak`, `**/*.zip`, `frontend/build_release_error.txt` | 임시 백업/압축 파일, 빌드 에러 로그 |
| `frontend/.idea/`, `*.iml` 등 | IDE 설정 파일 |

## 주요 기능

- 위치·날씨·혼잡도 기반 실시간 코스 추천 (NSGA-II 다목적 최적화)
- 자연어로 코스 장소 추가·제외·교체 요청 (챗봇)
- 다음 방문지 혼잡도가 높을 경우 대체지 자동 탐색
- 문화재 인근 위치 기반 에티켓 안내
- 커뮤니티, 친구 초대, 완료한 여행 기록, 알림
- QR 체크인 기반 방문 인증

자세한 API 명세는 [`backend/README.md`](backend/README.md)를 참고하세요.
