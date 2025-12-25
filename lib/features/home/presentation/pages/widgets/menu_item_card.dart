import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:sizer/sizer.dart';

/// Individual menu item card with swipe actions
/// Displays item thumbnail, name, price, and action buttons
class MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MenuItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Slidable(
      key: ValueKey(item['id']),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            icon: Icons.edit_outlined,
            label: 'تعديل',
            borderRadius: BorderRadius.circular(12.0),
          ),
          SizedBox(width: 5),
          SlidableAction(
            onPressed: (_) => _showDeleteConfirmation(context),
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
            icon: Icons.delete_outline_rounded,
            label: 'حذف',
            borderRadius: BorderRadius.circular(12.0),
          ),
        ],
      ),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.08),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            onLongPress: () => _showContextMenu(context),
            borderRadius: BorderRadius.circular(12.0),
            child: Padding(
              padding: EdgeInsets.all(3.w),
              child: Row(
                children: [
                  _buildItemImage(colorScheme),
                  SizedBox(width: 3.w),
                  Expanded(child: _buildItemDetails(theme)),
                  _buildActionButtons(context, colorScheme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemImage(ColorScheme colorScheme) {
    final imageValue = (item['image'] ?? '').toString();
    final hasImage = imageValue.isNotEmpty;

    return Container(
      width: 20.w,
      height: 20.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8.0),
        color: colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? _buildImageWidget(imageValue, colorScheme)
          : Container(
              color: colorScheme.surfaceContainerHighest,
              child: Center(
                child: CustomIconWidget(
                  iconName: 'restaurant',
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                  size: 8.w,
                ),
              ),
            ),
    );
  }

  Widget _buildImageWidget(String imageValue, ColorScheme colorScheme) {
    if (imageValue.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageValue,
        width: 20.w,
        height: 20.w,
        fit: BoxFit.cover,
        placeholder: (context, url) => CustomIconWidget(
          iconName: 'restaurant',
          color: colorScheme.onSurface.withValues(alpha: 0.3),
          size: 8.w,
        ),
        errorWidget: (context, url, error) => CustomIconWidget(
          iconName: 'restaurant',
          color: colorScheme.onSurface.withValues(alpha: 0.3),
          size: 8.w,
        ),
      );
    }

    final file = File(imageValue);
    if (!file.existsSync()) {
      return Center(
        child: CustomIconWidget(
          iconName: 'restaurant',
          color: colorScheme.onSurface.withValues(alpha: 0.3),
          size: 8.w,
        ),
      );
    }

    return Image.file(file, width: 20.w, height: 20.w, fit: BoxFit.cover);
  }

  Widget _buildItemDetails(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item['name'] ?? 'عنصر بدون اسم',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: 0.5.h),
        Text(
          item['price'] != null ? '${item['price']} \$' : '\$0.00',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (item['description'] != null &&
            item['description'].toString().isNotEmpty) ...[
          SizedBox(height: 0.5.h),
          Text(
            item['description'],
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onEdit,
          icon: CustomIconWidget(
            iconName: 'edit_outlined',
            color: colorScheme.primary,
            size: 5.w,
          ),
          tooltip: 'تعديل',
          constraints: BoxConstraints(minWidth: 10.w, minHeight: 6.h),
          padding: EdgeInsets.zero,
        ),
        IconButton(
          onPressed: () => _showDeleteConfirmation(context),
          icon: CustomIconWidget(
            iconName: 'delete_outline',
            color: colorScheme.error,
            size: 5.w,
          ),
          tooltip: 'حذف',
          constraints: BoxConstraints(minWidth: 10.w, minHeight: 6.h),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف العنصر', style: theme.textTheme.titleLarge),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد أنك تريد حذف هذا العنصر؟',
              style: theme.textTheme.bodyMedium,
            ),
            SizedBox(height: 2.h),
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  ..._buildDialogImagePreview(colorScheme),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item['name'] ?? 'عنصر بدون اسم',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          item['price'] ?? '\$0.00',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDialogImagePreview(ColorScheme colorScheme) {
    final imageValue = (item['image'] ?? '').toString();
    if (imageValue.isEmpty) {
      return [];
    }

    final imageWidget = imageValue.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: imageValue,
            width: 12.w,
            height: 12.w,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => CustomIconWidget(
              iconName: 'restaurant',
              color: colorScheme.onSurface.withValues(alpha: 0.3),
              size: 6.w,
            ),
          )
        : Image.file(
            File(imageValue),
            width: 12.w,
            height: 12.w,
            fit: BoxFit.cover,
          );

    return [
      Container(
        width: 12.w,
        height: 12.w,
        margin: EdgeInsets.only(right: 2.w),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6.0)),
        clipBehavior: Clip.antiAlias,
        child: imageWidget,
      ),
    ];
  }

  void _showContextMenu(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: CustomIconWidget(
                iconName: 'edit_outlined',
                color: theme.colorScheme.primary,
                size: 6.w,
              ),
              title: Text('تعديل العنصر'),
              onTap: () {
                Navigator.pop(context);
                onEdit();
              },
            ),

            ListTile(
              leading: CustomIconWidget(
                iconName: 'delete',
                color: theme.colorScheme.error,
                size: 6.w,
              ),
              title: Text('حذف العنصر'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
