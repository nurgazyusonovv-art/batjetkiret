import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/create_order_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/payments_screen.dart';
import 'screens/profile_screen.dart';
import 'services/auth_service.dart';

class EnterpriseShell extends StatefulWidget {
  const EnterpriseShell({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<EnterpriseShell> createState() => _EnterpriseShellState();
}

class _EnterpriseShellState extends State<EnterpriseShell> {
  int _tab = 0;

  Future<void> _logout() async {
    await AuthService.deleteToken();
    widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          DashboardScreen(onGoToOrders: () => setState(() => _tab = 1)),
          const OrdersScreen(),
          const CreateOrderScreen(),
          const PaymentsScreen(),
          const MenuScreen(),
          ProfileScreen(onLogout: _logout),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF16A34A),
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Башкы',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Заказдар',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Түзүү',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.payment_outlined),
            activeIcon: Icon(Icons.payment),
            label: 'Төлөмдөр',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Меню',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
