import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ubci_bank/src/view/screens/auth/auth_colors.dart';

/// Four-digit OTP entry matching corporate banking pin-box layouts.
class OtpPinInput extends StatefulWidget {
  const OtpPinInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.length = 4,
    this.onCompleted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String>? onCompleted;
  final bool enabled;

  @override
  State<OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<OtpPinInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    if (text.length == widget.length) {
      widget.onCompleted?.call(text);
    }
    setState(() {});
  }

  void _onFocusChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final gaps = 7.5 * (widget.length - 1);
        final boxSize = math.min(48.0, (available - gaps) / widget.length)
            .clamp(36.0, 48.0);

        return GestureDetector(
          onTap: () => widget.focusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 1,
                  width: 1,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: widget.length,
                    autofocus: true,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.length, (index) {
                  final char = index < code.length ? code[index] : '';
                  final isActive = widget.focusNode.hasFocus &&
                      (code.length == index ||
                          (code.length == widget.length &&
                              index == widget.length - 1));

                  return Padding(
                    padding: EdgeInsets.only(left: index == 0 ? 0 : 7.5),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: boxSize,
                      height: boxSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AuthColors.inputBackground(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isActive
                              ? AuthColors.brand(context)
                              : AuthColors.inputBorder(context),
                          width: isActive ? 1.5 : 1,
                        ),
                      ),
                      child: char.isEmpty
                          ? null
                          : Text(
                              '•',
                              style: TextStyle(
                                fontSize: (boxSize * 0.46).clamp(16.0, 22.0),
                                fontWeight: FontWeight.w600,
                                color: AuthColors.textPrimary(context),
                              ),
                            ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
