import 'package:flutter/material.dart';

import '../../theme/dxp_theme.dart';
import '../node.dart';
import '../render_context.dart';
import 'common.dart';

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String _money(dynamic v) {
  final n = toNum(v);
  return n == null ? stringify(v) : formatMoney(n);
}

Widget buildBalanceCard(NodeSpec n, NodeScope s) {
  final title = n.str('title', 'Total balance');
  final amount = _money(n.props['amount']);
  final currency = n.str('currency');
  final subtitle = n.str('subtitle');
  final onTap = s.handler(n, 'tap');
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: t.borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[t.primary, t.tint('primary', 0.78)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(color: t.tint('primary', 0.28), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: t.borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500, color: t.tint('onPrimary', 0.85))),
                    ),
                    Icon(Icons.account_balance_wallet_rounded, color: t.tint('onPrimary', 0.85), size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: <Widget>[
                    Text(amount,
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: t.onPrimary)),
                    if (currency.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(currency,
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600, color: t.tint('onPrimary', 0.85))),
                      ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: t.tint('onPrimary', 0.8))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  });
}

IconData _accountIcon(String type) {
  switch (type.toUpperCase()) {
    case 'SAVINGS':
      return Icons.savings_rounded;
    case 'DEPOSIT':
      return Icons.lock_outline_rounded;
    case 'CARD':
      return Icons.credit_card_rounded;
    default:
      return Icons.account_balance_wallet_rounded;
  }
}

Widget buildAccountList(NodeSpec n, NodeScope s) {
  final items = n.list('items').map(_asMap).toList();
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    if (items.isEmpty) {
      return _EmptyNote(text: 'No accounts to show', theme: t);
    }
    final tiles = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final a = items[i];
      final featured = i == 0;
      final onTap = s.handler(n, 'tap', s.ctx.withItem(a));
      final fg = featured ? t.onPrimary : t.onSurface;
      final sub = featured ? t.tint('onPrimary', 0.8) : t.muted;
      tiles.add(Container(
        decoration: BoxDecoration(
          borderRadius: t.borderRadius,
          color: featured ? null : t.surface,
          gradient: featured
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[t.primary, t.tint('primary', 0.8)],
                )
              : null,
          boxShadow: featured
              ? <BoxShadow>[
                  BoxShadow(color: t.tint('primary', 0.25), blurRadius: 20, offset: const Offset(0, 8)),
                ]
              : t.softShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: t.borderRadius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.all(featured ? 20 : 16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: featured ? t.tint('onPrimary', 0.18) : t.tint('primary', 0.1),
                      borderRadius: t.innerRadius,
                    ),
                    child: Icon(_accountIcon(stringify(a['type'])),
                        color: featured ? t.onPrimary : t.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(stringify(a['name']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: fg)),
                        const SizedBox(height: 3),
                        Text(stringify(a['number']), style: TextStyle(fontSize: 13, color: sub)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_money(a['balance']),
                          style: TextStyle(
                              fontSize: featured ? 20 : 16, fontWeight: FontWeight.w700, color: fg)),
                      const SizedBox(height: 2),
                      Text(stringify(a['currency']),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sub)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: withGaps(tiles, 10),
    );
  });
}

Widget buildTxnList(NodeSpec n, NodeScope s) {
  final limit = n.integer('limit', 0);
  var items = n.list('items').map(_asMap).toList();
  if (limit > 0 && items.length > limit) items = items.sublist(0, limit);
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    if (items.isEmpty) return _EmptyNote(text: 'No transactions yet', theme: t);
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final x = items[i];
      final amount = toNum(x['amount']) ?? 0;
      final credit = amount > 0;
      final status = stringify(x['status']);
      final pending = status.isNotEmpty && status.toUpperCase() != 'POSTED';
      if (i > 0) {
        rows.add(Divider(height: 1, indent: 68, color: t.tint('muted', 0.12)));
      }
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: credit ? t.tint('success', 0.12) : t.tint('muted', 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                credit ? Icons.south_west_rounded : Icons.north_east_rounded,
                size: 18,
                color: credit ? t.success : t.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(stringify(x['description']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: t.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    pending ? '${formatDate(x['date'])}  ·  $status' : formatDate(x['date']),
                    style: TextStyle(fontSize: 12.5, color: pending ? t.warning : t.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${credit ? '+' : ''}${formatMoney(amount)} ${stringify(x['currency'])}',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: credit ? t.success : t.onSurface,
              ),
            ),
          ],
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: t.borderRadius, boxShadow: t.softShadow),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  });
}

Widget buildQuickActions(NodeSpec n, NodeScope s) {
  final items = n.list('items').map(_asMap).toList();
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 10.0;
      final columns = constraints.maxWidth >= 520 ? 6 : 4;
      final w = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: items.map((it) {
          final label = stringify(it['label']);
          final action = it['action'];
          return SizedBox(
            width: w.isFinite && w > 0 ? w : 80,
            child: Material(
              color: t.surface,
              borderRadius: t.innerRadius,
              child: InkWell(
                borderRadius: t.innerRadius,
                onTap: action is Map ? () => s.run(action) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: t.tint('primary', 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(dxpIcon(stringify(it['icon'])), color: t.primary, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: t.onSurface),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  });
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text, required this.theme});

  final String text;
  final DxpTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: theme.surface, borderRadius: theme.borderRadius),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: theme.muted)),
    );
  }
}
