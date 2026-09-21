# 🚀 Batken Express (БатЖеткирет) тиркемесин App Store'го жүктөө боюнча толук нускама

Бул колдонмо Flutter тиркемесин Apple App Store'го башынан аягына чейин ийгиликтүү жүктөө боюнча кадам-кадам жол көрсөтөт.

---

## 📁 1. Даярдалган файлдар жана папкалар

Долбоордо бардык керектүү документтер жана графикалык материалдар даярдалды:
1. **`app_store_assets/icon/AppStore_Icon_1024x1024.png`** — App Store Connect үчүн 1024x1024 RGB иконкасы.
2. **`app_store_assets/screenshots_6.7_inch/`** — 6.7" / 6.9" экраны үчүн 5 даана жогорку сапаттагы маркетингдик скриншот (1290 x 2796 px).
3. **`app_store_assets/screenshots_6.5_inch/`** — 6.5" экраны үчүн 5 даана скриншот (1242 x 2688 px).
4. **`app_store_assets/marketing/Feature_Graphic_1024x500.png`** — Маркетингдик промо-баннер (1024 x 500 px).
5. **`APP_STORE_METADATA.md`** — Бардык аталыштар, сүрөттөмөлөр, ачкыч сөздөр жана Apple Review демо аккаунту.
6. **`PRIVACY_POLICY.md`** — Купуялуулук саясаты (Apple 5.1.1 талабы боюнча).
7. **`TERMS_OF_SERVICE.md`** — Колдонуу шарттары.

---

## 🛠️ 2. 1-Кадам: Apple Developer аккаунтун даярдоо

1. [developer.apple.com](https://developer.apple.com) сайтына кирип, **Apple Developer Program** мүчөлүгүн ($99/жыл) активдештириңиз.
2. **Certificates, Identifiers & Profiles** бөлүмүнө өтүңүз:
   - **Identifiers** -> `+` басып -> **App IDs** -> **App** тандаңыз.
   - **Description:** `Batken Express App`
   - **Bundle ID:** `Explicit` -> `com.batkenexpress.app` (же өзүңүз тандаган ID).
   - **Capabilities:** Тизмеден `Push Notifications` белгилеңиз.
   - `Continue` -> `Register` басыңыз.

---

## 🌐 3. 2-Кадам: App Store Connect'те жаңы тиркеме түзүү

1. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) сайтына кириңиз.
2. **Apps** -> `+` (New App) басыңыз:
   - **Platforms:** `iOS`
   - **Name:** `Batken Express - БатЖеткирет`
   - **Primary Language:** `Russian` (же `English`)
   - **Bundle ID:** Жогоруда түзүлгөн `com.batkenexpress.app` тандаңыз
   - **SKU:** `BATKEN_EXPRESS_IOS_01`
   - **User Access:** `Full Access`
   - `Create` басыңыз.

---

## 📝 4. 3-Кадам: Мета-маалыматтарды жана скриншотторду жүктөө

1. **App Information (Тиркеме маалыматы):**
   - Категорияларды тандаңыз: **Primary:** `Food & Drink`, **Secondary:** `Shopping`.
   - `PRIVACY_POLICY.md` шилтемесин **Privacy Policy URL** талаасына коюңуз.
2. **Version Information (1.0.0 версиясы):**
   - **Screenshots:**
     - `6.7" / 6.9" Display` бөлүмүнө `app_store_assets/screenshots_6.7_inch/` ичиндеги 5 скриншотту жүктөңүз.
     - `6.5" Display` бөлүмүнө `app_store_assets/screenshots_6.5_inch/` ичиндеги 5 скриншотту жүктөңүз.
   - `APP_STORE_METADATA.md` файлындагы **Description**, **Keywords**, **Support URL** тексттерин тиешелүү талааларга көчүрүп коюңуз.
3. **App Review Information (Apple текшерүүчүсү үчүн):**
   - **Sign-in required:** Ооба (Yes).
   - **Demo Login:** `+996700123456`
   - **Demo Password:** `Batken2026!`
   - **Notes:** `APP_STORE_METADATA.md` ичиндеги эскертүү текстин коюңуз.
4. **Age Rating:** Сурамжылоону толтуруп `4+` же `12+` алыңыз.

---

## 📦 5. 4-Кадам: Flutter тиркемесин чогултуу (Build & Archive)

### Вариант А: Буйрук сабы (Терминал) аркылуу:

```bash
cd ~/python_projects/batjetkiret-backend/frontend

# Кэшти тазалап, көз карандылыктарды алуу
flutter clean
flutter pub get

# Релиз IPA файлын чогултуу
flutter build ipa --release
```

Чогулган `.ipa` файлы `frontend/build/ios/ipa/` папкасында пайда болот. Аны **Apple Transporter** тиркемеси аркылуу App Store Connect'ке оңой жүктөсө болот.

---

### Вариант Б: Xcode аркылуу чогултуу жана жүктөө:

1. Xcode долбоорун ачыңыз:
   ```bash
   open ~/python_projects/batjetkiret-backend/frontend/ios/Runner.xcworkspace
   ```
2. Xcode ичинде:
   - **Runner** максатын тандаңыз -> **Signing & Capabilities** өтүңүз.
   - **Team:** Өзүңүздүн Apple Developer аккаунтуңузду тандаңыз.
   - **Bundle Identifier:** `com.batkenexpress.app` экенин текшериңиз.
3. Түзмөк катары **Any iOS Device (arm64)** тандаңыз.
4. Үстүңкү менюдан: **Product** -> **Archive** басыңыз.
5. Архив бүткөндө **Organizer** терезеси ачылат -> **Distribute App** -> **App Store Connect** -> **Upload** басыңыз.

---

## 🧪 6. 5-Кадам: TestFlight жана Текшерүүгө жөнөтүү

1. Жүктөлгөн жыйынтык 10-15 мүнөттө App Store Connect'те пайда болот.
2. **TestFlight** бөлүмүнөн командаңыз менен тестирлеп көрүңүз.
3. Баары туура иштесе, **App Store** өтмөгүнө кайтып:
   - **Build** бөлүмүнөн жүктөлгөн билдди тандаңыз.
   - **Export Compliance:** `No` (стандарттуу шифрлөө / HTTPS).
   - Жогорку оң бурчтан **Submit for Review** (Текшерүүгө жөнөтүү) баскычын басыңыз.
4. Apple адатта 24-48 сааттын ичинде тиркемени текшерип, бекитет (Approved).

---

🎉 **Куттуктайбыз! Сиздин тиркемеңиз дүйнө жүзү боюнча App Store'до жарыяланат!**
