import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:sizer/sizer.dart';

/// Widget for selecting and displaying menu item images
/// Supports camera capture and gallery selection with preview
class ImagePickerWidget extends StatefulWidget {
  /// Current image URL (for edit mode)
  final String? imageUrl;

  /// Fallback image URL (e.g., restaurant logo) to show when no image is selected
  final String? fallbackImageUrl;

  /// Callback when image is selected
  final Function(XFile?) onImageSelected;

  /// Whether the widget is in loading state
  final bool isLoading;

  const ImagePickerWidget({
    super.key,
    this.imageUrl,
    this.fallbackImageUrl,
    required this.onImageSelected,
    this.isLoading = false,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: widget.isLoading ? null : _showImageSourceDialog,
      child: Container(
        width: double.infinity,
        height: 30.h,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: widget.isLoading
            ? Center(
                child: CircularProgressIndicator(color: colorScheme.primary),
              )
            : _buildImageContent(colorScheme),
      ),
    );
  }

  Widget _buildImageContent(ColorScheme colorScheme) {
    // Show selected image
    if (_selectedImage != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: kIsWeb
                ? Image.network(_selectedImage!.path, fit: BoxFit.cover)
                : Image.file(File(_selectedImage!.path), fit: BoxFit.cover),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: CustomIconWidget(
                  iconName: 'edit',
                  color: colorScheme.primary,
                  size: 20,
                ),
                onPressed: _showImageSourceDialog,
                tooltip: 'تغيير الصورة',
              ),
            ),
          ),
        ],
      );
    }

    // Show existing image URL
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildImagePreview(colorScheme),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: CustomIconWidget(
                  iconName: 'edit',
                  color: colorScheme.primary,
                  size: 20,
                ),
                onPressed: _showImageSourceDialog,
                tooltip: 'تغيير الصورة',
              ),
            ),
          ),
        ],
      );
    }

    // Show fallback image (restaurant logo) if available
    if (widget.fallbackImageUrl != null &&
        widget.fallbackImageUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildFallbackImagePreview(colorScheme),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: CustomIconWidget(
                  iconName: 'edit',
                  color: colorScheme.primary,
                  size: 20,
                ),
                onPressed: _showImageSourceDialog,
                tooltip: 'تغيير الصورة',
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'صورة المطعم (افتراضي)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    // Show placeholder with restaurant icon
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: CustomIconWidget(
            iconName: 'restaurant',
            color: colorScheme.primary,
            size: 40,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          'إضافة صورة العنصر (اختياري)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          'اضغط للاختيار من الكاميرا أو المعرض',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImagePreview(ColorScheme colorScheme) {
    final imageValue = (widget.imageUrl ?? '').toString();
    if (imageValue.isEmpty) {
      return Container();
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

    return Container(
      width: 12.w,
      height: 12.w,
      margin: EdgeInsets.only(right: 2.w),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6.0)),
      clipBehavior: Clip.antiAlias,
      child: imageWidget,
    );
  }

  Widget _buildFallbackImagePreview(ColorScheme colorScheme) {
    final fallbackUrl = (widget.fallbackImageUrl ?? '').toString();
    if (fallbackUrl.isEmpty) {
      return Container();
    }

    if (fallbackUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: fallbackUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: colorScheme.surfaceContainerHighest,
          child: Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: colorScheme.surfaceContainerHighest,
          child: Center(
            child: CustomIconWidget(
              iconName: 'restaurant',
              color: colorScheme.onSurface.withValues(alpha: 0.3),
              size: 40,
            ),
          ),
        ),
      );
    }

    return Image.file(
      File(fallbackUrl),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child: CustomIconWidget(
            iconName: 'restaurant',
            color: colorScheme.onSurface.withValues(alpha: 0.3),
            size: 40,
          ),
        ),
      ),
    );
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 2.h),
              Container(
                width: 10.w,
                height: 0.5.h,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 2.h),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'camera_alt',
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'التقاط صورة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'photo_library',
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                title: Text(
                  'اختيار من المعرض',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_selectedImage != null ||
                  (widget.imageUrl != null && widget.imageUrl!.isNotEmpty))
                ListTile(
                  leading: CustomIconWidget(
                    iconName: 'delete',
                    color: Theme.of(context).colorScheme.error,
                    size: 24,
                  ),
                  title: Text(
                    'إزالة الصورة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                    });
                    widget.onImageSelected(null);
                  },
                ),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
        widget.onImageSelected(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل اختيار الصورة: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
