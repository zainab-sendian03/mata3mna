import 'package:flutter/material.dart';

/// Widget for displaying category distribution as a simple bar chart
class CategoryDistributionChart extends StatelessWidget {
  final Map<String, int> distribution;

  const CategoryDistributionChart({
    super.key,
    required this.distribution,
  });

  int get _maxValue {
    if (distribution.isEmpty) return 1;
    return distribution.values.reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing - cap at reasonable maximums for desktop
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final padding = isDesktop ? 20.0 : (isTablet ? 18.0 : 16.0);
    final itemSpacing = isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0);
    final barHeight = isDesktop ? 8.0 : (isTablet ? 7.0 : 6.0);
    final textSpacing = isDesktop ? 4.0 : (isTablet ? 3.5 : 3.0);

    if (distribution.isEmpty) {
      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'لا توجد بيانات',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: distribution.entries.map((entry) {
          final percentage = _maxValue > 0 ? entry.value / _maxValue : 0.0;
          return Padding(
            padding: EdgeInsets.only(bottom: itemSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 15 : (isTablet ? 14 : 13),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '${entry.value}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 14 : (isTablet ? 13 : 12),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: textSpacing),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: barHeight,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

