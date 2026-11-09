// Renders the app's screens with demo data, in light and dark mode, to PNGs
// in test_screenshots/goldens/. A visual check for design changes.
//
//   flutter test test_screenshots --update-goldens   (write / refresh images)
//   flutter test test_screenshots                    (compare against them)
//
// Kept out of test/ so the normal `flutter test` run stays fast and doesn't
// depend on fonts installed on this computer.

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tour_expense_tracker/controllers/auth_controller.dart';
import 'package:tour_expense_tracker/controllers/debt_controller.dart';
import 'package:tour_expense_tracker/controllers/expense_controller.dart';
import 'package:tour_expense_tracker/controllers/group_controller.dart';
import 'package:tour_expense_tracker/controllers/notification_controller.dart';
import 'package:tour_expense_tracker/controllers/theme_controller.dart';
import 'package:tour_expense_tracker/utils/app_router.dart';
import 'package:tour_expense_tracker/utils/app_theme.dart';
import 'package:tour_expense_tracker/views/auth/login_view.dart';
import 'package:tour_expense_tracker/views/auth/register_view.dart';
import 'package:tour_expense_tracker/views/debts/debt_overview_view.dart';
import 'package:tour_expense_tracker/views/debts/log_payment_view.dart';
import 'package:tour_expense_tracker/views/expenses/expense_detail_view.dart';
import 'package:tour_expense_tracker/views/expenses/expense_history_view.dart';
import 'package:tour_expense_tracker/views/expenses/home_view.dart';
import 'package:tour_expense_tracker/views/expenses/log_expense_view.dart';
import 'package:tour_expense_tracker/views/group/admin_dashboard_view.dart';
import 'package:tour_expense_tracker/views/group/create_group_view.dart';
import 'package:tour_expense_tracker/views/group/group_hub_view.dart';
import 'package:tour_expense_tracker/views/group/join_group_view.dart';
import 'package:tour_expense_tracker/views/group/tour_history_view.dart';
import 'package:tour_expense_tracker/views/notifications/notifications_view.dart';
import 'package:tour_expense_tracker/views/profile/profile_view.dart';
import 'package:tour_expense_tracker/views/shell/main_shell_view.dart';

import 'fakes.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) loader.addFont(f.readAsBytes().then((b) => ByteData.view(b.buffer)));
    }
    await loader.load();
  }

  const fonts = 'assets/fonts';
  await load('Montserrat', ['Regular', 'Medium', 'SemiBold', 'Bold'].map((w) => '$fonts/Montserrat-$w.ttf').toList());
  await load('WorkSans', ['Regular', 'Medium', 'SemiBold', 'Bold'].map((w) => '$fonts/WorkSans-$w.ttf').toList());
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  await load('MaterialIcons', ['$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
  // Phones fall back to a system font for ৳; tests have no fallback, so use
  // Windows' Nirmala UI when it's there.
  await load('Fallback', ['C:/Windows/Fonts/Nirmala.ttc']);
}

ThemeData _withFallback(ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamilyFallback: const ['Fallback']),
    );

void _mockPlatform() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockStreamHandler(
    const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
    MockStreamHandler.inline(onListen: (args, sink) => sink.success(['wifi'])),
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => ['wifi'],
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (call) async => <String, Object>{},
  );
}

class _Screen {
  final String route;
  final bool signedIn;
  final bool inTour;
  /// Render with phone text size at 130% (many people turn it up).
  final bool largeText;
  const _Screen(this.route, {this.signedIn = true, this.inTour = true, this.largeText = false});
}

