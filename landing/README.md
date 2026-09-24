# batjetkiret.vercel.app

Тиркемени бөлүшүү үчүн бир шилтеме. Кирген адам өз түзмөгүнө жараша
App Store же Google Play'ге өтөт.

Куру процесси жок — жөн гана статикалык файлдар:

| Файл | Эмне |
|---|---|
| `index.html` | беттин өзү (CSS жана JS ичинде) |
| `logo.png` | башкы логотип |
| `icon-180.png` | favicon / apple-touch-icon |
| `og.png` | WhatsApp, Telegram'да чыга турган 1200×630 сүрөт |
| `vercel.json` | сүрөттөр үчүн кэш аталыштары |

## Жаңылоо

Бул долбоор азырынча GitHub'ка туташкан эмес — Vercel аккаунтуна
GitHub Login Connection кошулгандан кийин гана туташат. Ошол себептен
жаңылоо кол менен жүргүзүлөт:

    vercel deploy --prod --scope nurgazyusonovv-7161s-projects

## Дүкөн шилтемелери

`index.html` ичинде, эки жерде. Алар тиркеменин чыныгы ID'лерине
байланыштуу — өзгөртсөңүз экөөнү тең текшериңиз:

- iOS — `com.batkenexpress.app` → `id6804351978`
- Android — `kg.batkenexpress.app`

Ошол эле шилтемелер басма материалдардагы QR коддордо да колдонулат.
