import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget for displaying a list of recent restaurants
class RecentRestaurantsList extends StatelessWidget {
  final List<Map<String, dynamic>> restaurants;

  const RecentRestaurantsList({
    super.key,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Responsive sizing - cap at reasonable maximums for desktop
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final padding = isDesktop ? 16.0 : (isTablet ? 14.0 : 12.0);
    final imageSize = isDesktop ? 56.0 : (isTablet ? 52.0 : 48.0);
    final iconSize = isDesktop ? 28.0 : (isTablet ? 26.0 : 24.0);
    final badgePaddingH = isDesktop ? 10.0 : (isTablet ? 9.0 : 8.0);
    final badgePaddingV = isDesktop ? 4.0 : (isTablet ? 3.5 : 3.0);

    if (restaurants.isEmpty) {
      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'لا توجد مطاعم',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          final restaurantName = restaurant['name'] ?? 'مطعم بدون اسم';
          final restaurantStatus = restaurant['status'] ?? 'غير محدد';
          final restaurantLogo = restaurant['logoPath'] ?? '';
          final restaurantCity = restaurant['city'] ?? '';
          final restaurantGovernorate = restaurant['governorate'] ?? '';

          return ListTile(
            leading: restaurantLogo.toString().isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: restaurantLogo.toString(),
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: imageSize,
                        height: imageSize,
                        color: colorScheme.surfaceContainerHighest,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: imageSize,
                        height: imageSize,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.restaurant,
                          size: iconSize,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ),
                    ),
                  )
                : Container(
                    width: imageSize,
                    height: imageSize,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.restaurant,
                      size: iconSize,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
            title: Text(
              restaurantName,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (restaurantCity.isNotEmpty || restaurantGovernorate.isNotEmpty)
                  Text(
                    '${restaurantCity.isNotEmpty ? restaurantCity : ''}${restaurantCity.isNotEmpty && restaurantGovernorate.isNotEmpty ? '، ' : ''}${restaurantGovernorate.isNotEmpty ? restaurantGovernorate : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                    ),
                  ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: badgePaddingH,
                    vertical: badgePaddingV,
                  ),
                  decoration: BoxDecoration(
                    color: restaurantStatus == 'active'
                        ? colorScheme.primaryContainer
                        : colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    restaurantStatus == 'active' ? 'نشط' : 'غير نشط',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: restaurantStatus == 'active'
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: isDesktop ? 12 : (isTablet ? 11 : 10),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

