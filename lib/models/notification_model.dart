import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_constants.dart';

/// In-app notification document stored in the top-level `notifications` collection.
class NotificationModel {
  final String notificationId;
  final String targetUserId;
  final String groupId;
  final String groupName;   // display name of the tour group
  final String type;        // see AppConstants.notif* constants
  final String referenceId; // expenseId | paymentId | requestId
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.notificationId,
    required this.targetUserId,
    required this.groupId,
    required this.groupName,
    required this.type,
    required this.referenceId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      notificationId: doc.id,
      targetUserId:   data['targetUserId'] as String? ?? '',
      groupId:        data['groupId']      as String? ?? '',
      groupName:      data['groupName']    as String? ?? '',
      type:           data['type']         as String? ?? '',
      referenceId:    data['referenceId']  as String? ?? '',
      message:        data['message']      as String? ?? '',
      isRead:         data['isRead']       as bool?   ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'targetUserId': targetUserId,
    'groupId':      groupId,
    'groupName':    groupName,
    'type':         type,
    'referenceId':  referenceId,
    'message':      message,
    'isRead':       isRead,
    'createdAt':    Timestamp.fromDate(createdAt),
  };

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
    notificationId: notificationId,
    targetUserId:   targetUserId,
    groupId:        groupId,
    groupName:      groupName,
    type:           type,
    referenceId:    referenceId,
    message:        message,
    isRead:         isRead ?? this.isRead,
    createdAt:      createdAt,
  );

  /// Returns an icon-name hint for the notification type.
  String get iconHint {
    switch (type) {
      case AppConstants.notifExpensePendingApproval: return 'pending_actions';
      case AppConstants.notifExpenseApproved:        return 'check_circle';
      case AppConstants.notifExpenseRejected:        return 'cancel';
      case AppConstants.notifPaymentApproved:        return 'payments';
      case AppConstants.notifPaymentRejected:        return 'money_off';
      case AppConstants.notifJoinApproved:           return 'group_add';
      case AppConstants.notifJoinRejected:           return 'person_remove';
      case AppConstants.notifBkashRequested:         return 'phone_android';
      case AppConstants.notifBkashAddRequired:       return 'add_card';
      case AppConstants.notifBkashAccepted:          return 'check_circle';
      case AppConstants.notifAdminTransferRequired:  return 'admin_panel_settings';
      case AppConstants.notifGroupAutoDeactivated:   return 'timer_off';
      case AppConstants.notifDeleteExpenseRequest:   return 'delete_forever';
      case AppConstants.notifDeleteExpenseApproved:  return 'delete_sweep';
      case AppConstants.notifDeleteExpenseRejected:  return 'delete_outline';
      default:                                       return 'notifications';
    }
  }
}
