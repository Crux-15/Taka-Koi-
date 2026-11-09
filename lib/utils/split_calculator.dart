import '../models/expense_model.dart';
import 'app_constants.dart';
import 'money.dart';

/// Works out each member's share of an expense, in whole cents.
///
/// Kept free of Flutter and Firebase so the rules for splitting money can be
/// unit-tested on their own.
class SplitCalculator {
  SplitCalculator._();

  /// Builds the splits map for an expense of [totalCents].
  ///
  /// * [selected]: the other members in the split, in display order.
  /// * Equal split: shares differ by at most one cent and add up to exactly
  ///   the total. The logger comes first, so they absorb any leftover cent.
  /// * Custom split: each selected member pays [customCents]; the logger (if
  ///   included) pays whatever is left, never below zero.
  static Map<String, SplitEntry> build({
    required String splitType,
    required int totalCents,
    required String loggerId,
    required String loggerName,
    required bool loggerIncluded,
    required List<String> selected,
    required Map<String, String> names,
    Map<String, int> customCents = const {},
  }) {
    final members = <String>[
      if (loggerIncluded) loggerId,
      ...selected.where((uid) => uid != loggerId),
    ];
    if (members.isEmpty) return {};

    String nameOf(String uid) => uid == loggerId ? loggerName : (names[uid] ?? '');
    final splits = <String, SplitEntry>{};

    if (splitType == AppConstants.splitEqual) {
      final shares = Money.splitEvenly(totalCents, members.length);
      for (var i = 0; i < members.length; i++) {
        final uid = members[i];
        splits[uid] = SplitEntry(userId: uid, name: nameOf(uid), amount: Money.fromCents(shares[i]));
      }
      return splits;
    }

    var othersCents = 0;
    for (final uid in members.where((uid) => uid != loggerId)) {
      final cents = customCents[uid] ?? 0;
      splits[uid] = SplitEntry(userId: uid, name: nameOf(uid), amount: Money.fromCents(cents));
      othersCents += cents;
    }
    if (loggerIncluded) {
      final selfCents = totalCents - othersCents;
      splits[loggerId] = SplitEntry(
        userId: loggerId,
        name:   loggerName,
        amount: Money.fromCents(selfCents < 0 ? 0 : selfCents),
      );
    }
    return splits;
  }

  /// Why these splits can't be saved, or null if they're fine.
  /// [symbol] is the currency symbol used in the messages.
  static String? validate({
    required String splitType,
    required int totalCents,
    required String loggerId,
    required bool loggerIncluded,
    required Map<String, SplitEntry> splits,
    required String symbol,
  }) {
    if (splits.isEmpty) return 'Please select at least one member to split with.';
    if (splits.length > AppConstants.maxSplitMembers) {
      return 'An expense can be split between at most ${AppConstants.maxSplitMembers} people.';
    }
    if (splitType != AppConstants.splitCustom) return null;

    var othersCents = 0;
    for (final entry in splits.entries.where((e) => e.key != loggerId)) {
      final cents = Money.toCents(entry.value.amount);
      if (cents <= 0) return 'Enter a share above zero for ${entry.value.name}, or unselect them.';
      othersCents += cents;
    }
    if (othersCents > totalCents) {
      return 'Custom shares exceed total by $symbol${Money.format(othersCents - totalCents)}. '
          'Please adjust amounts.';
    }
    if (!loggerIncluded && othersCents < totalCents) {
      return 'Please allocate remaining $symbol${Money.format(totalCents - othersCents)} to members.';
    }
    return null;
  }
}
