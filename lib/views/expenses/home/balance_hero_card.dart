import 'package:flutter/material.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/money.dart';
import '../../../widgets/ui/ui.dart';

/// The "black card" at the top of Home: where you stand in this tour.
///
/// Big number = your net balance (owed to you minus what you owe), with the
/// two sides underneath and how much of the tour you've paid for.
class BalanceHeroCard extends StatelessWidget {
  final String symbol;
  final int    iOweCents;
  final int    owedToMeCents;
  final double mySpent;
  final double groupTotal;
  final bool   loaded;
  final VoidCallback? onTap;

  const BalanceHeroCard({
    super.key,
    required this.symbol,
    required this.iOweCents,
    required this.owedToMeCents,
    required this.mySpent,
    required this.groupTotal,
    required this.loaded,
    this.onTap,
  });

  static const _text  = Color(0xFFF7F1E3);
  static const _muted = Color(0xFFB5AC97);
  static const _green = Color(0xFF34D399);
  static const _red   = Color(0xFFFF8A8E);

  @override
  Widget build(BuildContext context) {
    final net   = owedToMeCents - iOweCents;
    final share = groupTotal > 0 ? (mySpent / groupTotal).clamp(0.0, 1.0) : 0.0;

    final String headline;
    final Color  tone;
    if (net > 0) {
      headline = 'You\'re owed';
      tone = _green;
    } else if (net < 0) {
      headline = 'You owe';
      tone = _red;
    } else {
      headline = 'All square';
      tone = _text;
    }

    return Pressable(
      onTap: onTap,
      scale: 0.985,
      child: Container(
        decoration: BoxDecoration(
          gradient:     AppColors.heroGradient,
          borderRadius: BorderRadius.circular(28),
          border:       Border.all(color: const Color(0x33E2B044)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 32, offset: const Offset(0, 14)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Soft gold glow in the corner.
              Positioned(
                top: -90, right: -70,
                child: Container(
                  width: 240, height: 240,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Color(0x40E2B044), Color(0x00E2B044)]),
                  ),
                ),
              ),
              // Fine diagonal sheen.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end:   Alignment.bottomRight,
                      colors: [Colors.white.withValues(alpha: 0.05), Colors.transparent, Colors.transparent],
                      stops: const [0, 0.35, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('YOUR BALANCE', style: AppType.overline(_muted)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Settle up', style: TextStyle(fontFamily: AppType.body, fontSize: 12, fontWeight: FontWeight.w600, color: _text)),
                              SizedBox(width: 2),
                              Icon(Icons.chevron_right_rounded, size: 16, color: _text),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: !loaded
                          ? const Column(
                              key: ValueKey('loading'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DarkSkeleton(width: 90, height: 14),
                                SizedBox(height: 10),
                                _DarkSkeleton(width: 190, height: 38),
                              ],
                            )
                          : Column(
                              key: ValueKey(net),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(headline,
                                    style: TextStyle(fontFamily: AppType.body, fontSize: 14, fontWeight: FontWeight.w500, color: tone)),
                                const SizedBox(height: 4),
                                MoneyText(Money.fromCents(net.abs()), symbol: symbol, size: 40, color: _text),
                              ],
                            ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(child: _Side(label: 'You owe', cents: iOweCents, symbol: symbol, dot: _red, loaded: loaded)),
                        Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.08)),
                        const SizedBox(width: 16),
                        Expanded(child: _Side(label: 'Owed to you', cents: owedToMeCents, symbol: symbol, dot: _green, loaded: loaded)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // How much of the tour you've paid for
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Stack(
                        children: [
                          Container(height: 5, color: Colors.white.withValues(alpha: 0.08)),
                          FractionallySizedBox(
                            widthFactor: share,
                            child: Container(
                              height: 5,
                              decoration: const BoxDecoration(gradient: AppColors.goldGradient),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      groupTotal > 0
                          ? 'You\'ve paid ${Money.displayCompact(mySpent, symbol)} · ${(share * 100).round()}% of the '
                            '${Money.displayCompact(groupTotal, symbol)} tour total'
                          : 'No expenses yet. Add the first one below.',
                      style: const TextStyle(fontFamily: AppType.body, fontSize: 12.5, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Side extends StatelessWidget {
  final String label;
  final int cents;
  final String symbol;
  final Color dot;
  final bool loaded;

  const _Side({required this.label, required this.cents, required this.symbol, required this.dot, required this.loaded});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontFamily: AppType.body, fontSize: 12.5, color: BalanceHeroCard._muted)),
          ],
        ),
        const SizedBox(height: 5),
        loaded
            ? MoneyText(Money.fromCents(cents), symbol: symbol, size: 17, color: BalanceHeroCard._text, compact: true)
            : const _DarkSkeleton(width: 70, height: 16),
      ],
    );
  }
}

/// Placeholder bar for the dark card (the normal skeleton follows the theme).
class _DarkSkeleton extends StatelessWidget {
  final double width;
  final double height;
  const _DarkSkeleton({required this.width, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
      );
}
