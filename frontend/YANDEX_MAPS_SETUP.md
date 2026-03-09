# Yandex Maps Platform Конфигурациясы

## ✅ Аткарылган конфигурациялар

### Android
- ✅ Location permissions кошулду (ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, INTERNET)
- ✅ Yandex MapKit API key meta-data конфигурацияланды
- ✅ minSdkVersion 21 коюлду

### iOS  
- ✅ Platform version 11.0 коюлду
- ✅ Deployment target 11.0 бардык pods үчүн
- ✅ Location permissions кошулду (NSLocationWhenInUseUsageDescription)

## 🔑 Yandex API ключин алуу

1. **Yandex Cloud консолуна кириңиз**: https://console.yandex.cloud/
2. **Проектти тандаңыз же жаңысын түзүңүз**
3. **Services → Map API** бөлүмүнө өтүңүз
4. **API ключин жаратыңыз**
5. Ключди коопсуз сактап, `local.properties` файлына кошуңуз

## 📱 Билдирүүнү жүргүзүү

### Android

```bash
# 1. local.properties файлына API ключти кошуңуз (android/ папкасында)
echo "YANDEX_MAPKIT_API_KEY=ваш_api_ключ_здесь" >> android/local.properties

# 2. Dependencies жүктөө
flutter pub get

# 3. Android билдирүү
flutter build apk --dart-define=YANDEX_API_KEY=ваш_api_ключ_здесь

# 4. Же development режимде иштетүү
flutter run -d android --dart-define=YANDEX_API_KEY=ваш_api_ключ_здесь
```

### iOS

```bash
# 1. Pods орнотуу
cd ios
pod install
cd ..

# 2. Flutter dependencies жүктөө
flutter pub get

# 3. iOS билдирүү
flutter build ios --dart-define=YANDEX_API_KEY=ваш_api_ключ_здесь

# 4. Же development режимде иштетүү
flutter run -d ios --dart-define=YANDEX_API_KEY=ваш_api_ключ_здесь
```

## 🧪 Тестирлөө

### MockGeocoder менен тест (API ключсиз)

```bash
# API ключсиз иштейт - MockGeocoder колдонулат
flutter run
```

Колдонууга жеткиликтүү шаарлар:
- Бишкек (42.8746, 74.5698)
- Ош (42.4872, 72.7981)
- Нарын (41.4289, 76.1665)
- Жалал-Абад (41.9328, 74.4968)

### RealGeocoder менен тест (Yandex API)

```bash
# API ключ менен - Yandex geocoding иштейт
flutter run --dart-define=YANDEX_API_KEY=ваш_api_ключ
```

### Аралык калкуляциясын текшерүү

Заказ түзүү экранында:
1. "Бишкек" дан "Ош" га адрестерди киргизиңиз
2. Аралык автоматтык түрдө ~598 км болушу керек

## 🔧 Мүчүлүштөрдү чечүү

### Android: "Yandex MapKit initialization failed"
**Чечим**: `android/local.properties` файлында `YANDEX_MAPKIT_API_KEY` туура коюлганын текшериңиз

### iOS: "Pod install fails"
**Чечим**:
```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
cd ..
```

### "Location permission denied"
**Чечим**: 
- Android: Колдонмо Settings → Permissions → Location бөлүмүндө уруксат бериңиз
- iOS: Биринчи ирет ачканда уруксат сурайт, "Allow" басыңыз

### Build ката берсе
**Чечим**:
```bash
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter run
```

## 📦 Production билдирүү

### Android APK/AAB

```bash
# Environment variables менен
export YANDEX_API_KEY="ваш_production_api_ключ"
flutter build apk --release --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY

# AAB (Google Play үчүн)
flutter build appbundle --release --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY
```

### iOS IPA

```bash
# Environment variables менен
export YANDEX_API_KEY="ваш_production_api_ключ"
flutter build ios --release --dart-define=YANDEX_API_KEY=$YANDEX_API_KEY

# Xcode аркылуу
# 1. ios/Runner.xcworkspace ачыңыз
# 2. Product → Archive
# 3. Distribute App → App Store Connect
```

## 🎯 Кийинки кадамдар

1. ✅ Platform конфигурациясы (аткарылды)
2. ⏳ Yandex Cloud консолдон API ключ алуу
3. ⏳ Production үчүн API ключтерди CI/CD секреттерге кошуу
4. ⏳ MapPicker виджетин заказ түзүү экранына интеграциялоо
5. ⏳ Real geocoding менен тестирлөө
6. ⏳ Production билдирүү жана TestFlight/Play Store жүктөө

## 📚 Кошумча ресурстар

- [Yandex MapKit документация](https://yandex.com/dev/maps/mapkit/)
- [Flutter Yandex MapKit plugin](https://pub.dev/packages/yandex_mapkit)
- [Android конфигурация guide](ANDROID_YANDEX_MAPS_CONFIG.md)
- [iOS конфигурация guide](IOS_YANDEX_MAPS_CONFIG.md)

## 🆘 Жардам керек болсо

Документацияларды караңыз же сурооңузду бериңиз!
