# ЖетКир Backend - Flutter Frontend

Кыргызстандагы жеткирүү кызматы мобилдик колдонмосу.

## Орнотуу

### 1. Flutter SDK орнотуңуз

```bash
flutter doctor
```

### 2. Dependencies орнотуңуз

```bash
flutter pub get
```

### 3. Backend иштетиңиз

Backend `/Users/nurgazyuson/python_projects/batjetkiret-backend` папкасында турат. Биринчи анын иштетүү керек:

```bash
cd /Users/nurgazyuson/python_projects/batjetkiret-backend
source venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 4. Колдонмону иштетүү

iOS симуляторунда:

```bash
flutter run -d A8E0AAEA-45F8-4480-B868-D9D53165DB2E \
  --dart-define=API_BASE_URL=http://localhost:8000
```

macOS десктопто:

```bash
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:8000
```

## Yandex API орнотуу (жол аралыгын эсептөө үчүн)

Жол жүрүү аралыгын так эсептөө үчүн Yandex Router API колдонулат. Толук көрсөтмө:

**📄 [YANDEX_API_SETUP.md](../YANDEX_API_SETUP.md)** файлын окуңуз.

Кыскача:
1. [Yandex Cloud Console](https://console.cloud.yandex.ru/)га кириңиз
2. Router API үчүн API ачкычын түзүңүз
3. Колдонмону жүргүзгөндө API ачкычын бериңиз:

```bash
flutter run -d macos \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=YANDEX_API_KEY=СИЗДИН_API_АЧКЫЧЫҢЫЗ
```

**Эскертүү:** API ачкычы жок болсо, колдонмо автоматтык түрдө түз сызык аралыкка кайрылат.

## VS Code'то иштетүү

VS Code'то debug баскычын басып, ордун тандаңыз:
- Flutter (iOS Simulator)
- Flutter (macOS)
- Flutter (Chrome)

API ачкычын кошуу үчүн `.vscode/launch.json` файлындагы комментарийди ачыңыз.

## Негизги өзгөчөлүктөр

- ✅ Колдонуучу жана куреьр роледору
- ✅ Заказ түзүү (координаталар + адрес текст менен)
- ✅ Балансты башкаруу (10 сом минималдуу, 5 сом сервис акы)
- ✅ Заказдарды кабыл алуу жана жеткирүү
- ✅ Жол жүрүү аралыгын эсептөө (Yandex Router API)
- ✅ Уведомлениелер (push notifications)
- ✅ Чат колдонуучу ↔ куреьр

## Көйгөйлөрдү чечүү

### Backend'ке туташпайт

```bash
# Backend иштеп жатканын текшириңиз
curl http://localhost:8000/docs
# 200 OK кайтарышы керек
```

### iOS симулятору иштебей жатат

```bash
# Симуляторду reboot кылыңыз
xcrun simctl shutdown A8E0AAEA-45F8-4480-B868-D9D53165DB2E
xcrun simctl boot A8E0AAEA-45F8-4480-B868-D9D53165DB2E
open -a Simulator

# Flutter clean жана rebuild
flutter clean
flutter pub get
flutter run -d A8E0AAEA-45F8-4480-B868-D9D53165DB2E
```

## Flutter ресурстары

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)
- [Online documentation](https://docs.flutter.dev/)
