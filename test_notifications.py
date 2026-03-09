#!/usr/bin/env python3
import sys
sys.path.insert(0, '/Users/nurgazyuson/python_projects/batjetkiret-backend')

from app.core.database import SessionLocal
from app.models.user import User
from app.models.notification import Notification

db = SessionLocal()

# Check for existing user
existing_user = db.query(User).first()
if existing_user:
    user_id = existing_user.id
    print(f"Found user: {existing_user.phone} (id={user_id})")
else:
    print("No users found in database")
    db.close()
    sys.exit(1)

# Create test notifications
test_notifications = [
    Notification(
        user_id=user_id,
        title="Payment received",
        message="Your 500 som payment was received successfully. Balance updated.",
        is_read=False
    ),
    Notification(
        user_id=user_id,
        title="Screenshot under review",
        message="Admin is reviewing your Screenshot. You'll get results tomorrow.",
        is_read=False
    ),
    Notification(
        user_id=user_id,
        title="Order ready",
        message="Your order is ready for pickup!",
        is_read=True
    ),
]

for notif in test_notifications:
    db.add(notif)

db.commit()

# Verify
all_notifs = db.query(Notification).all()
print(f"Total notifications in DB: {len(all_notifs)}")
for n in all_notifs:
    print(f"  - {n.title} (id={n.id}, user_id={n.user_id}, read={n.is_read})")

db.close()
print("Done!")
