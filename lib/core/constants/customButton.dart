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
    this.isOutline = false,
    this.isLoading = false,
  });

  final ThemeData theme;
  final String label;
  final Color color;
  final Color? txtColor;
  final bool? isOutline;
  final Widget? icon;
  final void Function() onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    return SizedBox(
      width: double.infinity,
      child: isOutline!
          ? OutlinedButton(
              onPressed: isLoading ? null : onPressed,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  side: BorderSide.none,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (icon != null)
                    Row(children: [icon!, const SizedBox(width: 5)]),
                  if (isLoading) const SizedBox(width: 8),
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w300,
                      color: isLoading
                          ? theme.disabledColor
                          : (txtColor != null ? txtColor : theme.primaryColor),
                    ),
                  ),
                ],
              ),
            )
          : ElevatedButton(
              onPressed: isLoading ? null : onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: isLoading ? color.withOpacity(0.6) : color,
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
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Row(children: [icon!, const SizedBox(width: 5)]),
                  if (isLoading) const SizedBox(width: 8),
                  Text(
                    label,
                    style: isDesktop
                        ? TextStyle(fontSize: 25)
                        : theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w300,
                            color: isLoading
                                ? theme.scaffoldBackgroundColor.withOpacity(0.6)
                                : (txtColor != null
                                      ? txtColor
                                      : theme.scaffoldBackgroundColor),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
