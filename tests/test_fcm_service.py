from app.services import fcm


class _FakeMessaging:
    sent_message = None

    @staticmethod
    def Notification(**kwargs):
        return kwargs

    @staticmethod
    def AndroidNotification(**kwargs):
        return kwargs

    @staticmethod
    def AndroidConfig(**kwargs):
        return kwargs

    @staticmethod
    def Aps(**kwargs):
        return kwargs

    @staticmethod
    def APNSPayload(**kwargs):
        return kwargs

    @staticmethod
    def APNSConfig(**kwargs):
        return kwargs

    @staticmethod
    def Message(**kwargs):
        return kwargs

    @classmethod
    def send(cls, message):
        cls.sent_message = message


def test_push_uses_ios_sound_file_and_high_priority(monkeypatch):
    monkeypatch.setattr(fcm, "_initialized", True)
    monkeypatch.setattr(fcm, "_messaging", _FakeMessaging)
    _FakeMessaging.sent_message = None

    assert fcm.send_push(
        "device-token",
        "Заказ",
        "Статус өзгөрдү",
        data={"type": "order_status"},
        include_notification=True,
    )

    message = _FakeMessaging.sent_message
    assert message["apns"]["headers"] == {"apns-priority": "10"}
    assert message["apns"]["payload"]["aps"]["sound"] == "order_tone.wav"
    assert message["android"]["notification"]["sound"] == "order_tone"
