import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Widget for displaying a list of popular/recent items
class PopularItemsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const PopularItemsList({
    super.key,
    required this.items,
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

    if (items.isEmpty) {
      return Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            'لا توجد عناصر',
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
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final itemName = item['name'] ?? 'عنصر بدون اسم';
          final itemPrice = item['price'] ?? '0.00';
          final itemImage = item['image'] ?? '';
          final itemCategory = item['category'] ?? 'غير مصنف';

          return ListTile(
            leading: itemImage.toString().isNotEmpty
                ? (itemImage.toString().startsWith('http')
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: itemImage.toString(),
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
                              Icons.restaurant_menu,
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
                          Icons.restaurant_menu,
                          size: iconSize,
                          color: colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ))
                : Container(
                    width: imageSize,
                    height: imageSize,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.restaurant_menu,
                      size: iconSize,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ),
            title: Text(
              itemName,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemCategory,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                    fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                  ),
                ),
                Text(
                  '$itemPrice \$',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 15 : (isTablet ? 14 : 13),
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

