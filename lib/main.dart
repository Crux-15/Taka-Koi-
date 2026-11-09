import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'utils/app_constants.dart';
import 'utils/app_router.dart';

/// Development only: build with `--dart-define=USE_EMULATORS=true` to run
/// against the local Firebase emulators and their test data instead of the
/// real project (see rules_test/README.md). Normal builds never set it.
const bool _useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// The website's address (Cloudflare Pages).
const webHost = 'taka-koi.pages.dev';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bundled fonts are open-licensed; list them on the licences page.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Montserrat', 'Work Sans'], text);
  });

  // ── Firebase Init ──────────────────────────────────────────────────────────
  if (_useEmulators) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform.copyWith(
        projectId:     'demo-taka-koi',
        storageBucket: 'demo-taka-koi.appspot.com',
      ),
    );
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android ? '10.0.2.2' : 'localhost';
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  } else {
    var options = DefaultFirebaseOptions.currentPlatform;
    // On the website, Google sign-in goes through the site's own /__/auth/
    // address (passed on to Firebase by cloudflare/functions), so iPhone
    // Safari's privacy rules don't block the sign-in pop-up.
    if (kIsWeb && Uri.base.host == webHost) options = options.copyWith(authDomain: webHost);
    await Firebase.initializeApp(options: options);

    // ── Enable Firestore Offline Persistence ─────────────────────────────────
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled:  true,
      cacheSizeBytes:      Settings.CACHE_SIZE_UNLIMITED,
    );
  }

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
      title:            AppConstants.appName,
      debugShowCheckedModeBanner: false,
      themeMode:        themeCtrl.themeMode,
      theme:            AppTheme.light,
      darkTheme:        AppTheme.dark,
      routerConfig:     _router,
    );
  }
}
