import 'package:flutter_test/flutter_test.dart';
import 'package:tour_expense_tracker/models/expense_model.dart';
import 'package:tour_expense_tracker/utils/app_constants.dart';
import 'package:tour_expense_tracker/utils/money.dart';
import 'package:tour_expense_tracker/utils/split_calculator.dart';

const _names = {'me': 'Me', 'b': 'Bob', 'c': 'Carol'};

Map<String, SplitEntry> _equal(int totalCents, {bool includeMe = true, List<String> others = const ['b', 'c']}) =>
    SplitCalculator.build(
      splitType:      AppConstants.splitEqual,
      totalCents:     totalCents,
      loggerId:       'me',
      loggerName:     'Me',
      loggerIncluded: includeMe,
      selected:       others,
      names:          _names,
    );

Map<String, SplitEntry> _custom(int totalCents, Map<String, int> others, {bool includeMe = true}) =>
    SplitCalculator.build(
      splitType:      AppConstants.splitCustom,
      totalCents:     totalCents,
      loggerId:       'me',
      loggerName:     'Me',
      loggerIncluded: includeMe,
      selected:       others.keys.toList(),
      names:          _names,
      customCents:    others,
    );

int _sumCents(Map<String, SplitEntry> s) => s.values.fold(0, (t, e) => t + Money.toCents(e.amount));

String? _validate(String type, int total, Map<String, SplitEntry> splits, {bool includeMe = true}) =>
    SplitCalculator.validate(
      splitType:      type,
      totalCents:     total,
      loggerId:       'me',
      loggerIncluded: includeMe,
      splits:         splits,
      symbol:         '৳',
    );

void main() {
  group('equal split', () {
    test('adds up to the total exactly; the logger absorbs the odd cent', () {
      final s = _equal(10000); // ৳100 between 3
      expect(_sumCents(s), 10000);
      expect(Money.toCents(s['me']!.amount), 3334);
      expect(Money.toCents(s['b']!.amount), 3333);
      expect(Money.toCents(s['c']!.amount), 3333);
    });

    test('without the logger, only the selected members share it', () {
      final s = _equal(10000, includeMe: false);
      expect(s.keys, unorderedEquals(['b', 'c']));
      expect(_sumCents(s), 10000);
    });

    test('uses member names', () {
      final s = _equal(300);
      expect(s['me']!.name, 'Me');
      expect(s['b']!.name, 'Bob');
    });

    test('nobody selected → no splits, and that can\'t be saved', () {
      final s = _equal(1000, includeMe: false, others: const []);
      expect(s, isEmpty);
      expect(_validate(AppConstants.splitEqual, 1000, s), contains('at least one member'));
    });
  });

  group('custom split', () {
    test('the logger pays what the others don\'t', () {
      final s = _custom(10000, {'b': 2500, 'c': 1500});
      expect(Money.toCents(s['me']!.amount), 6000);
      expect(_sumCents(s), 10000);
      expect(_validate(AppConstants.splitCustom, 10000, s), isNull);
    });

    test('others asking for more than the total is refused', () {
      final s = _custom(10000, {'b': 8000, 'c': 3000});
      expect(Money.toCents(s['me']!.amount), 0); // never negative
      expect(_validate(AppConstants.splitCustom, 10000, s), contains('exceed total by ৳10.00'));
    });

    test('without the logger, every cent has to be given to someone', () {
      final s = _custom(10000, {'b': 5000, 'c': 4000}, includeMe: false);
      expect(_validate(AppConstants.splitCustom, 10000, s, includeMe: false),
          contains('allocate remaining ৳10.00'));
      final ok = _custom(10000, {'b': 5000, 'c': 5000}, includeMe: false);
      expect(_validate(AppConstants.splitCustom, 10000, ok, includeMe: false), isNull);
    });

    test('a selected member with no share is refused', () {
      final s = _custom(10000, {'b': 0, 'c': 5000});
      expect(_validate(AppConstants.splitCustom, 10000, s), contains('above zero for Bob'));
    });
  });

  test('at most ${AppConstants.maxSplitMembers} people per expense (the security rules need a limit)', () {
    final others = List.generate(AppConstants.maxSplitMembers, (i) => 'm$i');
    final names = {for (final id in others) id: id};
    Map<String, SplitEntry> split(List<String> sel) => SplitCalculator.build(
          splitType:      AppConstants.splitEqual,
          totalCents:     100000,
          loggerId:       'me',
          loggerName:     'Me',
          loggerIncluded: true,
          selected:       sel,
          names:          names,
        );
    expect(_validate(AppConstants.splitEqual, 100000, split(others.sublist(1))), isNull);
    expect(_validate(AppConstants.splitEqual, 100000, split(others)), contains('at most'));
  });
}
