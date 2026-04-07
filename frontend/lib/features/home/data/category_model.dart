class Category {
  final String id;
  final String name;
  final String icon;

  Category({required this.id, required this.name, required this.icon});
}

// Available categories
final List<Category> categories = [
  Category(id: 'food', name: 'Тамак-аш', icon: 'assets/images/category/1.png'),
  Category(id: 'taxi', name: 'Такси', icon: 'assets/images/category/2.png'),
  Category(
    id: 'intercity',
    name: 'Шаарлар аралык',
    icon: 'assets/images/category/3.png',
  ),
  Category(
    id: 'groceries',
    name: 'Азык-түлүк',
    icon: 'assets/images/category/4.png',
  ),
  Category(
    id: 'pharmacy',
    name: 'Дарыкана',
    icon: 'assets/images/category/5.png',
  ),
  Category(
    id: 'clothes',
    name: 'Кийим-кече',
    icon: 'assets/images/category/6.png',
  ),
  Category(
    id: 'electronics',
    name: 'Электроника',
    icon: 'assets/images/category/7.png',
  ),
  Category(
    id: 'household',
    name: 'Үй-тиричилик буюмдары',
    icon: 'assets/images/category/8.png',
  ),
  Category(
    id: 'autoparts',
    name: 'Унаа тетиктери',
    icon: 'assets/images/category/9.png',
  ),
  Category(
    id: 'flowers',
    name: 'Гүлдөр',
    icon: 'assets/images/category/10.png',
  ),
  Category(
    id: 'documents',
    name: 'Документтер',
    icon: 'assets/images/category/11.png',
  ),
  Category(id: 'other', name: 'Башка', icon: 'assets/images/category/12.png'),
];
