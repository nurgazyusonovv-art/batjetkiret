# Order Management с Cubit - Архитектързалык ачкочу

## Окуу максаты

Бул документ `batjetkiret-backend` жобасындагы Заказдарга байланышкан бардык экрандарды Cubit менен иштей турган кырдаал түйлөнүүнүн құрылышын түшүндүрөт.

## Architecture Overview

```
Order Screens (Presentation)
    ↓
├── MyOrdersPage
├── OrderHistoryPage  
├── OrderDetailPage
└── HomePage (orders section)
    ↓
Cubits (State Management)
    ↓
├── OrdersCubit (list operations)
└── OrderDetailCubit (single order operations)
    ↓
Repositories (Data Layer)
    ↓
OrderApi (HTTP requests)
```

## Cubits

### 1. OrdersCubit
**Жооп бери:** Колдонуучунун/курьердин бардык заказдарын башкаруу

**State:** `OrdersState`
- `orders: List<Order>` - Заказдардын тизмеси
- `isLoading: bool` - Жүктөө абалы
- `error: String?` - Ката билдирээ
- `isCourier: bool` - Жура курьер же жөнөөтчү

**Методдору:**
```dart
// Бардык заказдарды жүктөө
loadOrders(String token)

// Аутентификация аркылуу гидратировка
hydrateOnAuth(String? token)

// Бир заказды листста өндөтүү
updateOrder(Order updatedOrder)

// Бир заказды тизмеден чыгаруу
removeOrder(int orderId)

// Абалды тазалоо
clear()
```

**Utility методдору в State:**
```dart
// ID боюнча заказды издөө
Order? getOrderById(int id)

// Белсел заказдарды алуу
List<Order> getActiveOrders()

// Аяктагандарды алуу
List<Order> getCompletedOrders()
```

### 2. OrderDetailCubit
**Жооп бери:** бир заказтын деталдүүлүгүн жана макула сентимент операцияларын башкаруу

**State:** `OrderDetailState`
- `currentOrder: Order` - Учурдагы заказ
- `isUpdatingStatus: bool` - Статус жаңылануучабы
- `isReloading: bool` - Кайра жүктөлүүчүбү
- `error: String?` - Ката

**Status операцияларынын чөйрөсү:**
- `acceptOrder(token)` - курьер тарабынан кабыл алуу (WAITING_COURIER → ACCEPTED)
- `startDelivery(token)` - чыгарууну баштоо (ACCEPTED → IN_TRANSIT)
- `markDelivered(token)` - берилгени белгилөө (IN_TRANSIT → DELIVERED)
- `completeDelivery(token, code)` - таасыктоо кодусу менен белгилөө (DELIVERED → COMPLETED)

**Кайра жүктөө:**
```dart
reloadCurrentOrder({
  required String? token,
  required bool isCourier,
})
```

## Order Model

`Order` моделина жаңы `copyWith` методу кошулду:

```dart
Order updatedOrder = order.copyWith(
  status: 'accepted',
  verificationCode: '123456',
);
```

Барлык өзүлүктүн сакалануу:
- `id`, `category`, `fromAddress`, `toAddress`, `distance`
- `status`, `description`, `estimatedPrice`
- `courierName`, `courierPhone`, `courierId`
- `userName`, `userPhone`, `userId`
- `createdAt`, `verificationCode`

## Экрандардын иштөөсү

### MyOrdersPage
**Колдонуйт:** `OrdersCubit`
**BlocBuilder генис:** `OrdersState` менен фильтрүүлөө
- Жалпы / Күтүндө / Белсел / Аяктагандар

### OrderHistoryPage
**Колдонуйт:** `OrdersCubit`
**BlocBuilder генис:** `OrdersState` менен издөө жана фильтрүүлөө
- 7 күн, 30 күн, бул ай

### OrderDetailPage
**Колдонуйт:** `OrderDetailCubit`
**Статус операциялары:**
- Курьер үчүн: Accept → Start → Mark Delivered → Complete
- Колдонуучу үчүн: чат, утар, отмена

### HomePage  
**Колдонуйт:** `OrdersCubit` + `OrderCreateCubit`
**Аңдоо:**
- Курьер үчүн: берилүүсүн кайта жүктөө
- Жаңы заказ түзүүдөн кийин рефреш

## Error Handling

**Бардык Cubits:**
- Ката кызмат-коё каза менен үнүмөө чокусуна чүютөтмк
- Ката Cubit аркылуу UI ге серилет
- Экран ената боюнча сүндөбөсүндөн күчтүүнө эки брашаны эке-каттуута

**UI компоненттери:**
```dart
BlocBuilder<OrdersCubit, OrdersState>(
  builder: (context, state) {
    if (state.isLoading) {
      return LoadingWidget();
    }
    if (state.error != null) {
      return ErrorWidget(error: state.error);
    }
    return OrdersList(orders: state.orders);
  },
)
```

## Best Practices

1. **State читиш:** `context.read<Cubit>()` - когда нужна синхронная операция
2. **State наблюдение:** `BlocBuilder`, `BlocListener` - когда нужна реакция на изменения
3. **Консолидация:** Всегда истеользуйте `copyWith` методы
4. **Ошибки:** Всегда используйте `clearError` флаг после восстановления

## Разработка

### Добавление новой операции

1. Добавить метод в Cubit:
```dart
Future<void> myNewOperation(String token) async {
  emit(state.copyWith(isLoading: true, clearError: true));
  try {
    // операция
    emit(state.copyWith(isLoading: false, ...));
  } catch (error) {
    emit(state.copyWith(isLoading: false, error: error.toString()));
  }
}
```

2. Обновить State класс если нужны новые поля:
```dart
// В copyWith добавить параметр и обновить конструктор
```

3. Использовать в UI:
```dart
context.read<OrdersCubit>().myNewOperation(token);
```

## Проверка

✅ `flutter analyze` - синтаксис проверен
✅ Всех экранов используют Cubits
✅ State управление консистентно
✅ Error обработка везде присутствует
✅ Order данные полностью сохраняются при обновлении
