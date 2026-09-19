# app/db.py 에 추가할 모델 두 개
# 기존 app/db.py의 Base / Mapped / mapped_column / String / Boolean /
# DateTime / ForeignKey / JSON 등 import 스타일에 맞춰 붙이세요.

class NotificationRecord(Base):
    __tablename__ = "notifications"

    notification_id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.user_id", ondelete="CASCADE"), index=True
    )
    actor_user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True
    )
    type: Mapped[str] = mapped_column(String(40), index=True)
    title: Mapped[str] = mapped_column(String(120))
    message: Mapped[str] = mapped_column(String(500))
    post_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("community_posts.post_id", ondelete="CASCADE"), nullable=True
    )
    friendship_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    shared_route_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("shared_routes.shared_route_id", ondelete="CASCADE"), nullable=True
    )
    route_request_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    is_read: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )
    read_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


class RouteCompanionRequestRecord(Base):
    __tablename__ = "route_companion_requests"

    request_id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid4())
    )
    shared_route_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("shared_routes.shared_route_id", ondelete="CASCADE"), index=True
    )
    requester_user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.user_id", ondelete="CASCADE"), index=True
    )
    recipient_user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.user_id", ondelete="CASCADE"), index=True
    )
    status: Mapped[str] = mapped_column(String(20), default="pending", index=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), index=True
    )
    responded_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
