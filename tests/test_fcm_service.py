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


def test_image_push_builds_with_real_firebase_classes(monkeypatch):
    """A picture campaign must reach the phone, not only the in-app list.

    The fakes above accept any attribute, so a misspelt firebase class
    (APNSFcmOptions instead of APNSFCMOptions) once made every image push
    fail silently. Build the message with the real SDK classes instead.
    """
    from firebase_admin import _messaging_encoder, messaging

    sent = []
    monkeypatch.setattr(fcm, "_initialized", True)
    monkeypatch.setattr(fcm, "_messaging", messaging)
    monkeypatch.setattr(messaging, "send", lambda message: sent.append(message))

    class _Response:
        success_count = 1

    monkeypatch.setattr(
        messaging,
        "send_each_for_multicast",
        lambda message: sent.append(message) or _Response(),
    )

    image = "https://media.example.com/notifications/promo.jpg"
    assert fcm.send_push(
        "device-token", "Акция", "Бүгүн арзан", data={"type": "promo"},
        include_notification=True, image_url=image,
    )
    assert fcm.send_push_to_tokens(
        ["device-token"], "Акция", "Бүгүн арзан", data={"type": "promo"},
        image_url=image,
    ) == 1

    single = _messaging_encoder.MessageEncoder().default(sent[0])
    assert single["notification"]["image"] == image
    assert single["android"]["notification"]["image"] == image
    assert single["android"]["notification"]["sound"] == "message_tone"
    assert single["apns"]["fcm_options"]["image"] == image
    assert single["apns"]["payload"]["aps"]["sound"] == "message_tone.wav"
    assert single["apns"]["payload"]["aps"]["mutable-content"] == 1
