import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/models/debt_model.dart';
import 'package:tour_expense_tracker/services/debt_service.dart';
import 'package:tour_expense_tracker/utils/money.dart';

DebtModel _debt({
  required String from,
  required String to,
  required double remaining,
  String status = 'active',
}) =>
    DebtModel(
      debtId:          '$from-$to-$remaining',
      groupId:         'g',
      fromUserId:      from,
      fromUserName:    from,
      toUserId:        to,
      toUserName:      to,
      sourceExpenseId: 'e',
      originalAmount:  remaining,
      remainingAmount: remaining,
      status:          status,
      createdAt:       DateTime(2026),
    );

void main() {
  group('Money.toCents / parseCents', () {
    test('rounds to the nearest cent despite float error', () {
      expect(Money.toCents(0.29), 29);       // 0.29 * 100 == 28.999999999999996
      expect(Money.toCents(33.3333333), 3333);
      expect(Money.toCents(100), 10000);
    });

    test('parses user input', () {
      expect(Money.parseCents('12.5'), 1250);
      expect(Money.parseCents(' 7 '), 700);
      expect(Money.parseCents('0.004'), 0);
      expect(Money.parseCents('-3'), -300);
    });

    test('rejects text that is not a usable amount', () {
      expect(Money.parseCents(''), isNull);
      expect(Money.parseCents(null), isNull);
      expect(Money.parseCents('abc'), isNull);
      expect(Money.parseCents('NaN'), isNull);
      expect(Money.parseCents('Infinity'), isNull);
      expect(Money.parseCents('1e15'), isNull);
    });

    test('formats cents with two decimals', () {
      expect(Money.format(3334), '33.34');
      expect(Money.format(5), '0.05');
    });
  });

  group('Money.splitEvenly', () {
    test('100 split three ways adds up exactly, first share takes the extra cent', () {
      expect(Money.splitEvenly(10000, 3), [3334, 3333, 3333]);
    });

    test('shares always sum to the total and differ by at most one cent', () {
      for (var total = 0; total <= 2500; total += 7) {
        for (var count = 1; count <= 12; count++) {
          final shares = Money.splitEvenly(total, count);
          expect(shares.length, count);
          expect(shares.reduce((a, b) => a + b), total, reason: '$total / $count');
          final spread = shares.reduce((a, b) => a > b ? a : b) - shares.reduce((a, b) => a < b ? a : b);
          expect(spread, lessThanOrEqualTo(1), reason: '$total / $count');
        }
      }
    });

    test('handles zero people', () {
      expect(Money.splitEvenly(1000, 0), isEmpty);
    });
  });

  group('DebtModel.isOpen', () {
    test('a debt left with a fraction of a cent is treated as paid', () {
      // What an old unrounded split left behind after paying 33.33 of 33.3333…
      expect(_debt(from: 'a', to: 'b', remaining: 100 / 3 - 33.33).isOpen, isFalse);
    });

    test('a debt with at least one cent left is open', () {
      expect(_debt(from: 'a', to: 'b', remaining: 0.01).isOpen, isTrue);
    });

    test('a settled debt is never open', () {
      expect(_debt(from: 'a', to: 'b', remaining: 5, status: 'settled').isOpen, isFalse);
    });

    test('paying the shown amount on an old unrounded debt clears it', () {
      final old       = _debt(from: 'a', to: 'b', remaining: 100 / 3);
      final payment   = Money.parseCents(Money.format(old.remainingCents))!; // "1-Tap Settle Full"
      expect(old.remainingCents - payment, 0);
    });
  });

  group('computeNetDebts', () {
    test('balances that cancel out come to exactly zero', () {
      final net = computeNetDebts(
        iOwe:     [_debt(from: 'me', to: 'x', remaining: 0.1), _debt(from: 'me', to: 'x', remaining: 0.2)],
        owedToMe: [_debt(from: 'x', to: 'me', remaining: 0.3)],
      );
      expect(net['x'], 0.0);
    });

    test('nets per person in both directions', () {
      final net = computeNetDebts(
        iOwe:     [_debt(from: 'me', to: 'x', remaining: 100), _debt(from: 'me', to: 'y', remaining: 10)],
        owedToMe: [_debt(from: 'x', to: 'me', remaining: 33.33), _debt(from: 'y', to: 'me', remaining: 25)],
      );
      expect(net['x'], 66.67);
      expect(net['y'], -15.0);
    });
  });
}
