import 'package:flutter/material.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:sizer/sizer.dart';

/// Widget for entering menu item price with currency formatting
/// Supports USD currency with proper validation
class PriceInputWidget extends StatelessWidget {
  /// Text editing controller for price input
  final TextEditingController controller;

  /// Whether the widget is enabled
  final bool enabled;

  /// Callback when price changes
  final Function(String)? onChanged;

  const PriceInputWidget({
    super.key,
    required this.controller,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'السعر',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 1.h),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [],
          decoration: InputDecoration(
            hintText: '\$0.00',
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 2.w, right: 2.w),
              child: CustomIconWidget(
                iconName: 'attach_money',
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            prefixIconConstraints: BoxConstraints(minWidth: 12.w),
            filled: true,
            fillColor: colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2.0),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 2.h,
            ),
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: onChanged,
        ),
        SizedBox(height: 0.5.h),
        Text(
          'أدخل السعر بالدولار الأمريكي',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
