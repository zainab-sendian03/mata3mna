import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({
    super.key,
    required this.icon,
    required this.theme,
    required this.label,
    required this.color,
    required this.onPressed,
    this.txtColor,
  });

  final ThemeData theme;
  final String label;
  final Color color;
  final Color? txtColor;

  final Widget? icon;
  final void Function() onPressed;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          onPressed();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            side: BorderSide.none,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon != null
                ? Row(children: [icon!, SizedBox(width: 5)])
                : Container(),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w300,
                color: txtColor != null
                    ? txtColor
                    : theme.scaffoldBackgroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
