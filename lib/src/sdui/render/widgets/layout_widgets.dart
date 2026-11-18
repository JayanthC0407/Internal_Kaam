import 'package:flutter/material.dart';

import '../../theme/dxp_theme.dart';
import '../node.dart';
import 'common.dart';

Widget buildColumn(NodeSpec n, NodeScope s) {
  final padding = n.dbl('padding', 0);
  final gap = n.dbl('gap', 0);
  final CrossAxisAlignment cross;
  switch (n.str('align', 'stretch')) {
    case 'start':
      cross = CrossAxisAlignment.start;
      break;
    case 'center':
      cross = CrossAxisAlignment.center;
      break;
    default:
      cross = CrossAxisAlignment.stretch;
  }
  Widget col = Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: cross,
    children: withGaps(s.children(n), gap),
  );
  if (padding > 0) col = Padding(padding: EdgeInsets.all(padding), child: col);
  if (n.flag('scroll')) {
    col = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: col,
    );
  }
  return col;
}

Widget buildRow(NodeSpec n, NodeScope s) {
  final gap = n.dbl('gap', 8);
  final MainAxisAlignment main;
  switch (n.str('align', 'start')) {
    case 'center':
      main = MainAxisAlignment.center;
      break;
    case 'spaceBetween':
      main = MainAxisAlignment.spaceBetween;
      break;
    default:
      main = MainAxisAlignment.start;
  }
  // Flexible(loose) keeps intrinsic widths but prevents overflow.
  final kids = s
      .children(n)
      .map<Widget>((w) => Flexible(fit: FlexFit.loose, child: w))
      .toList();
  return Row(
    mainAxisAlignment: main,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: main == MainAxisAlignment.spaceBetween ? kids : withGaps(kids, gap, horizontal: true),
  );
}

Widget buildCard(NodeSpec n, NodeScope s) {
  final primaryTone = n.str('tone', 'surface') == 'primary';
  final padding = n.dbl('padding', 16);
  final onTap = s.handler(n, 'tap');
  final children = withGaps(s.children(n), 6);
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    final fg = primaryTone ? t.onPrimary : t.onSurface;
    return Container(
      decoration: BoxDecoration(
        borderRadius: t.borderRadius,
        boxShadow: primaryTone ? null : t.softShadow,
        gradient: primaryTone
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[t.primary, t.tint('primary', 0.82)],
              )
            : null,
        color: primaryTone ? null : t.surface,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: t.borderRadius,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: OnPrimaryScope(
              onPrimary: primaryTone,
              child: DefaultTextStyle.merge(
                style: TextStyle(color: fg),
                child: IconTheme.merge(
                  data: IconThemeData(color: fg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });
}

Widget buildDivider(NodeSpec n, NodeScope s) {
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    return Divider(height: 1, thickness: 1, color: t.tint('muted', 0.18));
  });
}

Widget buildSpacer(NodeSpec n, NodeScope s) {
  final size = n.dbl('size', 16);
  return SizedBox(width: size, height: size);
}
