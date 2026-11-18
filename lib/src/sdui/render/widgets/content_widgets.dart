import 'package:flutter/material.dart';

import '../../theme/dxp_theme.dart';
import '../node.dart';
import '../render_context.dart';
import 'common.dart';

Widget buildText(NodeSpec n, NodeScope s) {
  return DxpText(
    text: n.str('text'),
    style: n.str('style', 'body'),
    align: n.str('align', 'start'),
  );
}

class DxpText extends StatelessWidget {
  const DxpText({super.key, required this.text, required this.style, required this.align});

  final String text;
  final String style;
  final String align;

  @override
  Widget build(BuildContext context) {
    final t = DxpThemeScope.of(context);
    final onPrimary = OnPrimaryScope.of(context);
    final base = onPrimary ? t.onPrimary : t.onSurface;
    final mutedColor = onPrimary ? t.tint('onPrimary', 0.78) : t.muted;
    TextStyle ts;
    switch (style) {
      case 'headline':
        ts = TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.2, color: base, letterSpacing: -0.3);
        break;
      case 'title':
        ts = TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3, color: base);
        break;
      case 'caption':
        ts = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3, color: mutedColor, letterSpacing: 0.2);
        break;
      case 'muted':
        ts = TextStyle(fontSize: 14, height: 1.4, color: mutedColor);
        break;
      default:
        ts = TextStyle(fontSize: 15, height: 1.45, color: base);
    }
    final TextAlign ta;
    switch (align) {
      case 'center':
        ta = TextAlign.center;
        break;
      case 'end':
        ta = TextAlign.end;
        break;
      default:
        ta = TextAlign.start;
    }
    return Text(text, style: ts, textAlign: ta);
  }
}

Widget buildButton(NodeSpec n, NodeScope s) {
  final label = n.str('label', 'Continue');
  final variant = n.str('variant', 'primary');
  final iconName = n.strOrNull('icon');
  final onTap = s.handler(n, 'tap');
  final icon = iconName == null ? null : Icon(dxpIcon(iconName), size: 20);
  final text = Text(label, overflow: TextOverflow.ellipsis);
  return Builder(builder: (context) {
    final onPrimary = OnPrimaryScope.of(context);
    final t = DxpThemeScope.of(context);
    switch (variant) {
      case 'secondary':
        {
        final style = onPrimary
            ? OutlinedButton.styleFrom(
                foregroundColor: t.onPrimary,
                side: BorderSide(color: t.tint('onPrimary', 0.7), width: 1.4),
              )
            : null;
        return icon == null
            ? OutlinedButton(onPressed: onTap, style: style, child: text)
            : OutlinedButton.icon(onPressed: onTap, style: style, icon: icon, label: text);
        }
      case 'text':
        {
        final style = onPrimary ? TextButton.styleFrom(foregroundColor: t.onPrimary) : null;
        return icon == null
            ? TextButton(onPressed: onTap, style: style, child: text)
            : TextButton.icon(onPressed: onTap, style: style, icon: icon, label: text);
        }
      default:
        {
        final style = onPrimary
            ? ElevatedButton.styleFrom(backgroundColor: t.onPrimary, foregroundColor: t.primary)
            : null;
        return icon == null
            ? ElevatedButton(onPressed: onTap, style: style, child: text)
            : ElevatedButton.icon(onPressed: onTap, style: style, icon: icon, label: text);
        }
    }
  });
}

Widget buildBanner(NodeSpec n, NodeScope s) {
  final title = n.str('title');
  final text = n.str('text');
  final tone = n.str('tone', 'info');
  final iconName = n.strOrNull('icon') ??
      (tone == 'warning' ? 'info' : (tone == 'promo' ? 'star' : 'info'));
  final onTap = s.handler(n, 'tap');
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    Color bg;
    Color fg;
    Color iconBg;
    Gradient? gradient;
    switch (tone) {
      case 'promo':
        bg = t.secondary;
        fg = const Color(0xFFFFFFFF);
        iconBg = t.tint('primary', 0.9);
        gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[t.secondary, t.tint('primary', 0.95)],
        );
        break;
      case 'warning':
        bg = t.tint('warning', 0.12);
        fg = t.onSurface;
        iconBg = t.tint('warning', 0.2);
        break;
      default:
        bg = t.tint('primary', 0.09);
        fg = t.onSurface;
        iconBg = t.tint('primary', 0.16);
    }
    final iconColor = tone == 'promo'
        ? const Color(0xFFFFFFFF)
        : (tone == 'warning' ? t.warning : t.primary);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: t.borderRadius,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: t.borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: iconBg, borderRadius: t.innerRadius),
                  child: Icon(dxpIcon(iconName), color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (title.isNotEmpty)
                        Text(title,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
                      if (title.isNotEmpty && text.isNotEmpty) const SizedBox(height: 4),
                      if (text.isNotEmpty)
                        Text(text,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.4,
                                color: tone == 'promo' ? const Color(0xE6FFFFFF) : t.muted)),
                    ],
                  ),
                ),
                if (onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 10),
                    child: Icon(Icons.chevron_right_rounded,
                        color: tone == 'promo' ? const Color(0xFFFFFFFF) : t.muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  });
}

Widget buildResultPanel(NodeSpec n, NodeScope s) {
  final success = n.str('status', 'success') != 'failure';
  final title = n.str('title', success ? 'Done' : 'Something went wrong');
  final message = n.str('message');
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    final c = success ? t.success : t.danger;
    final tintName = success ? 'success' : 'danger';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: t.tint(tintName, 0.12), shape: BoxShape.circle),
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                child: Icon(success ? Icons.check_rounded : Icons.close_rounded,
                    color: const Color(0xFFFFFFFF), size: 38),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: t.onSurface)),
          if (message.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.45, color: t.muted)),
          ],
        ],
      ),
    );
  });
}

Widget buildReviewSummary(NodeSpec n, NodeScope s) {
  final rows = n
      .list('rows')
      .whereType<Map>()
      .map((r) => MapEntry(stringify(r['label']), stringify(r['value'])))
      .toList();
  return Builder(builder: (context) {
    final t = DxpThemeScope.of(context);
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(Divider(height: 1, color: t.tint('muted', 0.14)));
      final last = i == rows.length - 1;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              flex: 2,
              child: Text(rows[i].key, style: TextStyle(fontSize: 14, color: t.muted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(
                rows[i].value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: last ? 16 : 15,
                  fontWeight: last ? FontWeight.w700 : FontWeight.w600,
                  color: t.onSurface,
                ),
              ),
            ),
          ],
        ),
      ));
    }
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: t.borderRadius,
        boxShadow: t.softShadow,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  });
}
