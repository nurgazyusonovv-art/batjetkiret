# Настройка интервалов обновления - быстрый старт

## TL;DR - 3 команды для старта

### Dev режим (default, никого флага не нужно)
```bash
cd frontend && flutter run
```
Используются значения по умолчанию: Home 5s, Orders 5s, Profile 30s

### Testing (ускоренный режим для демонстрации)
```bash
cd frontend && flutter run \
  --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=2 \
  --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=2 \
  --dart-define=REFRESH_PROFILE_INTERVAL=5
```

### Production (оптимизированный)
```bash
cd frontend && flutter build apk --release \
  --dart-define=REFRESH_HOME_ACTIVE_INTERVAL=15 \
  --dart-define=REFRESH_HOME_IDLE_INTERVAL=30 \
  --dart-define=REFRESH_ORDERS_ACTIVE_INTERVAL=15 \
  --dart-define=REFRESH_ORDERS_IDLE_INTERVAL=30 \
  --dart-define=REFRESH_PROFILE_INTERVAL=120 \
  --dart-define=REFRESH_MAX_BACKOFF_MINUTES=5
```

## Как это работает

1. **Параметры окружения** передаются при сборке через `--dart-define`
2. **AppConfig класс** ([lib/core/config.dart](lib/core/config.dart)) читает эти параметры
3. **MainNavigation** использует значения из AppConfig для управления refresh'ем
4. **Без кода** - просто измените параметры при сборке

## Где что находится

| Файл | Описание |
|------|---------|
| [lib/core/config.dart](lib/core/config.dart) | Конфиг класс с параметрами |
| [lib/main.dart](lib/main.dart) | Navigation логика с refresh цикло |
| [build_flutter.sh](build_flutter.sh) | Удобный скрипт для сборки с разными профилями |
| ../REFRESH_INTERVALS_CONFIG.md | Полная документация |
| ../frontend/CI_CD_EXAMPLES.md | Примеры для GitHubActions, GitLab, FastLane и т.д |

## Готовые профили

### Для быстрого тестирования
```bash
./build_flutter.sh test
```

### Для продакшна
```bash
./build_flutter.sh production
```

### Для iOS
```bash
./build_flutter.sh ios-prod
```

## Что задается

| Параметр | MVP default | Production |
|----------|------------|-----------|
| Home (активные заказы) | 5s | 15s |
| Home (нет заказов) | 15s | 30s |
| Orders (активные) | 5s | 15s |
| Orders (нет активных) | 12s | 30s |
| Profile | 30s | 120s |
| Max Backoff (ошибки) | 1m | 5m |

## Основная идея

- **Адаптивный refresh**: интервал меняется в зависимости от того есть ли активные заказы
- **Exponential backoff**: при ошибках интервал удлиняется (2x, 4x, 8x...)
- **Lifecycle-aware**: refresh останавливается в background'е, возобновляется при foreground
- **Zero downtime**: интервалы менятся без переiстановки и redeploy'ment

## Для CI/CD

Примеры для автоматической сборки с разными параметрами:
- GitHub Actions
- GitLab CI
- Fastlane
- Docker
- Cloud Build
- CodeBuild

Смотри [CI_CD_EXAMPLES.md](CI_CD_EXAMPLES.md)

## Что дальше

- Первый шаг: `./build_flutter.sh test` и проверить что refresh работает
- Второй шаг: Настроить для вашего сервера (сколько RPS выдерживает)
- Третий шаг: Добавить remote config для изменения параметров на лету без переиностваки
