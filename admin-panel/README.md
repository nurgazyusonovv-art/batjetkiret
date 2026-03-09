# BATJETKIRET Admin Panel

Веб админ панель React + TypeScript + Vite менен түзүлгөн.

## Функционалдык

- ✅ **Dashboard** - Системанын жалпы статистикасы  
- ✅ **Заказдар** - Бардык заказдарды көрүү жана башкаруу
- ✅ **Колдонуучулар** - Колдонуучуларды блоктоо/анблоктоо
- ✅ **Топап** - Баланс толтуруу өтүнүчторүн тастыктоо  
- 🔐 **Коопсуздук** - JWT токендер, админ гана кире алат

## Орнотуу

```bash
cd admin-panel
npm install
```

## Development режимде иштетүү

```bash
npm run dev
```

Админ панель `http://localhost:3001` дарегинде ачылат.

Backend автоматтык түрдө `http://localhost:8000`ге proxy кылынат.

## Production build

```bash
npm run build
npm run preview
```

## Environment Variables

`.env` файл түзүп, төмөнкүлөрдү жазыңыз:

```bash
VITE_API_BASE_URL=http://localhost:8000
```

Production үчүн:

```bash
VITE_API_BASE_URL=https://your-api-domain.com
```

## Технологиялар

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Vite** - Build tool (тез build)
- **React Router** - Client-side routing
- **Axios** - HTTP client
- **Lucide React** - Icons

## Структура

```
admin-panel/
├── src/
│   ├── components/     # UI компоненттер
│   ├── pages/         # Беттер (Dashboard, Orders, Users...)
│   ├── services/      # API интеграция
│   ├── types/         # TypeScript типтер
│   ├── App.tsx        # Негизги компонент
│   └── main.tsx       # Entry point
├── package.json
├── tsconfig.json
└── vite.config.ts
```

## Backend Requirements

Backend төмөнкү endpoint'терди колдоп жиберүүсү керек:

- `POST /auth/login` - Админ авторизация
- `GET /admin/stats` - Системанын статистикасы
- `GET /admin/orders` - Заказдар тизмеси
- `GET /admin/users` - Колдонуучулар тизмеси
- `GET /admin/topup/pending` - Күтүүдөгү топаптар
- `POST /admin/topup/{id}/approve` - Топапты тастыктоо
- `POST /admin/topup/{id}/reject` - Топапты четке кагуу
- `POST /admin/users/{id}/block` - Колдонуучуну блоктоо
- `POST /admin/users/{id}/unblock` - Колдонуучуну анблоктоо

## Login

Админ панелге кирүү үчүн backend'де `role='admin'` болуусу керек.

Test credentials:
- Phone: +996700000001 (же башка админ номери)
- Password: (сиздин admin password)
