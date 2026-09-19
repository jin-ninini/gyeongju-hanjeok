# community_api.py 에 추가할 코드 예시
# 상단:
from app.notification_service import create_notification

# ------------------------------------------------------------
# recommend_post()에서 추천 레코드를 새로 추가한 경우에만:
# post = _load_post(db, post_id) 형태로 작성자 정보를 확보
# ------------------------------------------------------------
if post.author_user_id != current_user.user_id:
    create_notification(
        db,
        user_id=post.author_user_id,
        actor_user_id=current_user.user_id,
        type="recommendation",
        title="새 추천이 있어요",
        message=f"{current_user.nickname}님이 회원님의 게시물을 추천했어요.",
        post_id=post.post_id,
    )
# 기존 endpoint의 db.commit()에서 recommendation + notification을 함께 commit

# 추천 취소(unrecommend) 때는 과거 알림까지 지우지 않는 것을 권장.
# 알림은 "그 시점에 발생했던 활동 이력"이기 때문.

# ------------------------------------------------------------
# create_comment()에서 댓글 row를 db.add(row) 한 뒤:
# ------------------------------------------------------------
post = _load_post(db, post_id)
if post.author_user_id != current_user.user_id:
    create_notification(
        db,
        user_id=post.author_user_id,
        actor_user_id=current_user.user_id,
        type="comment",
        title="새 댓글이 달렸어요",
        message=f"{current_user.nickname}님이 회원님의 게시물에 댓글을 남겼어요.",
        post_id=post.post_id,
    )
# 기존 db.commit()에서 함께 저장

# ------------------------------------------------------------
# 친구 요청 생성 endpoint POST /friends/requests
# FriendshipRecord를 만들고 friendship_id를 확보한 뒤:
# target_user = 요청받는 사람
# ------------------------------------------------------------
create_notification(
    db,
    user_id=target_user.user_id,
    actor_user_id=current_user.user_id,
    type="friend_request",
    title="새 친구 요청",
    message=f"{current_user.nickname}님이 친구 요청을 보냈어요.",
    friendship_id=friendship.friendship_id,
)

# 친구 요청 수락 endpoint /friends/{friendship_id}/accept 에서는:
create_notification(
    db,
    user_id=friendship.requester_user_id,
    actor_user_id=current_user.user_id,
    type="friend_accepted",
    title="친구 요청 수락",
    message=f"{current_user.nickname}님이 친구 요청을 수락했어요.",
    friendship_id=friendship.friendship_id,
)
