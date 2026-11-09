import 'package:flutter/material.dart';
import '../../utils/app_palette.dart';
import '../../utils/app_typography.dart';
import '../../utils/money.dart';

/// An amount set like a bank app: currency symbol and paisa smaller than the
/// whole part, digits aligned. `৳3,800.00` → small ৳, big 3,800, small .00
class MoneyText extends StatelessWidget {
  final num     amount;
  final String  symbol;
  final double  size;
  final Color?  color;
  final FontWeight weight;
  /// Hide ".00" on whole amounts.
  final bool    compact;
  /// Prefix with + or − (for balances).
  final bool    signed;

  const MoneyText(
    this.amount, {
    super.key,
    required this.symbol,
    this.size    = 16,
    this.color,
    this.weight  = FontWeight.w700,
    this.compact = false,
    this.signed  = false,
  });

  @override
  Widget build(BuildContext context) {
    final c     = color ?? context.palette.text;
    final p     = Money.parts(amount, symbol);
    final base  = DefaultTextStyle.of(context).style;
    final big   = base.merge(AppType.money(size, weight: weight, color: c));
    final small = base.merge(AppType.money(size * 0.62, weight: weight, color: c.withValues(alpha: 0.72)));
    final sign  = signed ? (p.sign.isEmpty ? (Money.toCents(amount) == 0 ? '' : '+') : '−') : p.sign;
    final showFraction = !(compact && p.fraction == '00');

    return Text.rich(
      TextSpan(children: [
        if (sign.isNotEmpty) TextSpan(text: sign, style: big),
        TextSpan(text: symbol, style: small),
        TextSpan(text: p.whole, style: big),
        if (showFraction) TextSpan(text: '.${p.fraction}', style: small),
      ]),
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
    );
  }
}
