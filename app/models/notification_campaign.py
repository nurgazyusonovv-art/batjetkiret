from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.sql import func

from app.core.database import Base


class NotificationCampaign(Base):
    """One notification blast, sent now or at a scheduled time.

    A broadcast writes one Notification row per user, which leaves no record of
    the campaign itself. This table holds that record, which is what makes
    scheduling, cancelling and "how many did it reach" possible.

    Admins send campaigns directly. An enterprise submits one from its panel;
    it waits in STATUS_PENDING_REVIEW until an admin approves (sends) or
    rejects it.
    """

    __tablename__ = "notification_campaigns"

    STATUS_PENDING_REVIEW = "pending_review"
    STATUS_SCHEDULED = "scheduled"
    STATUS_SENDING = "sending"
    STATUS_SENT = "sent"
    STATUS_CANCELLED = "cancelled"
    STATUS_FAILED = "failed"
    STATUS_REJECTED = "rejected"

    id = Column(Integer, primary_key=True, index=True)

    title = Column(String, nullable=False)
    message = Column(String, nullable=False)
    image_url = Column(String, nullable=True)
    enterprise_id = Column(
        Integer,
        ForeignKey("enterprises.id", ondelete="SET NULL"),
        nullable=True,
    )
    notification_type = Column(String, nullable=True)

    # Naive UTC, like the rest of the schema. Null means "send immediately".
    scheduled_at = Column(DateTime, nullable=True, index=True)
    status = Column(String, nullable=False, default=STATUS_SCHEDULED, index=True)

    sent_at = Column(DateTime, nullable=True)
    sent_count = Column(Integer, nullable=False, default=0)
    pushed_count = Column(Integer, nullable=False, default=0)
    error = Column(Text, nullable=True)

    created_by_admin_id = Column(Integer, nullable=True)
    # Set when an enterprise submitted the campaign from its own panel.
    created_by_enterprise_id = Column(
        Integer,
        ForeignKey("enterprises.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )
    # The menu item the campaign advertises, if one was picked.
    product_id = Column(
        Integer,
        ForeignKey("enterprise_products.id", ondelete="SET NULL"),
        nullable=True,
    )
    review_note = Column(Text, nullable=True)
    reviewed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    @property
    def is_cancellable(self) -> bool:
        return self.status == self.STATUS_SCHEDULED
