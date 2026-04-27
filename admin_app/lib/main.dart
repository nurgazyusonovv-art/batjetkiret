import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/login_screen.dart';
import 'screens/reset_requests_screen.dart';
import 'screens/topup_screen.dart';
import 'screens/support_chats_screen.dart';
import 'screens/cancel_requests_screen.dart';
import 'services/auth_service.dart';

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

const _channelId = 'admin_resets';
const _channelName = 'Сырсөз өтүнүчтөрү';

const _androidChannel = AndroidNotificationChannel(
  _channelId,
  _channelName,
  importance: Importance.max,
  enableVibration: true,
  playSound: true,
  showBadge: true,
);

const _notificationDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    _channelName,
    importance: Importance.max,
    priority: Priority.max,
    enableVibration: true,
    playSound: true,
    fullScreenIntent: true,
  ),
);

// App жабык болгондо да иштейт — өзүнчө isolate'та чалынат
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Канал жана notification plugin'ди фондо да инициализациялайбыз
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: androidSettings));

  await plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(const AndroidNotificationChannel(
        _channelId,
        _channelName,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      ));

  final title = message.notification?.title ??
      message.data['title'] ??
      '🔑 Жаңы сырсөз өтүнүчү';
  final body = message.notification?.body ?? message.data['body'] ?? '';

  await plugin.show(
    message.hashCode,
    title,
    body,
    _notificationDetails,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Background handler'ды эрте катталганы маанилүү
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await localNotifications.initialize(
    const InitializationSettings(android: androidSettings),
  );

  // Канал түзөбүз — маанилүүлүгү MAX болушу керек heads-up үчүн
  await localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);

  // Notification уруксаты
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    criticalAlert: true,
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // FCM token жаңырса — backend'ке жиберебиз
  FirebaseMessaging.instance.onTokenRefresh.listen((_) {
    AuthService.uploadFcmToken();
  });

  runApp(const AdminApp());
}

Future<void> showLocalNotification(String title, String body) async {
  await localNotifications.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    _notificationDetails,
  );
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Баткен Экспрес Админ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFDC2626)),
        useMaterial3: true,
      ),
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatefulWidget {
  const AppEntry({super.key});

  @override
  State<AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<AppEntry> with WidgetsBindingObserver {
  bool _checking = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAuth();
    _setupFCMForeground();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _loggedIn) {
      AuthService.uploadFcmToken();
    }
  }

  Future<void> _checkAuth() async {
    final token = await AuthService.getToken();
    if (token != null) {
      AuthService.uploadFcmToken();
    }
    setState(() {
      _loggedIn = token != null;
      _checking = false;
    });
  }

  void _setupFCMForeground() {
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ??
          message.data['title'] ??
          '🔑 Жаңы өтүнүч';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      showLocalNotification(title, body);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loggedIn) return const HomeScreen();
    return LoginScreen(onLogin: () => setState(() => _loggedIn = true));
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _screens = [
    ResetRequestsScreen(),
    TopUpScreen(),
    SupportChatsScreen(),
    CancelRequestsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        selectedItemColor: const Color(0xFFDC2626),
        unselectedItemColor: const Color(0xFF9CA3AF),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.lock_reset),
            label: 'Сырсөз',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Топап',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.support_agent),
            label: 'Колдоо',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cancel_outlined),
            label: 'Жокко чыг.',
          ),
        ],
      ),
    );
  }
}
