# app/main.py 또는 현재 router 등록 파일에서 추가

from app.notification_api import notification_router
from app.companion_request_api import companion_router

app.include_router(notification_router)
app.include_router(companion_router)

# 만약 이미 api_router = APIRouter() 방식이면:
# api_router.include_router(notification_router)
# api_router.include_router(companion_router)
