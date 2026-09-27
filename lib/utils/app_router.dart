import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/group_controller.dart';
import '../views/splash/splash_view.dart';
import '../views/auth/login_view.dart';
import '../views/auth/register_view.dart';
import '../views/auth/profile_setup_view.dart';
import '../views/group/group_hub_view.dart';
import '../views/group/create_group_view.dart';
import '../views/group/join_group_view.dart';
import '../views/group/admin_dashboard_view.dart';
import '../views/group/tour_history_view.dart';
import '../views/expenses/home_view.dart';
import '../views/expenses/log_expense_view.dart';
import '../views/expenses/expense_history_view.dart';
import '../views/expenses/expense_detail_view.dart';
import '../views/debts/debt_overview_view.dart';
import '../views/debts/log_payment_view.dart';
import '../views/debts/payment_review_view.dart';
import '../views/expenses/expense_delete_review_view.dart';
import '../views/notifications/notifications_view.dart';
import '../views/profile/profile_view.dart';
import '../views/shell/main_shell_view.dart';

/// Route name constants — use these to navigate instead of raw strings.
class AppRoutes {
  static const splash           = '/';
  static const login            = '/login';
  static const register         = '/register';
  static const otpVerification  = '/otp-verification';
  static const passwordSetup    = '/password-setup';
  static const profileSetup     = '/profile-setup';
  static const groupHub         = '/group-hub';
  static const createGroup      = '/create-group';
  static const joinGroup        = '/join-group';
  static const home             = '/home';
  static const adminDashboard   = '/admin-dashboard';
  static const tourHistory      = '/tour-history';
  static const logExpense       = '/log-expense';
  static const expenseHistory   = '/expense-history';
  static const expenseDetail    = '/expense-detail';
  static const debtOverview     = '/debts';
  static const logPayment       = '/log-payment';
  static const paymentReview    = '/payment-review';
  static const notifications        = '/notifications';
  static const profile              = '/profile';
  static const expenseDeleteReview  = '/expense-delete-review';
}

GoRouter buildAppRouter(BuildContext context) {
  final auth  = context.read<AuthController>();
  final group = context.read<GroupController>();

  return GoRouter(
    initialLocation: AppRoutes.splash,
    // ── CRITICAL: Re-evaluate redirect whenever auth or group state changes ──
    // Without this, signOut() changes isAuth but the router never reacts,
    // leaving the user stuck on /home with a blank loading screen.
    refreshListenable: Listenable.merge([auth, group]),
    redirect: (context, state) {
      final isAuth  = auth.isAuthenticated;
      final loc     = state.matchedLocation;

      // Allow splash and auth screens freely
      if (loc == AppRoutes.splash) return null;
      if (!isAuth &&
          loc != AppRoutes.login &&
          loc != AppRoutes.register &&
          loc != AppRoutes.otpVerification &&
          loc != AppRoutes.passwordSetup &&
          loc != AppRoutes.profileSetup) {
        return AppRoutes.login;
      }

      // Once authenticated + has group → go to home (not login/group-hub)
      if (isAuth && auth.user != null && group.hasActiveGroup &&
          (loc == AppRoutes.groupHub || loc == AppRoutes.login)) {
        return AppRoutes.home;
      }

      // If authenticated but NO active group and on any in-group screen → group-hub
      // This handles the "End Tour" case so users don't get a black screen.
      const _shellRoutes = {
        AppRoutes.home,
        AppRoutes.debtOverview,
        AppRoutes.notifications,
        AppRoutes.profile,
        AppRoutes.logExpense,
        AppRoutes.expenseHistory,
        AppRoutes.expenseDetail,
        AppRoutes.logPayment,
        AppRoutes.paymentReview,
        AppRoutes.adminDashboard,
        AppRoutes.tourHistory,
      };
      if (isAuth && !group.hasActiveGroup && _shellRoutes.contains(loc)) {
        return AppRoutes.groupHub;
      }

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash,         builder: (_, __) => const SplashView()),
      GoRoute(path: AppRoutes.login,          builder: (_, __) => const LoginView()),
      GoRoute(path: AppRoutes.register,       builder: (_, __) => const RegisterView()),
      GoRoute(path: AppRoutes.profileSetup,   builder: (_, __) => const ProfileSetupView()),
      GoRoute(path: AppRoutes.groupHub,       builder: (_, __) => const GroupHubView()),
      GoRoute(path: AppRoutes.createGroup,    builder: (_, __) => const CreateGroupView()),
      GoRoute(path: AppRoutes.joinGroup,      builder: (_, __) => const JoinGroupView()),
      GoRoute(path: AppRoutes.adminDashboard, builder: (_, __) => const AdminDashboardView()),
      GoRoute(path: AppRoutes.tourHistory,    builder: (_, __) => const TourHistoryView()),
      GoRoute(path: AppRoutes.logExpense,     builder: (_, __) => const LogExpenseView()),
      GoRoute(path: AppRoutes.expenseHistory, builder: (_, __) => const ExpenseHistoryView()),
      GoRoute(
        path: AppRoutes.expenseDetail,
        builder: (_, state) => ExpenseDetailView(
          expenseId: state.uri.queryParameters['expenseId'] ?? '',
          groupId:   state.uri.queryParameters['groupId']   ?? '',
        ),
      ),
      GoRoute(path: AppRoutes.logPayment,    builder: (_, state) => LogPaymentView(debtId: state.uri.queryParameters['debtId'] ?? '')),
      GoRoute(path: AppRoutes.paymentReview, builder: (_, state) => PaymentReviewView(paymentId: state.uri.queryParameters['paymentId'] ?? '', groupId: state.uri.queryParameters['groupId'] ?? '')),
      GoRoute(
        path: AppRoutes.expenseDeleteReview,
        builder: (_, state) => ExpenseDeleteReviewView(
          expenseId:  state.uri.queryParameters['expenseId']  ?? '',
          groupId:    state.uri.queryParameters['groupId']    ?? '',
          memberName: state.uri.queryParameters['memberName'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (_, __, child) => MainShellView(child: child),
        routes: [
          GoRoute(path: AppRoutes.home,          builder: (_, __) => const HomeView()),
          GoRoute(path: AppRoutes.debtOverview,  builder: (_, __) => const DebtOverviewView()),
          GoRoute(path: AppRoutes.notifications, builder: (_, __) => const NotificationsView()),
          GoRoute(path: AppRoutes.profile,       builder: (_, __) => const ProfileView()),
        ],
      ),
    ],
  );
}
