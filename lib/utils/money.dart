/// Money helpers.
///
/// Amounts are still stored in Firestore as doubles (so existing data keeps
/// working), but every calculation and comparison goes through whole cents
/// (paisa). That way splits always add up exactly and a debt can always be
/// paid down to zero. Every supported currency uses two decimal places.
class Money {
  Money._();

  /// Largest amount accepted from user input (1 billion in major units).
  static const int maxCents = 100000000000;

  /// Converts an amount in major units (e.g. 33.33) to whole cents (3333).
  static int toCents(num amount) => (amount * 100).round();

  /// Converts whole cents back to major units.
  static double fromCents(int cents) => cents / 100;

  /// Rounds an amount to the nearest cent.
  static double round(num amount) => fromCents(toCents(amount));

  /// Parses user input such as "12.5" into cents (1250).
  /// Returns null if the text isn't a usable number.
  static int? parseCents(String? text) {
    final value = double.tryParse(text?.trim() ?? '');
    if (value == null || !value.isFinite) return null;
    final cents = toCents(value);
    if (cents.abs() > maxCents) return null;
    return cents;
  }

  /// Formats cents as "1234.50" (no currency symbol).
  static String format(int cents) => fromCents(cents).toStringAsFixed(2);

  /// Currencies written with South Asian digit grouping (1,00,000).
  static const Set<String> _southAsian = {'৳', '₹', '₨'};

  /// Groups the digits of a whole number: "1,234,567", or "12,34,567" in the
  /// South Asian style.
  static String group(int whole, {bool southAsian = false}) {
    final s = whole.abs().toString();
    if (s.length <= 3) return s;
    final parts = <String>[s.substring(s.length - 3)];
    var rest = s.substring(0, s.length - 3);
    final size = southAsian ? 2 : 3;
    while (rest.length > size) {
      parts.insert(0, rest.substring(rest.length - size));
      rest = rest.substring(0, rest.length - size);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    return parts.join(',');
  }

  /// "৳1,00,000.00" / "\$1,234.50": an amount for people to read.
  static String display(num amount, String symbol) {
    final p = parts(amount, symbol);
    return '${p.sign}$symbol${p.whole}.${p.fraction}';
  }

  /// Like [display] but drops ".00" on whole amounts: "৳3,800", "৳33.33".
  static String displayCompact(num amount, String symbol) {
    final p = parts(amount, symbol);
    return '${p.sign}$symbol${p.whole}${p.fraction == '00' ? '' : '.${p.fraction}'}';
  }

  /// The pieces [display] is made of, for styling them separately.
  static ({String sign, String whole, String fraction}) parts(num amount, String symbol) {
    final cents = toCents(amount);
    final abs   = cents.abs();
    return (
      sign:     cents < 0 ? '-' : '',
      whole:    group(abs ~/ 100, southAsian: _southAsian.contains(symbol)),
      fraction: (abs % 100).toString().padLeft(2, '0'),
    );
  }

  /// Splits [totalCents] into [count] shares that differ by at most one cent
  /// and add up to exactly [totalCents]. The leftover cents go to the first
  /// shares in order, so put whoever should absorb rounding first.
  static List<int> splitEvenly(int totalCents, int count) {
    if (count <= 0) return const [];
    final base      = totalCents ~/ count;
    final remainder = totalCents % count;
    return List<int>.generate(count, (i) => base + (i < remainder ? 1 : 0));
  }
}
