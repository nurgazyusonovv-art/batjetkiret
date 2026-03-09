# Refresh Intervals Configuration

Приложение поддерживает конфигурируемые интервалы обновления данных без изменения кода. Интервалы настраиваются через `--dart-define` флаг при сборке.

## Доступные параметры

| Параметр | Описание | Значение по умолчанию | Единица |
|----------|---------|----------------------|--------|
| `REFRESH_HOME_ACTIVE_INTERVAL` | Домашняя страница (когда есть заказы) | 5 | секунды |
| `REFRESH_HOME_IDLE_INTERVAL` | Домашняя страница (когда нет заказов) | 15 | секунды |
| `REFRESH_ORDERS_ACTIVE_INTERVAL` | Заказы (активные заказы) | 5 | секунды |
| `REFRESH_ORDERS_IDLE_INTERVAL` | Заказы (без активных) | 12 | секунды |
| `REFRESH_PROFILE_INTERVAL` | Профиль | 30 | секунды |
| `REFRESH_MAX_BACKOFF_MINUTES` | Максимальный backoff при ошибках | 1 | минуты |

## Как использовать

### Development (по умолчанию)
```bash
flutter run
# Используются значения по умолчанию: Home 5s, Orders 5s, Profile 30s
```

### Testing (тестирование на ускорение)
```bash
flutter run \
  --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=3 \
  --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=3 \
  --dart-define=REFRESH_PROFILE_INTERVAL=10
```

### Production (оптимизованный)
```bash
flutter build apk --release \
  --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=8 \
  --dart-define=REFRESH_HOME_IDLE_INTERVAL=20 \
  --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=8 \
  --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=15 \
  --dart-define=REFRESH_PROFILE_INTERVAL=60 \
  --dart-define=REFRESH_MAX_BACKOFF_MINUTES=2
```

### iOS
```bash
flutter build ios --release \
  --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=8 \
  --dart-define=REFRESH_HOME_IDLE_INTERVAL=20 \
  --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=8 \
  --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=15 \
  --dart-define=REFRESH_PROFILE_INTERVAL=60
```

### Web
```bash
flutter build web --release \
  --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=10 \
  --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=10 \
  --dart-define=REFRESH_PROFILE_INTERVAL=45
```

## Рекомендуемые конфигурации

### Для MVP / Testing
```
Home Active: 5s
Home Idle: 15s
Orders Active: 5s
Orders Idle: 12s
Profile: 30s
Max Backoff: 1m
```
*Быстрое обновление, проще заметить изменения во время разработки*

### Для Production (стандартное)
```
Home Active: 8s
Home Idle: 20s
Orders Active: 8s
Orders Idle: 15s
Profile: 60s
Max Backoff: 2m
```
*Баланс между UX и нагрузкой на сервер*

### Для High-Scale Production
```
Home Active: 15s
Home Idle: 30s
Orders Active: 15s
Orders Idle: 30s
Profile: 120s
Max Backoff: 5m
```
*Минимальная нагрузка на сервер и батарею*

## Как это работает

1. **Адаптивная логика**: Интервал зависит от данных
   - Если есть активные заказы → используется `ACTIVE_INTERVAL`
   - Если заказов нет → используется `IDLE_INTERVAL`
   - Профиль обновляется постоянно с `PROFILE_INTERVAL`

2. **Exponential Backoff**: При ошибках интервал растет (x2, x4, x8...) до `MAX_BACKOFF_MINUTES`

3. **Lifecycle-aware**: Refresh токтатылат когда app в background, возобновляется при resume

4. **Concurrent safety**: Одновременный refresh не может запуститься дважды

## Окружение переменные (альтернатива)

Если используете `.env` файл (с `flutter_dotenv`):
```env
REFRESH_HOME_ACTIVE_INTERVAL=8
REFRESH_HOME_IDLE_INTERVAL=20
REFRESH_ORDERS_ACTIVE_INTERVAL=8
REFRESH_ORDERS_IDLE_INTERVAL=15
REFRESH_PROFILE_INTERVAL=60
REFRESH_MAX_BACKOFF_MINUTES=2
```

Затем в `main.dart`:
```dart
await dotenv.load(fileName: '.env');
```

## CI/CD Integration

### GitHub Actions пример
```yaml
- name: Build APK with Production Config
  run: |
    flutter build apk --release \
      --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=8 \
      --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=8 \
      --dart-define=REFRESH_PROFILE_INTERVAL=60
```

## Remote Config (будущее)

Для полностью динамической конфигурации без переиностваки можно добавить Firebase Remote Config:

```dart
// В будущем:
final config = await FirebaseRemoteConfig.instance.fetch();
final homeInterval = config.getInt('refresh_home_active_interval');
```

Это позволит менять интервалы на лету без пересборки приложения.

## Troubleshooting

**Q: Intevral не меняется при запуске с `--dart-define`**
A: Убедитесь что:
1. Флаг передан корректно (без typo в имени)
2. Значение — это число (без кавычек или символов)
3. Используются underscores в имени переменной (не дефисы)

**Q: Как понять какие значения сейчас использует приложение?**
A: Добавьте в `ProfilePage` отладочный widget:
```dart
Text('Intervals: Home ${AppConfig.homeActiveInterval.inSeconds}s, Orders ${AppConfig.ordersActiveInterval.inSeconds}s')
```

**Q: Хочу интервалы снизу управлять (remote config)?**
A: Предусмотрена архитектура для добавления Firebase Remote Config или API endpoint для конфигурации.
