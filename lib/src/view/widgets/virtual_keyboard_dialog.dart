import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ubci_bank/l10n/app_localizations.dart';
import 'package:ubci_bank/src/core/theme/app_colors.dart';

/// Web secure on-screen keyboard for credential entry (anti-keylogger).
class VirtualKeyboardDialog extends StatefulWidget {
  const VirtualKeyboardDialog({
    super.key,
    required this.controller,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final bool obscureText;

  /// Opens the keyboard and writes into [controller] until dismissed.
  static Future<void> show(
    BuildContext context, {
    required TextEditingController controller,
    bool obscureText = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => VirtualKeyboardDialog(
        controller: controller,
        obscureText: obscureText,
      ),
    );
  }

  @override
  State<VirtualKeyboardDialog> createState() => _VirtualKeyboardDialogState();
}

class _VirtualKeyboardDialogState extends State<VirtualKeyboardDialog> {
  static const _letters = [
    ['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
    ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
    ['z', 'x', 'c', 'v', 'b', 'n', 'm'],
  ];

  static const _digits = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'];

  static const _symbols = [
    ['!', '@', '#', '\$', '%', '^', '&', '*', '(', ')'],
    ['-', '_', '=', '+', '[', ']', '{', '}', '\\', '|'],
    [';', ':', '"', "'", '<', '>', ',', '.', '?', '/'],
  ];

  late List<List<String>> _letterRows;
  late List<String> _digitRow;
  bool _shift = false;
  bool _symbolsMode = false;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _letterRows = _letters.map((row) => List<String>.from(row)).toList();
    _digitRow = List<String>.from(_digits);
    _shuffleKeys();
  }

  void _shuffleKeys() {
    for (final row in _letterRows) {
      row.shuffle(_random);
    }
    _digitRow.shuffle(_random);
  }

  void _insert(String value) {
    final controller = widget.controller;
    final text = controller.text;
    final selection = controller.selection;
    final start =
        selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final safeStart = start.clamp(0, text.length);
    final safeEnd = end.clamp(0, text.length);
    final newText = text.replaceRange(safeStart, safeEnd, value);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: safeStart + value.length),
    );
    if (_shift && !_symbolsMode) {
      setState(() => _shift = false);
    } else {
      setState(() {});
    }
  }

  void _backspace() {
    final controller = widget.controller;
    final text = controller.text;
    if (text.isEmpty) return;

    final selection = controller.selection;
    if (selection.isValid && selection.start != selection.end) {
      final start = selection.start.clamp(0, text.length);
      final end = selection.end.clamp(0, text.length);
      final newText = text.replaceRange(start, end, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start),
      );
    } else {
      final cursor = selection.isValid
          ? selection.start.clamp(0, text.length)
          : text.length;
      if (cursor == 0) return;
      final newText = text.replaceRange(cursor - 1, cursor, '');
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor - 1),
      );
    }
    setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    setState(() {});
  }

  String _displayChar(String char) {
    if (_symbolsMode) return char;
    return _shift ? char.toUpperCase() : char;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width >= 720 ? 560.0 : width - 32;

    final rows = _symbolsMode
        ? _symbols
        : _letterRows.map((row) => row.map(_displayChar).toList()).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: colors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.keyboard_alt_outlined, color: colors.brand, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.virtualKeyboard,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.virtualKeyboardShuffle,
                    onPressed: () => setState(_shuffleKeys),
                    icon: Icon(Icons.shuffle, color: colors.textSecondary),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.inputBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.inputBorder),
                ),
                child: Text(
                  widget.controller.text.isEmpty
                      ? ' '
                      : (widget.obscureText
                          ? '•' * widget.controller.text.length
                          : widget.controller.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: widget.obscureText ? 2 : 0.2,
                    color: colors.textPrimary,
                    fontFamily: widget.obscureText ? null : 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    _KeyRow(
                      keys: _digitRow,
                      onTap: _insert,
                      colors: colors,
                    ),
                    const SizedBox(height: 6),
                    for (var i = 0; i < rows.length; i++) ...[
                      _KeyRow(
                        keys: rows[i],
                        onTap: _insert,
                        colors: colors,
                        leading: i == rows.length - 1 && !_symbolsMode
                            ? _ActionKey(
                                label: '⇧',
                                selected: _shift,
                                colors: colors,
                                flex: 12,
                                onTap: () =>
                                    setState(() => _shift = !_shift),
                              )
                            : null,
                        trailing: i == rows.length - 1
                            ? _ActionKey(
                                icon: Icons.backspace_outlined,
                                colors: colors,
                                flex: 12,
                                onTap: _backspace,
                              )
                            : null,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Row(
                      children: [
                        _ActionKey(
                          label: _symbolsMode ? 'ABC' : '!#1',
                          colors: colors,
                          flex: 14,
                          onTap: () =>
                              setState(() => _symbolsMode = !_symbolsMode),
                        ),
                        const SizedBox(width: 6),
                        _ActionKey(
                          label: l10n.virtualKeyboardSpace,
                          colors: colors,
                          flex: 40,
                          onTap: () => _insert(' '),
                        ),
                        const SizedBox(width: 6),
                        _ActionKey(
                          label: l10n.virtualKeyboardClear,
                          colors: colors,
                          flex: 14,
                          onTap: _clear,
                        ),
                        const SizedBox(width: 6),
                        _ActionKey(
                          label: l10n.virtualKeyboardDone,
                          colors: colors,
                          flex: 16,
                          filled: true,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
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

class _KeyRow extends StatelessWidget {
  const _KeyRow({
    required this.keys,
    required this.onTap,
    required this.colors,
    this.leading,
    this.trailing,
  });

  final List<String> keys;
  final ValueChanged<String> onTap;
  final AppColors colors;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _CharKey(
              label: keys[i],
              colors: colors,
              onTap: () => onTap(keys[i]),
            ),
          ),
        ],
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
    );
  }
}

class _CharKey extends StatelessWidget {
  const _CharKey({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colors.inputBackground,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.inputBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.colors,
    required this.onTap,
    this.label,
    this.icon,
    this.flex = 1,
    this.selected = false,
    this.filled = false,
  });

  final AppColors colors;
  final VoidCallback onTap;
  final String? label;
  final IconData? icon;
  final int flex;
  final bool selected;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? colors.brand
        : selected
            ? colors.brand.withValues(alpha: 0.15)
            : colors.secondaryButtonBg;
    final fg = filled ? Colors.white : colors.textPrimary;

    return Expanded(
      flex: flex,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            child: icon != null
                ? Icon(icon, size: 18, color: fg)
                : Text(
                    label ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Trailing icon that opens [VirtualKeyboardDialog] for a field.
class VirtualKeyboardIconButton extends StatelessWidget {
  const VirtualKeyboardIconButton({
    super.key,
    required this.controller,
    this.obscureText = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final bool obscureText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = AppColors.of(context);
    return IconButton(
      tooltip: l10n.virtualKeyboard,
      icon: Icon(
        Icons.keyboard_alt_outlined,
        color: colors.textSecondary,
        size: 20,
      ),
      onPressed: !enabled
          ? null
          : () => VirtualKeyboardDialog.show(
                context,
                controller: controller,
                obscureText: obscureText,
              ),
    );
  }
}
