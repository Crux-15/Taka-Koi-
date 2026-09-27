/// App-wide constants — strings, dimensions, durations, limits.
class AppConstants {
  AppConstants._();

  // ── App Info ──────────────────────────────────────────────────────────────
  static const String appName        = 'Taka Koi?';
  static const String appTagline     = 'Balance Every Journey';
  static const String appVersion     = '1.0.0';

  // ── Firestore Collections ─────────────────────────────────────────────────
  static const String colUsers         = 'users';
  static const String colGroups        = 'groups';
  static const String colExpenses      = 'expenses';
  static const String colDebts         = 'debts';
  static const String colPayments      = 'payments';
  static const String colNotifications = 'notifications';
  static const String colJoinRequests  = 'joinRequests';
  static const String colAuditLog      = 'auditLog';
  static const String colBkashRequests = 'bkashRequests';

  // ── Group Rules ───────────────────────────────────────────────────────────
  /// Hours before the group join-code expires and must be refreshed.
  static const int groupCodeExpiryHours = 1;

  /// Consecutive days of inactivity before auto-deactivation.
  static const int inactivityDays = 4;

  /// Length of the alphanumeric group join-code.
  static const int groupCodeLength = 6;

  // ── Expense ───────────────────────────────────────────────────────────────
  static const int maxCommentLength = 200;

  // ── Status Strings ────────────────────────────────────────────────────────
  static const String statusPending  = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusActive   = 'active';
  static const String statusInactive = 'inactive';
  static const String statusSettled  = 'settled';

  // ── Split Types ───────────────────────────────────────────────────────────
  static const String splitEqual  = 'equal';
  static const String splitCustom = 'custom';

  // ── Inactivation Reasons ──────────────────────────────────────────────────
  static const String inactivatedByAdmin  = 'admin';
  static const String inactivatedBySystem = 'system';

  // ── Notification Types ────────────────────────────────────────────────────
  static const String notifExpensePendingApproval = 'expense_pending_approval';
  static const String notifExpenseApproved      = 'expense_approved';
  static const String notifExpenseRejected      = 'expense_rejected';
  static const String notifPaymentApproved      = 'payment_approved';
  static const String notifPaymentRejected      = 'payment_rejected';
  static const String notifJoinApproved         = 'join_approved';
  static const String notifJoinRejected         = 'join_rejected';
  static const String notifBkashRequested       = 'bkash_requested';
  static const String notifBkashAddRequired     = 'bkash_add_required';
  static const String notifBkashAccepted        = 'bkash_accepted';
  static const String notifAdminTransferRequired= 'admin_transfer_required';
  static const String notifGroupAutoDeactivated = 'group_auto_deactivated';
  static const String notifLeaveRequest         = 'leave_request';
  static const String notifLeaveApproved        = 'leave_approved';
  static const String notifLeaveRejected        = 'leave_rejected';
  static const String notifGroupEnded               = 'group_ended';
  static const String notifDeleteExpenseRequest     = 'delete_expense_request';
  static const String notifDeleteExpenseApproved    = 'delete_expense_approved';
  static const String notifDeleteExpenseRejected    = 'delete_expense_rejected';

  // ── SharedPreferences Keys ────────────────────────────────────────────────
  static const String prefThemeMode      = 'theme_mode';
  static const String prefLastSeenNotif  = 'last_seen_notif';

  // ── Animation Durations ───────────────────────────────────────────────────
  static const Duration splashDuration     = Duration(seconds: 2);
  static const Duration animFast           = Duration(milliseconds: 200);
  static const Duration animNormal         = Duration(milliseconds: 350);
  static const Duration animSlow           = Duration(milliseconds: 600);

  // ── Dimensions ────────────────────────────────────────────────────────────
  static const double radiusSmall  = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge  = 24.0;
  static const double radiusXL     = 32.0;
  static const double radiusFull   = 100.0;

  static const double paddingXS = 4.0;
  static const double paddingS  = 8.0;
  static const double paddingM  = 16.0;
  static const double paddingL  = 24.0;
  static const double paddingXL = 32.0;

  static const double avatarSizeS = 32.0;
  static const double avatarSizeM = 48.0;
  static const double avatarSizeL = 80.0;
  static const double avatarSizeXL= 120.0;

  static const double elevationS = 2.0;
  static const double elevationM = 6.0;
  static const double elevationL = 12.0;

  // ── Supported Currencies ─────────────────────────────────────────────────
  static const List<Map<String, String>> currencies = [
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'PKR', 'symbol': '₨', 'name': 'Pakistani Rupee'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
  ];
}
