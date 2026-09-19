-- 경주한적 notifications + 동행 코스 요청
-- PostgreSQL 기준. Railway PostgreSQL에서 그대로 실행 가능.

CREATE TABLE IF NOT EXISTS notifications (
    notification_id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    actor_user_id VARCHAR(36) NULL REFERENCES users(user_id) ON DELETE SET NULL,
    type VARCHAR(40) NOT NULL,
    title VARCHAR(120) NOT NULL,
    message VARCHAR(500) NOT NULL,
    post_id VARCHAR(36) NULL REFERENCES community_posts(post_id) ON DELETE CASCADE,
    friendship_id VARCHAR(80) NULL,
    shared_route_id VARCHAR(36) NULL REFERENCES shared_routes(shared_route_id) ON DELETE CASCADE,
    route_request_id VARCHAR(36) NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ NULL
);

CREATE INDEX IF NOT EXISTS ix_notifications_user_created
    ON notifications(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_notifications_user_unread
    ON notifications(user_id, is_read);

CREATE TABLE IF NOT EXISTS route_companion_requests (
    request_id VARCHAR(36) PRIMARY KEY,
    shared_route_id VARCHAR(36) NOT NULL REFERENCES shared_routes(shared_route_id) ON DELETE CASCADE,
    requester_user_id VARCHAR(36) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    recipient_user_id VARCHAR(36) NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    responded_at TIMESTAMPTZ NULL,
    CONSTRAINT uq_route_companion_pending UNIQUE(shared_route_id, requester_user_id, recipient_user_id)
);

CREATE INDEX IF NOT EXISTS ix_route_companion_recipient_status
    ON route_companion_requests(recipient_user_id, status, created_at DESC);
