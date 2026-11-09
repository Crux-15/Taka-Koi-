import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

/// Controller for in-app notification state.
class NotificationController extends ChangeNotifier {
  /// The service can be swapped for a fake in tests.
  NotificationController({NotificationService? service}) : _service = service ?? NotificationService();

  final NotificationService _service;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  StreamSubscription<List<NotificationModel>>? _sub;
  String? _listeningFor;

  List<NotificationModel> get notifications => _notifications;
  int  get unreadCount => _unreadCount;
  bool get hasUnread   => _unreadCount > 0;

  /// Listens to [userId]'s notifications, replacing any earlier listener
  /// (e.g. from a previous account on this phone).
  void listenToNotifications(String userId) {
    if (_listeningFor == userId && _sub != null) return;
    _sub?.cancel();
    _listeningFor  = userId;
    _notifications = [];
    _unreadCount   = 0;
    _sub = _service.notificationsStream(userId).listen((list) {
      _notifications = list;
      _unreadCount   = list.where((n) => !n.isRead).length;
      notifyListeners();
    }, onError: (Object _) {
      _sub = null;
      _listeningFor = null;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
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
