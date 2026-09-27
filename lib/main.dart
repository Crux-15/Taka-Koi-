import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/group_controller.dart';
import 'controllers/expense_controller.dart';
import 'controllers/debt_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/theme_controller.dart';
import 'firebase_options.dart';
import 'utils/app_theme.dart';
import 'utils/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Init ──────────────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // ── Enable Firestore Offline Persistence ───────────────────────────────────
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled:  true,
    cacheSizeBytes:      Settings.CACHE_SIZE_UNLIMITED,
  );

  // ── Theme Controller (load persisted preference) ───────────────────────────
  final themeCtrl = ThemeController();
  await themeCtrl.loadTheme();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(     create: (_) => themeCtrl),
        ChangeNotifierProvider<AuthController>(      create: (_) => AuthController()),
        ChangeNotifierProvider<GroupController>(     create: (_) => GroupController()),
        ChangeNotifierProvider<ExpenseController>(   create: (_) => ExpenseController()),
        ChangeNotifierProvider<DebtController>(      create: (_) => DebtController()),
        ChangeNotifierProvider<NotificationController>(create: (_) => NotificationController()),
      ],
      child: const TourExpenseApp(),
    ),
  );
}

class TourExpenseApp extends StatefulWidget {
  const TourExpenseApp({super.key});

  @override
  State<TourExpenseApp> createState() => _TourExpenseAppState();
}

class _TourExpenseAppState extends State<TourExpenseApp> {
  late final _router = buildAppRouter(context);

  @override
  void initState() {
    super.initState();
    // Auth listener is started in SplashView so it can properly await authReady.
    // Do NOT call listenToAuthChanges() here — it would create a duplicate stream.
  }

  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeController>();

    return MaterialApp.router(
      title:            'Tour Tracker',
      debugShowCheckedModeBanner: false,
      themeMode:        themeCtrl.themeMode,
      theme:            AppTheme.light,
      darkTheme:        AppTheme.dark,
      routerConfig:     _router,
    );
  }
}
