import 'package:flutter/material.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:sizer/sizer.dart';

/// Empty state widget for categories with no items
/// Displays friendly message and action to add first item
class EmptyCategoryState extends StatelessWidget {
  final String categoryName;
  final VoidCallback onAddItem;

  const EmptyCategoryState({
    super.key,
    required this.categoryName,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 30.w,
              height: 30.w,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomIconWidget(
                  iconName: 'restaurant_menu_rounded',
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 15.w,
                ),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'لا توجد عناصر في $categoryName',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 1.h),
            Text(
              'ابدأ بناء قائمتك بإضافة أول عنصر',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 3.h),
            ElevatedButton.icon(
              onPressed: onAddItem,
              icon: CustomIconWidget(
                iconName: 'add',
                color: colorScheme.onPrimary,
                size: 5.w,
              ),
              label: Text('إضافة أول عنصر'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
