import 'package:flutter/material.dart';

/// Card widget for displaying statistics
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive sizing - cap at reasonable maximums for desktop
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final padding = isDesktop ? 20.0 : (isTablet ? 18.0 : 16.0);
    final iconSize = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final valuePaddingH = isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0);
    final valuePaddingV = isDesktop ? 8.0 : (isTablet ? 7.0 : 6.0);
    final spacing = isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: iconSize),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: valuePaddingH,
                  vertical: valuePaddingV,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  value,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
              fontSize: isDesktop ? 15 : (isTablet ? 14 : 13),
            ),
          ),
        ],
      ),
    );
  }
}
