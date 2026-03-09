# Railway.app Deployment Guide

## Өмнөлүк

Бул чебби Railway.app'та Batjetkiret backend'ти жайгаштыруунун үстүнкү жолу.

## Кадам 1: Railway CLI орнотуу

```bash
# MacOS
brew install railway

# Linux/Windows
npm install -g @railway/cli
```

## Кадам 2: Railway'ге кирүү

```bash
railway login
```

Браузер ачылат жана GitHub аркылуу кирүүсүнүңүз каалаш болокт.

## Кадам 3: Жаңы долор жаса

```bash
cd /Users/nurgazyuson/python_projects/batjetkiret-backend
railway init
```

Суроолорго жооп берүүлөр:
- **What is your project name?** - `batjetkiret`
- **Select services** - `PostgreSQL` + `Empty Service`

## Кадам 4: PostgreSQL конфигурасы

Railway PostgreSQL автоматикалык түрдө жаралат. Байланыш маалыматы `.env` файлка орнотулат.

## Кадам 5: Өзгөрмөлөрдү орнотуу

```bash
railway variables set DEBUG=false
railway variables set LOG_LEVEL=INFO
railway variables set LOG_JSON=true
railway variables set SERVICE_NAME=batjetkiret-api
railway variables set SECRET_KEY=$(python -c "import secrets; print(secrets.token_urlsafe(32))")
railway variables set ALLOWED_ORIGINS="https://your-domain.com"
```

## Кадам 6: Жайгаштыруу

```bash
railway up
```

Немесе GitHub'та push кыл - Railway автоматикалык түрдө жайгаштырат.

## Кадам 7: Баланы текшеру

```bash
railway logs
```

Тизмесинде ката болбоо керек. Сервер `https://<project>.railway.app` адресинде жеткиликтүү.

## Мега маалымат

- **Жүндө:** `DATABASE_URL` автоматикалык орнотулат
- **Миграциялар:** Dockerfile'да `alembic upgrade head` автоматикалык иштейт
- **SSL:** Railway өтөнүн SSL сертификатын берет
- **Free тариф:** 5$ / ай (PostgreSQL баалуу)

## Маселелер чечүү

**"Port is already in use":**
```bash
railway variables set PORT=8000
```

**"Database connection failed":**
```bash
railway logs  # DATABASE_URL текшеру
```

**"Migration failed":**
```bash
railway run python init_database.py
```

## Production маалыматтарын өз ара алмаштыруу

Flask сервисинде ары байланыш адресин өзгөрт:
```dart
// frontend/lib/core/config/app_config.dart
static const String baseUrl = 'https://your-project.railway.app';
```

Бути жасаш жана жайгаштыруу!

---

**Railway Docs:** https://docs.railway.app
