import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

/// The page look of the newer designs (Track Requests, Raise a New Ticket,
/// Financial Calculator): a tinted square back button beside a large
/// title, an optional ⋮ menu at the right, then the content. Colours come
/// from the active palette, so light / dark and every colour theme apply.
class DesignPage extends StatelessWidget {
  const DesignPage({super.key, required this.title, required this.child, this.onBack, this.menu});

  final String title;
  final Widget child;

  /// Back; a pushed route pops when null.
  final VoidCallback? onBack;

  /// The ⋮ menu's entries: label and action.
  final List<(String, VoidCallback)>? menu;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomeColors.bg(context),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final phone = c.maxWidth < 600;
            final pad = phone ? 16.0 : 36.0;
            return ListView(
              padding: EdgeInsets.fromLTRB(pad, phone ? 16 : 28, pad, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DesignPageHeader(title: title, onBack: onBack, menu: menu, compact: phone),
                        SizedBox(height: phone ? 16 : 20),
                        child,
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class DesignPageHeader extends StatelessWidget {
  const DesignPageHeader({super.key, required this.title, this.onBack, this.menu, this.compact = false});

  final String title;
  final VoidCallback? onBack;
  final List<(String, VoidCallback)>? menu;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final size = compact ? 40.0 : 44.0;
    return Row(
      children: [
        Tooltip(
          message: MaterialLocalizations.of(context).backButtonTooltip,
          child: Material(
            color: brand.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(Icons.arrow_back_ios_new_rounded, size: compact ? 18 : 22, color: HomeColors.brandDark(context)),
              ),
            ),
          ),
        ),
        SizedBox(width: compact ? 14 : 20),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: compact ? 24 : 32,
              fontWeight: FontWeight.w600,
              color: HomeColors.textPrimary(context),
              height: 1.15,
            ),
          ),
        ),
        if (menu != null && menu!.isNotEmpty)
          PopupMenuButton<int>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: Icon(Icons.more_vert_rounded, color: brand),
            color: HomeColors.card(context),
            onSelected: (i) => menu![i].$2(),
            itemBuilder: (_) => [
              for (final (i, (label, _)) in menu!.indexed) PopupMenuItem(value: i, child: Text(label)),
            ],
          ),
      ],
    );
  }
}

/// The designs' white card with a hairline border.
class DesignCard extends StatelessWidget {
  const DesignCard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HomeColors.divider(context)),
        ),
        child: child,
      );
}

/// A field with its label inside the border, above the value.
class DesignBoxField extends StatefulWidget {
  const DesignBoxField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
    this.suffixText,
    this.prefixText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffixText;
  final String? prefixText;

  @override
  State<DesignBoxField> createState() => _DesignBoxFieldState();
}

class _DesignBoxFieldState extends State<DesignBoxField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.error;
    final red = HomeColors.error(context);
    final text = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: HomeColors.textPrimary(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _focus.requestFocus,
          child: _BoxFrame(
            focused: _focus.hasFocus,
            error: error != null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: _labelStyle(context, error: error != null)),
                TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  style: text,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.only(top: 4, bottom: 2),
                    hintText: widget.hint,
                    hintStyle: text.copyWith(fontWeight: FontWeight.w400, color: HomeColors.textSecondary(context).withValues(alpha: 0.8)),
                    suffixText: widget.suffixText,
                    prefixText: widget.prefixText,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(error, style: TextStyle(fontSize: 11.5, color: red)),
          ),
      ],
    );
  }
}

/// A dropdown in the same box: small label, the value, a chevron.
class DesignBoxSelect extends StatelessWidget {
  const DesignBoxSelect({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.placeholder,
    this.loading = false,
    this.trailingIcon = Icons.keyboard_arrow_down_rounded,
    this.caption,
  });

  final String label;
  final String? value;
  final String? placeholder;

  /// A second, smaller label under [label] (Forex's "Currency").
  final String? caption;
  final VoidCallback? onTap;
  final bool loading;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final shown = value ?? placeholder ?? '';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: _BoxFrame(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _labelStyle(context, strong: caption != null)),
                    if (caption != null) ...[
                      const SizedBox(height: 6),
                      Text(caption!, style: _labelStyle(context)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      shown,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: value == null && placeholder != null ? HomeColors.textPrimary(context) : HomeColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Icon(trailingIcon, size: 20, color: onTap == null ? HomeColors.navInactive(context) : brand),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _labelStyle(BuildContext context, {bool error = false, bool strong = false}) => TextStyle(
      fontSize: strong ? 12.5 : 11.5,
      fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
      color: error
          ? HomeColors.error(context)
          : strong
              ? HomeColors.textPrimary(context)
              : HomeColors.textSecondary(context),
    );

class _BoxFrame extends StatelessWidget {
  const _BoxFrame({required this.child, this.focused = false, this.error = false});

  final Widget child;
  final bool focused;
  final bool error;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: HomeColors.card(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: error
                ? HomeColors.error(context)
                : focused
                    ? HomeColors.brand(context)
                    : HomeColors.divider(context),
            width: error || focused ? 1.4 : 1,
          ),
        ),
        child: child,
      );
}

/// The tinted result box: a caption, the headline figure in the brand
/// colour, then smaller lines.
class DesignResultPanel extends StatelessWidget {
  const DesignResultPanel({
    super.key,
    required this.caption,
    required this.value,
    this.lines = const [],
    this.note,
    this.detail,
    this.loading = false,
    this.minHeight = 84,
  });

  final String caption;
  final String value;

  /// Small label / value pairs under the figure, side by side.
  final List<(String, String)> lines;

  /// A plain line in the brand colour (Loan Eligibility's policy note).
  final String? note;

  /// A muted working line under the figure (Forex's "1,000 INR × rate").
  final String? detail;
  final bool loading;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final brand = HomeColors.brand(context);
    final small = TextStyle(fontSize: 11.5, color: HomeColors.textSecondary(context));
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: brand.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: brand.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(caption, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: brand)),
          const SizedBox(height: 2),
          loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
                )
              : Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: brand, height: 1.2)),
          if (detail != null) Text(detail!, style: small),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 120,
              runSpacing: 4,
              children: [
                for (final (label, v) in lines)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: label, style: small.copyWith(fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context))),
                        const TextSpan(text: '  '),
                        TextSpan(text: v, style: small.copyWith(fontWeight: FontWeight.w600, color: HomeColors.textPrimary(context))),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: TextStyle(fontSize: 11.5, color: brand)),
          ],
        ],
      ),
    );
  }
}