const _screens = {
  'home':            _Screen(AppRoutes.home),
  'balances':        _Screen(AppRoutes.debtOverview),
  'activity':        _Screen(AppRoutes.notifications),
  'profile':         _Screen(AppRoutes.profile),
  'login':           _Screen(AppRoutes.login, signedIn: false, inTour: false),
  'register':        _Screen(AppRoutes.register, signedIn: false, inTour: false),
  'group_hub':       _Screen(AppRoutes.groupHub, inTour: false),
  'create_group':    _Screen(AppRoutes.createGroup, inTour: false),
  'join_group':      _Screen(AppRoutes.joinGroup, inTour: false),
  'log_expense':     _Screen(AppRoutes.logExpense),
  'expense_history': _Screen(AppRoutes.expenseHistory),
  'expense_detail':  _Screen('${AppRoutes.expenseDetail}?expenseId=kayak&groupId=g-coxs'),
  'log_payment':     _Screen('${AppRoutes.logPayment}?debtId=hotel_nafis'),
  'admin':           _Screen(AppRoutes.adminDashboard),
  'past_tours':      _Screen(AppRoutes.tourHistory),
  // Large text: nothing may overflow or get cut off.
  'home_large':        _Screen(AppRoutes.home, largeText: true),
  'balances_large':    _Screen(AppRoutes.debtOverview, largeText: true),
  'log_expense_large': _Screen(AppRoutes.logExpense, largeText: true),
  'log_payment_large': _Screen('${AppRoutes.logPayment}?debtId=hotel_nafis', largeText: true),
};

Widget _app(_Screen screen, ThemeMode mode) {
  final auth = AuthController(authService: FakeAuthService());
  if (screen.signedIn) auth.debugSignIn(Demo.me);
  final groups = GroupController(
    groupService:        FakeGroupService(),
    notificationService: FakeNotificationService(),
    bkashService:        FakeBkashService(),
  );
  if (screen.inTour) groups.debugSetActiveGroup(Demo.group, currentUserId: Demo.me.uid);
  final expenses = ExpenseController(
    expenseService:      FakeExpenseService(),
    geoService:          FakeGeoService(),
    notificationService: FakeNotificationService(),
  )
    ..listenToApprovedExpenses(Demo.group.groupId)
    ..listenToMyExpenses(Demo.group.groupId, Demo.me.uid);
  final debts = DebtController(debtService: FakeDebtService(), notificationService: FakeNotificationService())
    ..listenToDebts(Demo.group.groupId, Demo.me.uid);
  final notifs = NotificationController(service: FakeNotificationService())..listenToNotifications(Demo.me.uid);

  GoRoute r(String path, Widget Function(GoRouterState s) b) => GoRoute(path: path, builder: (_, s) => b(s));
  final router = GoRouter(
    initialLocation: screen.route,
    routes: [
      ShellRoute(
        builder: (_, __, child) => MainShellView(child: child),
        routes: [
          r(AppRoutes.home,          (_) => const HomeView()),
          r(AppRoutes.debtOverview,  (_) => const DebtOverviewView()),
          r(AppRoutes.notifications, (_) => const NotificationsView()),
          r(AppRoutes.profile,       (_) => const ProfileView()),
        ],
      ),
      r(AppRoutes.login,          (_) => const LoginView()),
      r(AppRoutes.register,       (_) => const RegisterView()),
      r(AppRoutes.groupHub,       (_) => const GroupHubView()),
      r(AppRoutes.createGroup,    (_) => const CreateGroupView()),
      r(AppRoutes.joinGroup,      (_) => const JoinGroupView()),
      r(AppRoutes.logExpense,     (_) => const LogExpenseView()),
      r(AppRoutes.expenseHistory, (_) => const ExpenseHistoryView()),
      r(AppRoutes.adminDashboard, (_) => const AdminDashboardView()),
      r(AppRoutes.expenseDetail,  (s) => ExpenseDetailView(
            expenseId: s.uri.queryParameters['expenseId'] ?? '',
            groupId:   s.uri.queryParameters['groupId'] ?? '',
          )),
      r(AppRoutes.logPayment,     (s) => LogPaymentView(debtId: s.uri.queryParameters['debtId'] ?? '')),
      r(AppRoutes.tourHistory,    (_) => const TourHistoryView()),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: groups),
      ChangeNotifierProvider.value(value: expenses),
      ChangeNotifierProvider.value(value: debts),
      ChangeNotifierProvider.value(value: notifs),
    ],
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme:        _withFallback(AppTheme.light),
      darkTheme:    _withFallback(AppTheme.dark),
      themeMode:    mode,
      routerConfig: router,
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  for (final entry in _screens.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      final name = '${entry.key}_${mode.name}';
      testWidgets(name, (tester) async {
        _mockPlatform();
        tester.view.devicePixelRatio = 2;
        tester.view.physicalSize = const Size(400 * 2, 860 * 2);
        addTearDown(tester.view.reset);
        if (entry.value.largeText) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }

        await tester.pumpWidget(_app(entry.value, mode));
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      });
    }
  }
}
