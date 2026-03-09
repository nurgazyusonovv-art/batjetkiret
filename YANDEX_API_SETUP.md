# Yandex API Орнотуу Көрсөтмөсү

## Жол жүрүү аралыгын эсептөө үчүн Yandex Router API

Колдонмо азыр заказдагы аралыкты Yandex Router API аркылуу **жол жүрүү аралыгы** катары эсептейт (мурда түз сызык болгон).

### 1. Yandex Cloud Console'га кириңиз

1. [https://console.cloud.yandex.ru/](https://console.cloud.yandex.ru/) сайтына кириңиз
2. Эгер аккаунтуңуз жок болсо, жаңы аккаунт түзүңүз

### 2. Cloud үчүн төлөм кошуңуз (Trial акча берилет)

1. Биллингди жандырыңыз (60 күн бою 4000 сом Trial credit берилет)
2. Банк картаңызды кошуңуз (Trial акча бүткөнгө чейин төлөбөйсүз)

### 3. API ачкычын түзүңүз

1. **API Services** → **Yandex Maps API** бөлүмүнө өтүңүз
2. **Create API Key** баскычын басыңыз
3. API ачкычы (`apikey`) көчүрүлүп алыңыз

**Важно:** Router API үчүн аны кошуңуз:
- "Maps Router" кызматын тандаңыз
- Rate limit: 1000 request/day (бекер тарифте)

### 4. Колдонмодо API ачкычын иштетүү

#### А) Терминалдан Flutter жүргүзүү

```bash
cd /Users/nurgazyuson/python_projects/batjetkiret-backend/frontend

flutter run -d A8E0AAEA-45F8-4480-B868-D9D53165DB2E \
  --dart-define=API_BASE_URL=http://localhost:8000 \
  --dart-define=YANDEX_API_KEY=СИЗДИН_API_АЧКЫЧЫҢЫЗ
```

#### Б) VS Code launch.json файлында

`.vscode/launch.json` файлынын `args` бөлүгүнө кошуңуз:

```json
"args": [
    "--dart-define=API_BASE_URL=http://localhost:8000",
    "--dart-define=YANDEX_API_KEY=СИЗДИН_API_АЧКЫЧЫҢЫЗ"
]
```

**Эскертүү:** API ачкычын Git'ке жүктөбөңүз! `.gitignore` файлында `.vscode/launch.json` бар экенин текшериңиз, же API ачкычын environment переменнадан алыңыз.

### 5. Fallback режими

Эгер API ачкычы жок болсо, колдонмо автоматтык түрдө **түз сызык аралыкка** кайрылат (Haversine формуласы). Бул MVP үчүн жетиштүү, бирок production үчүн Router API сунушталат.

### 6. Тестирование

Заказ түзгөндө, console'да төмөнкү логдорду көрөсүз:

```
🚗 Requesting driving route from Yandex Router API...
  From: 74.5698,42.8746
  To: 74.6000,42.8700
  ✅ Driving distance: 5.3 km
```

API ачкычы жок болсо:

```
⚠️ Yandex API key not set, using straight-line distance
  ⚠️ Falling back to straight-line distance
```

### 7. API лимиттери (бекер тариф)

- **Router API**: 1,000 requests/day
- **Geocoding API**: 1,000 requests/day

Production үчүн төлөнүүчү тарифке өтүү керек болушу мүмкүн.

---

## Көйгөйлөрдү чечүү

### API ката кайтарса

Эгер `❌ Yandex Router API error: 403` деп чыкса:
- API ачкычы туура эмес
- Router API кызматы токтотулган
- Account'угуз билинг жок

### Өтө түз аралык көрүнсө

- API ачкычы берилген эмес болушу мүмкүн
- Console'дагы логдорду текшириңиз
- Fallback режимге түшүп калган болушу мүмкүн

### API өтө жай иштесе (>10 секунд)

- Интернет байланышыңызды текшериңиз
- Yandex Cloud сервистеринин статусун текшириңиз
- Timeout азыр 15 секунд катары коюлган
