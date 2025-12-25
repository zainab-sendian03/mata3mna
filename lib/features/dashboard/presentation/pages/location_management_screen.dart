import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/location_management_controller.dart';

/// Screen for managing locations (governorates and cities) in the admin dashboard
class LocationManagementScreen extends StatelessWidget {
  final bool hideAppBar;

  const LocationManagementScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      LocationManagementController(
        locationService: Get.find(),
        cacheHelper: Get.find(),
      ),
    );

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    final bodyContent = Obx(() {
      if (controller.isLoading.value) {
        return Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        );
      }

      if (controller.errorMessage.value.isNotEmpty) {
        final errorIconSize = isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0);
        final errorSpacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

        return Center(
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 40 : (isTablet ? 32 : 24)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: colorScheme.error,
                  size: errorIconSize,
                ),
                SizedBox(height: errorSpacing),
                Text(
                  controller.errorMessage.value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.error,
                    fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: errorSpacing),
                ElevatedButton(
                  onPressed: () => controller.refresh(),
                  child: Text(
                    'إعادة المحاولة',
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Responsive layout: stack on mobile, side-by-side on tablet/desktop
      if (screenWidth <= 768) {
        return Column(
          children: [
            // Governorates list
            Expanded(
              flex: 1,
              child: _buildGovernoratesList(
                context,
                controller,
                theme,
                colorScheme,
                isDesktop,
                isTablet,
              ),
            ),
            // Divider
            Container(height: 1, color: colorScheme.outline.withOpacity(0.2)),
            // Cities list
            Expanded(
              flex: 1,
              child: _buildCitiesList(
                context,
                controller,
                theme,
                colorScheme,
                isDesktop,
                isTablet,
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          // Left side: Governorates list
          Expanded(
            flex: 1,
            child: _buildGovernoratesList(
              context,
              controller,
              theme,
              colorScheme,
              isDesktop,
              isTablet,
            ),
          ),
          // Right side: Cities list for selected governorate
          Expanded(
            flex: 1,
            child: _buildCitiesList(
              context,
              controller,
              theme,
              colorScheme,
              isDesktop,
              isTablet,
            ),
          ),
        ],
      );
    });

    return Scaffold(
      appBar: hideAppBar
          ? null
          : AppBar(
              title: Text(
                'إدارة المناطق',
                style: isDesktop
                    ? theme.textTheme.displaySmall?.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      )
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                      ),
              ),
              backgroundColor: Colors.white,
              foregroundColor: colorScheme.onPrimary,
              actions: [
                IconButton(
                  icon: Icon(Icons.refresh, color: colorScheme.onSurface),
                  onPressed: () => controller.refresh(),
                ),
              ],
            ),
      body: hideAppBar
          ? Column(
              children: [
                // Header bar when AppBar is hidden
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24 : (isTablet ? 20 : 16),
                    vertical: isDesktop ? 16 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'إدارة المناطق',
                          style: isDesktop
                              ? theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                )
                              : theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: colorScheme.onSurface),
                        onPressed: () => controller.refresh(),
                      ),
                    ],
                  ),
                ),
                Expanded(child: bodyContent),
              ],
            )
          : bodyContent,
    );
  }

  Widget _buildGovernoratesList(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
  ) {
    final headerPadding = isDesktop ? 20.0 : (isTablet ? 16.0 : 12.0);
    final listPadding = isDesktop ? 16.0 : (isTablet ? 12.0 : 8.0);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(headerPadding),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المحافظات',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddGovernorateDialog(
                    context,
                    controller,
                    theme,
                    colorScheme,
                    isDesktop,
                    isTablet,
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: controller.governorates.isEmpty
                ? Center(
                    child: Text(
                      'لا توجد محافظات',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                        fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(listPadding),
                    itemCount: controller.governorates.length,
                    itemBuilder: (context, index) {
                      final governorate = controller.governorates[index];
                      final isSelected =
                          controller.selectedGovernorate.value == governorate;

                      return Card(
                        margin: EdgeInsets.only(
                          bottom: isDesktop ? 10 : (isTablet ? 8 : 6),
                        ),
                        elevation: isSelected
                            ? (isDesktop ? 6 : 4)
                            : (isDesktop ? 2 : 1),
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.outline.withOpacity(0.3),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 20 : (isTablet ? 16 : 12),
                            vertical: isDesktop ? 12 : (isTablet ? 8 : 4),
                          ),
                          title: Text(
                            governorate,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                iconSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                                color: colorScheme.primary,
                                onPressed: () => _showEditGovernorateDialog(
                                  context,
                                  controller,
                                  theme,
                                  colorScheme,
                                  governorate,
                                  isDesktop,
                                  isTablet,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                iconSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                                color: colorScheme.error,
                                onPressed: () => _showDeleteGovernorateDialog(
                                  context,
                                  controller,
                                  theme,
                                  colorScheme,
                                  governorate,
                                  isDesktop,
                                  isTablet,
                                ),
                              ),
                            ],
                          ),
                          onTap: () =>
                              controller.selectGovernorate(governorate),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCitiesList(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
  ) {
    final headerPadding = isDesktop ? 20.0 : (isTablet ? 16.0 : 12.0);
    final listPadding = isDesktop ? 16.0 : (isTablet ? 12.0 : 8.0);

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(headerPadding),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  controller.selectedGovernorate.value.isEmpty
                      ? 'اختر محافظة لعرض المدن'
                      : 'مدن ${controller.selectedGovernorate.value}',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                  ),
                ),
              ),
              if (controller.selectedGovernorate.value.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddCityDialog(
                    context,
                    controller,
                    theme,
                    colorScheme,
                    isDesktop,
                    isTablet,
                  ),
                ),
            ],
          ),
        ),
        // List
        Expanded(
          child: controller.selectedGovernorate.value.isEmpty
              ? Center(
                  child: Text(
                    'اختر محافظة لعرض المدن',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                    ),
                  ),
                )
              : Obx(() {
                  final cities = controller.selectedGovernorateCities;

                  if (cities.isEmpty) {
                    return Center(
                      child: Text(
                        'لا توجد مدن في هذه المحافظة',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(listPadding),
                    itemCount: cities.length,
                    itemBuilder: (context, index) {
                      final city = cities[index];

                      return Card(
                        margin: EdgeInsets.only(
                          bottom: isDesktop ? 10 : (isTablet ? 8 : 6),
                        ),
                        elevation: isDesktop ? 2 : 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 20 : (isTablet ? 16 : 12),
                            vertical: isDesktop ? 12 : (isTablet ? 8 : 4),
                          ),
                          title: Text(
                            city,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                iconSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                                color: colorScheme.primary,
                                onPressed: () => _showEditCityDialog(
                                  context,
                                  controller,
                                  theme,
                                  colorScheme,
                                  city,
                                  isDesktop,
                                  isTablet,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                iconSize: isDesktop ? 22 : (isTablet ? 20 : 18),
                                color: colorScheme.error,
                                onPressed: () => _showDeleteCityDialog(
                                  context,
                                  controller,
                                  theme,
                                  colorScheme,
                                  city,
                                  isDesktop,
                                  isTablet,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
        ),
      ],
    );
  }

  void _showAddGovernorateDialog(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
  ) {
    final nameController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = isDesktop
        ? 500.0
        : (isTablet ? 450.0 : screenWidth * 0.9);
    final formFieldFontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final labelFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final hintFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إضافة محافظة جديدة',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
        ),
        content: SizedBox(
          width: dialogWidth,
          child: TextField(
            style: TextStyle(fontSize: formFieldFontSize, height: 1.2),
            controller: nameController,
            decoration: InputDecoration(
              label: Text(
                'اسم المحافظة',
                style: TextStyle(fontSize: labelFontSize),
              ),
              hintText: 'أدخل اسم المحافظة',
              hintStyle: TextStyle(fontSize: hintFontSize),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await controller.addGovernorate(
                nameController.text,
              );
              if (success && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'إضافة',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditGovernorateDialog(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    String currentName,
    bool isDesktop,
    bool isTablet,
  ) {
    final nameController = TextEditingController(text: currentName);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = isDesktop
        ? 500.0
        : (isTablet ? 450.0 : screenWidth * 0.9);
    final formFieldFontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final labelFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final hintFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تعديل المحافظة',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
        ),
        content: SizedBox(
          width: dialogWidth,
          child: TextField(
            style: TextStyle(fontSize: formFieldFontSize, height: 1.2),
            controller: nameController,
            decoration: InputDecoration(
              label: Text(
                'اسم المحافظة',
                style: TextStyle(fontSize: labelFontSize),
              ),
              hintText: 'أدخل اسم المحافظة',
              hintStyle: TextStyle(fontSize: hintFontSize),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await controller.updateGovernorate(
                currentName,
                nameController.text,
              );
              if (success && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'حفظ',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteGovernorateDialog(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    String name,
    bool isDesktop,
    bool isTablet,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حذف المحافظة',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
        ),
        content: Text(
          'هل أنت متأكد من حذف المحافظة "$name"؟\n'
          'ملاحظة: يجب حذف جميع المدن في هذه المحافظة أولاً.',
          style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await controller.deleteGovernorate(name);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(
              'حذف',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCityDialog(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
  ) {
    final nameController = TextEditingController();
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = isDesktop
        ? 500.0
        : (isTablet ? 450.0 : screenWidth * 0.9);
    final formFieldFontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final labelFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final hintFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'إضافة مدينة جديدة في ${controller.selectedGovernorate.value}',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
        ),
        content: SizedBox(
          width: dialogWidth,
          child: TextField(
            style: TextStyle(fontSize: formFieldFontSize, height: 1.2),
            controller: nameController,
            decoration: InputDecoration(
              label: Text(
                'اسم المدينة',
                style: TextStyle(fontSize: labelFontSize),
              ),
              hintText: 'أدخل اسم المدينة',
              hintStyle: TextStyle(fontSize: hintFontSize),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await controller.addCity(nameController.text);
              if (success && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'إضافة',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCityDialog(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    String currentName,
    bool isDesktop,
    bool isTablet,
  ) {
    final nameController = TextEditingController(text: currentName);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = isDesktop
        ? 500.0
        : (isTablet ? 450.0 : screenWidth * 0.9);
    final formFieldFontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final labelFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final hintFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'تعديل المدينة',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
        ),
        content: SizedBox(
          width: dialogWidth,
          child: TextField(
            style: TextStyle(fontSize: formFieldFontSize, height: 1.2),
            controller: nameController,
            decoration: InputDecoration(
              label: Text(
                'اسم المدينة',
                style: TextStyle(fontSize: labelFontSize),
              ),
              hintText: 'أدخل اسم المدينة',
              hintStyle: TextStyle(fontSize: hintFontSize),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
            ),
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final success = await controller.updateCity(
                currentName,
                nameController.text,
              );
              if (success && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'حفظ',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteCityDialog(
    BuildContext context,
    LocationManagementController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    String cityName,
    bool isDesktop,
    bool isTablet,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'حذف المدينة',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 18 : 16)),
        ),
        content: Text(
          'هل أنت متأكد من حذف المدينة "$cityName"؟\n'
          'ملاحظة: يجب تغيير موقع المطاعم التي تستخدم هذه المدينة أولاً.',
          style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await controller.deleteCity(cityName);
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            child: Text(
              'حذف',
              style: TextStyle(fontSize: isDesktop ? 16 : (isTablet ? 15 : 14)),
            ),
          ),
        ],
      ),
    );
  }
}
