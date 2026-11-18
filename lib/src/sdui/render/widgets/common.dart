import 'package:flutter/material.dart';

/// Icon names of CONTRACT §4. Unknown → `info`.
IconData dxpIcon(String? name) {
  switch (name) {
    case 'home':
      return Icons.home_rounded;
    case 'send':
      return Icons.send_rounded;
    case 'swap':
      return Icons.swap_horiz_rounded;
    case 'card':
      return Icons.credit_card_rounded;
    case 'receipt':
      return Icons.receipt_long_rounded;
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    case 'user':
      return Icons.person_rounded;
    case 'logout':
      return Icons.logout_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    case 'gift':
      return Icons.card_giftcard_rounded;
    case 'lock':
      return Icons.lock_rounded;
    case 'chart':
      return Icons.bar_chart_rounded;
    case 'phone':
      return Icons.phone_iphone_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'info':
    default:
      return Icons.info_outline_rounded;
  }
}

/// Inserts fixed gaps between [children].
List<Widget> withGaps(List<Widget> children, double gap, {bool horizontal = false}) {
  if (gap <= 0 || children.length < 2) return children;
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(horizontal ? SizedBox(width: gap) : SizedBox(height: gap));
    out.add(children[i]);
  }
  return out;
}

/// Marks a subtree as sitting on a primary-coloured surface, so text and
/// icons switch to `onPrimary`.
class OnPrimaryScope extends InheritedWidget {
  const OnPrimaryScope({super.key, required this.onPrimary, required super.child});

  final bool onPrimary;

  static bool of(BuildContext context) {
    final s = context.dependOnInheritedWidgetOfExactType<OnPrimaryScope>();
    return s?.onPrimary ?? false;
  }

  @override
  bool updateShouldNotify(OnPrimaryScope oldWidget) => oldWidget.onPrimary != onPrimary;
}

/// Section label used above inputs and lists.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: color,
        ),
      ),
    );
  }
}
