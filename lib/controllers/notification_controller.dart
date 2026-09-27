import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Controller for in-app notification state.
class NotificationController extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int  get unreadCount => _unreadCount;
  bool get hasUnread   => _unreadCount > 0;

  void listenToNotifications(String userId) {
    _service.notificationsStream(userId).listen((list) {
      _notifications = list;
      _unreadCount   = list.where((n) => !n.isRead).length;
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _service.markAsRead(notificationId);
    final index = _notifications.indexWhere((n) => n.notificationId == notificationId);
    if (index != -1) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllAsRead(String userId) async {
    await _service.markAllAsRead(userId);
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount   = 0;
    notifyListeners();
  }
}
