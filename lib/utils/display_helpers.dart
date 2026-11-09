import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// "Just now", "5m ago", "3h ago", "Yesterday", "Mon", "12 Mar", "12 Mar 2025".
String timeAgo(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  final today = DateTime(n.year, n.month, n.day);
  final day   = DateTime(t.year, t.month, t.day);
  final days  = today.difference(day).inDays;
  if (days == 0) return '${d.inHours}h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return DateFormat('EEE').format(t);
  if (t.year == n.year) return DateFormat('d MMM').format(t);
  return DateFormat('d MMM y').format(t);
}

/// Section label for grouping a list by day: "Today", "Yesterday", "Monday, 3 Mar".
String dayLabel(DateTime t, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = DateTime(n.year, n.month, n.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (t.year == n.year) return DateFormat('EEEE, d MMM').format(t);
  return DateFormat('d MMM y').format(t);
}

/// A success message, plus "it syncs later" when the change was only saved
/// on this phone (no connection).
String doneMessage(String done, {required bool queued}) =>
    queued ? '$done Saved on this phone; it syncs when you\'re back online.' : done;

/// First name only ("Nafis Rahman" → "Nafis").
String firstName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.first.isEmpty ? name : parts.first;
}

/// A fitting icon for an expense, guessed from its note.
IconData expenseIcon(String comment) {
  final c = comment.toLowerCase();
  bool has(List<String> words) => words.any(c.contains);
  if (has(['bus', 'train', 'launch', 'flight', 'plane', 'ticket', 'ferry', 'boat'])) return Icons.directions_bus_rounded;
  if (has(['hotel', 'resort', 'room', 'stay', 'cottage', 'hostel', 'night'])) return Icons.hotel_rounded;
  if (has(['tuk', 'cng', 'rickshaw', 'uber', 'pathao', 'taxi', 'car', 'jeep', 'fuel', 'petrol'])) return Icons.local_taxi_rounded;
  if (has(['coffee', 'tea', 'cafe', 'coconut', 'juice', 'drink'])) return Icons.local_cafe_rounded;
  if (has(['dinner', 'lunch', 'breakfast', 'food', 'meal', 'restaurant', 'biryani', 'seafood', 'snack', 'jhalmuri', 'bbq'])) {
    return Icons.restaurant_rounded;
  }
  if (has(['kayak', 'surf', 'boat ride', 'park', 'entry', 'museum', 'tour', 'guide', 'activity'])) return Icons.kayaking_rounded;
  if (has(['shop', 'market', 'gift', 'souvenir', 'cloth'])) return Icons.shopping_bag_rounded;
  if (has(['medicine', 'pharmacy', 'doctor'])) return Icons.medical_services_rounded;
  return Icons.receipt_long_rounded;
}
