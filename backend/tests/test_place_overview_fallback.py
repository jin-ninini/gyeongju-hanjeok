import asyncio

import app.compat_api as compat
from app.config import Settings
from app.schemas import Place


def _place() -> Place:
    return Place(
        place_id="heritage-test",
        title="경주 탈해왕릉",
        category="관광지",
        latitude=35.866,
        longitude=129.228,
    )


def test_official_web_document_can_fill_missing_overview(monkeypatch):
    async def fake_local(self, query, limit=5, sort="random"):
        return []

    async def fake_web(self, query, limit=10):
        return [
            {
                "title": "경주 탈해왕릉 | 국가유산 디지털 서비스",
                "url": "https://digital.khs.go.kr/heri/example",
                "description": (
                    "경주 탈해왕릉은 신라 탈해왕의 무덤으로 전해지며 "
                    "소나무숲으로 둘러싸인 원형 봉토무덤이다."
                ),
            }
        ]

    async def fake_blogs(self, query, limit=5):
        return []

    monkeypatch.setattr(compat.NaverClient, "local_search", fake_local)
    monkeypatch.setattr(compat.NaverClient, "web_documents", fake_web)
    monkeypatch.setattr(compat.NaverClient, "blogs", fake_blogs)

    overview, source, link = asyncio.run(
        compat._quick_overview_from_naver(_place(), Settings())
    )

    assert "신라 탈해왕" in overview
    assert source == "official_web"
    assert link is not None
    assert link["type"] == "official_web"
    assert "khs.go.kr" in link["url"]


def test_untrusted_web_document_is_not_used_as_official_overview(monkeypatch):
    async def fake_local(self, query, limit=5, sort="random"):
        return []

    async def fake_web(self, query, limit=10):
        return [
            {
                "title": "경주 탈해왕릉 후기",
                "url": "https://example.com/talhae",
                "description": "경주 탈해왕릉은 분위기가 정말 좋고 사진이 잘 나오는 곳입니다.",
            }
        ]

    async def fake_blogs(self, query, limit=5):
        return []

    monkeypatch.setattr(compat.NaverClient, "local_search", fake_local)
    monkeypatch.setattr(compat.NaverClient, "web_documents", fake_web)
    monkeypatch.setattr(compat.NaverClient, "blogs", fake_blogs)

    overview, source, link = asyncio.run(
        compat._quick_overview_from_naver(_place(), Settings())
    )

    assert overview is None
    assert source is None
    assert link is None


def test_kakao_daum_official_web_can_fill_missing_overview(monkeypatch):
    async def fake_local(self, query, limit=5, sort="random"):
        return []

    async def fake_naver_web(self, query, limit=10):
        return []

    async def fake_blogs(self, query, limit=5):
        return []

    async def fake_kakao_web(self, query, *, limit=10):
        return [
            {
                "title": "경주 탈해왕릉 | 경주문화관광",
                "url": "https://www.gyeongju.go.kr/tour/page.do?area_uid=184",
                "description": (
                    "탈해왕릉은 경주 내에 있는 유일한 석씨 왕의 능으로, "
                    "소나무숲에 둘러싸여 있어 왕릉과 주변 경관을 함께 살펴볼 수 있다."
                ),
                "search_source": "kakao_daum",
            }
        ]

    monkeypatch.setattr(compat.NaverClient, "local_search", fake_local)
    monkeypatch.setattr(compat.NaverClient, "web_documents", fake_naver_web)
    monkeypatch.setattr(compat.NaverClient, "blogs", fake_blogs)
    monkeypatch.setattr(compat.KakaoLocalClient, "web_search", fake_kakao_web)

    overview, source, link = asyncio.run(
        compat._quick_overview_from_naver(_place(), Settings(kakao_rest_api_key="test"))
    )

    assert "유일한 석씨 왕" in overview
    assert source == "official_web"
    assert link is not None
    assert "gyeongju.go.kr" in link["url"]


def _list_place(place_id: str) -> Place:
    return Place(
        place_id=place_id,
        content_type_id="12",
        title=f"테스트장소 {place_id}",
        category="관광지",
        latitude=35.866,
        longitude=129.228,
    )


def test_list_overview_caches_empty_tourapi_result(monkeypatch):
    monkeypatch.setattr(compat, "_PLACE_LIST_OVERVIEW_CACHE", {})
    calls = []

    async def fake_detail(self, place):
        calls.append(place.place_id)
        place.overview = ""
        return place

    monkeypatch.setattr(compat.TourApiClient, "detail", fake_detail)
    settings = Settings(_env_file=None)

    first = asyncio.run(compat._fill_list_overviews_from_tourapi([_list_place("empty-1")], settings))
    second = asyncio.run(compat._fill_list_overviews_from_tourapi([_list_place("empty-1")], settings))

    assert calls == ["empty-1"]
    assert not first[0].overview
    assert not second[0].overview


def test_list_overview_retries_after_transient_failure(monkeypatch):
    monkeypatch.setattr(compat, "_PLACE_LIST_OVERVIEW_CACHE", {})
    calls = []

    async def flaky_detail(self, place):
        calls.append(place.place_id)
        if len(calls) == 1:
            raise compat.IntegrationError("tour_api", "temporary failure")
        place.overview = "신라 왕릉과 소나무숲을 함께 둘러볼 수 있는 경주의 대표 유적지입니다."
        return place

    monkeypatch.setattr(compat.TourApiClient, "detail", flaky_detail)
    settings = Settings(_env_file=None)

    first = asyncio.run(compat._fill_list_overviews_from_tourapi([_list_place("flaky-1")], settings))
    second = asyncio.run(compat._fill_list_overviews_from_tourapi([_list_place("flaky-1")], settings))

    assert calls == ["flaky-1", "flaky-1"]
    assert not first[0].overview
    assert "소나무숲" in second[0].overview
