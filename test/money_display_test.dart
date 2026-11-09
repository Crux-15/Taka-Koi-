import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/utils/display_helpers.dart';
import 'package:tour_expense_tracker/utils/money.dart';

void main() {
  group('Money.display', () {
    test('Taka, Rupee and Rupi use South Asian grouping', () {
      expect(Money.display(100000, '৳'), '৳1,00,000.00');
      expect(Money.display(12345678.9, '₹'), '₹1,23,45,678.90');
      expect(Money.display(999, '৳'), '৳999.00');
    });

    test('other currencies group by thousands', () {
      expect(Money.display(1234567.5, r'$'), r'$1,234,567.50');
      expect(Money.display(1000, '€'), '€1,000.00');
    });

    test('rounds to the cent and keeps the sign', () {
      expect(Money.display(33.333, '৳'), '৳33.33');
      expect(Money.display(-1860, '৳'), '-৳1,860.00');
    });

    test('compact drops .00 on whole amounts only', () {
      expect(Money.displayCompact(3800, '৳'), '৳3,800');
      expect(Money.displayCompact(33.5, '৳'), '৳33.50');
    });
  });

  group('timeAgo / dayLabel', () {
    final now = DateTime(2026, 11, 9, 18);
    test('recent times are relative', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'Just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(timeAgo(DateTime(2026, 11, 8, 23), now: now), 'Yesterday');
    });

    test('days group as Today / Yesterday / date', () {
      expect(dayLabel(DateTime(2026, 11, 9, 1), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 11, 8, 1), now: now), 'Yesterday');
      expect(dayLabel(DateTime(2026, 11, 6), now: now), 'Friday, 6 Nov');
    });
  });

  test('expense icons come from the note', () {
    expect(expenseIcon('Green Line bus tickets'), expenseIcon('train'));
    expect(expenseIcon('Seafood dinner'), expenseIcon('lunch'));
    expect(expenseIcon('random thing'), expenseIcon('misc'));
  });
}
