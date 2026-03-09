# iOS Simulator - Рабочее решение 🚀

## Проблема
- Flutter 3.41.4 + Xcode 26.2 имеют несовместимость с debugger (VM Service / DDS)
- Приложение **успешно компилируется и работает**, но debugger теряет соединение
- Это **не проблема кода**, а проблема Flutter framework версии

## ✅ Решение: Запуск БЕЗ debugger

Используйте эту команду для запуска приложения на iOS:

```bash
# Вариант 1: Простой запуск (рекомендуется)
cd ~/python_projects/batjetkiret-backend/frontend
flutter run -d "iPhone 17" --detach

# Вариант 2: С логами
cd ~/python_projects/batjetkiret-backend/frontend
flutter build ios --debug
xcrun simctl launch booted com.example.batJetkiret

# Вариант 3: Создать алиас для удобства
alias run-ios='flutter run -d "iPhone 17" --detach'
# Затем: run-ios
```

## 📋 Как работает

1. **`--detach`** запускает приложение БЕЗ подключения debugger
2. Приложение запускается и работает нормально
3. Debugger НЕ подключается (это избегает ошибки "Connection refused")
4. Приложение остается работающим в симуляторе

## ✨ Дополнительные команды

```bash
# Убить приложение с симулятора
xcrun simctl terminate booted com.example.batJetkiret

# Перезагрузить приложение
xcrun simctl uninstall booted com.example.batJetkiret
flutter install

# Очистить всё и пересобрать
flutter clean
flutter pub get
flutter run -d "iPhone 17" --debug
```

## 🌐 Альтернатива: Используйте Chrome для development

Chrome имеет **полную поддержку debugger** и hot reload:

```bash
flutter run -d "chrome"
```

**Преимущества Web:**
- ✅ Полный debugger и DevTools
- ✅ Hot reload работает идеально  
- ✅ Вся функция приложения работает
- ✅ Быстрее компилируется

## 📱 Android (если нужно)

APK готов к построению:

```bash
flutter build apk --release
```

## 🔧 Если всё ещё не работает

1. Убедитесь, что backend работает на `http://localhost:8000`
2. Проверьте логи:
   ```bash
   flutter run -d "iPhone 17" -v 2>&1 | grep -i error
   ```
3. Перезагрузите симулятор: 
   ```bash
   xcrun simctl erase iPhone\ 17
   ```

## ⚡ Быстрая диагностика

```bash
# Проверяем компиляцию
flutter analyze

# Проверяем, есть ли проблемы с кодом
flutter doctor -v

# Запускаем на Chrome (работает идеально!)
flutter run -d "chrome"
```

---

**Статус проекта:** ✅ Code Ready | ✅ Web Working | ✅ iOS Builds | ⚠️ iOS Debugger (Framework limitation)
