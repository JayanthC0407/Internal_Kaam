import 'package:flutter/material.dart';
import 'package:ubci_bank/src/view/screens/retail/home/home_colors.dart';

class HomeMenuButton extends StatelessWidget {
  const HomeMenuButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomeColors.card(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: HomeColors.divider(context)),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.menu_rounded, size: 20, color: HomeColors.textPrimary(context)),
        ),
      ),
    );
  }
}
