import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/admin_restaurant_controller.dart';
import 'package:mata3mna/features/dashboard/data/services/location_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/admin_firestore_service.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mata3mna/core/services/supabase_storage_service.dart';
import 'package:mata3mna/core/widgets/expandable_text.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:typed_data';

/// Screen for managing restaurants in admin dashboard
class AdminRestaurantManagementScreen extends StatelessWidget {
  final bool hideAppBar;

  const AdminRestaurantManagementScreen({super.key, this.hideAppBar = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AdminRestaurantController());
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    // Check if admin is authenticated - if not, redirect to login
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed(AppPages.adminLogin);
      });
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    return Obx(() {
      if (controller.isLoading.value && controller.restaurants.isEmpty) {
        return Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        );
      }

      if (controller.errorMessage.value.isNotEmpty) {
        final errorIconSize = isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0);
        final errorSpacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

        return Column(
          children: [
            Center(
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (controller.errorMessage.value.contains('صلاحية') ||
                            controller.errorMessage.value.contains(
                              'permission',
                            ))
                          ElevatedButton(
                            onPressed: () {
                              Get.offAllNamed('/admin-login');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                            ),
                            child: const Text('تسجيل الدخول'),
                          ),
                        if (controller.errorMessage.value.contains('صلاحية') ||
                            controller.errorMessage.value.contains(
                              'permission',
                            ))
                          SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () => controller.refresh(),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return Material(
        child: Column(
          children: [
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
                  if (!hideAppBar)
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () => Get.back(),
                    ),
                  Expanded(
                    child: Text(
                      'إدارة المطاعم',
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
                    icon: Icon(Icons.add, color: colorScheme.onSurface),
                    onPressed: () =>
                        _showAddEditRestaurantDialog(context, controller, null),
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh, color: colorScheme.onSurface),
                    onPressed: () => controller.refresh(),
                  ),
                ],
              ),
            ),
            // Search bar
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : (isTablet ? 32 : 20),
                vertical: isDesktop ? 24 : (isTablet ? 20 : 16),
              ),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 800 : double.infinity,
                  ),
                  child: TextField(
                    keyboardType: TextInputType.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                    ),
                    onChanged: (value) => controller.searchQuery.value = value,
                    decoration: InputDecoration(
                      hintText: 'بحث في المطاعم...',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                        fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: controller.searchQuery.value.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () =>
                                  controller.searchQuery.value = '',
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 16 : 12,
                        vertical: isDesktop ? 16 : 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Restaurants list
            Expanded(
              child: controller.filteredRestaurants.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0),
                            color: colorScheme.onSurface.withOpacity(0.5),
                          ),
                          SizedBox(
                            height: isDesktop ? 24 : (isTablet ? 20 : 16),
                          ),
                          Text(
                            controller.searchQuery.value.isNotEmpty
                                ? 'لا توجد نتائج للبحث'
                                : 'لا توجد مطاعم',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurface.withOpacity(0.7),
                              fontSize: isDesktop ? 18 : (isTablet ? 16 : 14),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 1400 : double.infinity,
                        ),
                        child: isDesktop
                            ? ListView.builder(
                                padding: EdgeInsets.all(24),
                                itemCount:
                                    controller.filteredRestaurants.length,
                                itemBuilder: (context, index) {
                                  final restaurant =
                                      controller.filteredRestaurants[index];
                                  return _buildRestaurantCard(
                                    context,
                                    restaurant,
                                    controller,
                                    theme,
                                    colorScheme,
                                    isDesktop,
                                    isTablet,
                                  );
                                },
                              )
                            : ListView.builder(
                                padding: EdgeInsets.all(isTablet ? 20 : 16),
                                itemCount:
                                    controller.filteredRestaurants.length,
                                itemBuilder: (context, index) {
                                  final restaurant =
                                      controller.filteredRestaurants[index];
                                  return _buildRestaurantCard(
                                    context,
                                    restaurant,
                                    controller,
                                    theme,
                                    colorScheme,
                                    isDesktop,
                                    isTablet,
                                  );
                                },
                              ),
                      ),
                    ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildRestaurantCard(
    BuildContext context,
    Map<String, dynamic> restaurant,
    AdminRestaurantController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
  ) {
    final logoUrl = restaurant['logo_path'] as String? ?? '';
    final status = restaurant['status'] as String? ?? 'active';

    final logoSize = isDesktop ? 100.0 : (isTablet ? 80.0 : 60.0);
    final cardPadding = isDesktop ? 20.0 : (isTablet ? 20.0 : 16.0);
    final cardSpacing = isDesktop ? 20.0 : (isTablet ? 16.0 : 12.0);

    final restaurantId = (restaurant['id'] ?? '').toString();
    final restaurantName = (restaurant['name'] ?? 'بدون اسم').toString();

    return Card(
      margin: EdgeInsets.only(bottom: isDesktop ? 10 : (isTablet ? 16 : 12)),
      elevation: isDesktop ? 4 : 2,
      clipBehavior: Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline),
      ),
      child: InkWell(
        onTap: restaurantId.isNotEmpty
            ? () => Get.toNamed(
                  AppPages.adminItemManagement,
                  arguments: {
                    'restaurantId': restaurantId,
                    'restaurantName': restaurantName,
                  },
                )
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: EdgeInsets.all(cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: logoUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: logoUrl,
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: logoSize,
                        height: logoSize,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.restaurant,
                          size: logoSize * 0.5,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    )
                  : Container(
                      width: logoSize,
                      height: logoSize,
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.restaurant,
                        size: logoSize * 0.5,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
            ),
            SizedBox(width: cardSpacing),

            // Restaurant info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant['name'] ?? 'بدون اسم',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'active'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status == 'active' ? 'نشط' : 'غير نشط',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: status == 'active'
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: isDesktop ? 13 : (isTablet ? 12 : 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  if (restaurant['phone'] != null &&
                      restaurant['phone'].toString().isNotEmpty)
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 16,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                        SizedBox(width: 4),
                        Text(
                          restaurant['phone'].toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                            fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${restaurant['governorate'] ?? ''} - ${restaurant['city'] ?? ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                        ),
                      ),
                    ],
                  ),
                  if (restaurant['description'] != null &&
                      restaurant['description'].toString().isNotEmpty) ...[
                    SizedBox(height: 8),
                    ExpandableText(
                      text: restaurant['description'].toString(),
                      maxLines: 2,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isDesktop ? 18 : (isTablet ? 18 : 16),
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      linkStyle: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isDesktop ? 18 : (isTablet ? 18 : 16),
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAddEditRestaurantDialog(
                    context,
                    controller,
                    restaurant,
                  ),
                  color: colorScheme.primary,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      _showDeleteDialog(context, controller, restaurant),
                  color: colorScheme.error,
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showAddEditRestaurantDialog(
    BuildContext context,
    AdminRestaurantController controller,
    Map<String, dynamic>? restaurant,
  ) {
    final isEdit = restaurant != null;
    final nameController = TextEditingController(
      text: restaurant?['name'] ?? '',
    );
    final phoneController = TextEditingController(
      text: restaurant?['phone'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: restaurant?['description'] ?? '',
    );
    String? selectedOwnerId = restaurant?['owner_id'];
    String? selectedOwnerEmail = restaurant?['owner_email'];
    Map<String, dynamic>? selectedOwner;
    final ownerPasswordController = TextEditingController();

    String? selectedGovernorate = restaurant?['governorate'];
    String? selectedCity = restaurant?['city'];
    String? selectedStatus = restaurant?['status'] ?? 'active';
    String? logoUrl = restaurant?['logo_path'];
    XFile? selectedLogo;
    Uint8List? selectedLogoBytes;

    final locationService = Get.find<LocationSupabaseService>();
    final adminService = Get.find<AdminFirestoreService>();
    final storageService = Get.find<SupabaseStorageService>();
    final imagePicker = ImagePicker();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    bool isPasswordVisible = false;
    final formKey = GlobalKey<FormState>();

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final dialogWidth = isDesktop
        ? 600.0
        : (isTablet ? 600.0 : screenWidth * 0.95);
    final dialogPadding = isDesktop ? 32.0 : (isTablet ? 28.0 : 24.0);
    final dialogSpacing = isDesktop ? 24.0 : (isTablet ? 20.0 : 16.0);

    // Responsive font sizes for form fields
    final formFieldFontSize = isDesktop ? 16.0 : (isTablet ? 15.0 : 14.0);
    final labelFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final hintFontSize = isDesktop ? 15.0 : (isTablet ? 14.0 : 13.0);
    final errorFontSize = isDesktop ? 11.0 : (isTablet ? 10.0 : 9.0);

    Get.dialog(
      Dialog(
        child: Container(
          width: dialogWidth,
          padding: EdgeInsets.all(dialogPadding),
          child: StatefulBuilder(
            builder: (context, setState) {
              return Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'تعديل مطعم' : 'إضافة مطعم جديد',
                        style: isDesktop
                            ? theme.textTheme.labelSmall?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              )
                            : theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: isDesktop ? 24 : (isTablet ? 22 : 20),
                              ),
                      ),
                      SizedBox(height: dialogSpacing),

                      // Owner Selection (only for new restaurants)
                      if (!isEdit)
                        StatefulBuilder(
                          builder: (context, setOwnerState) {
                            final ownerEmailController = TextEditingController(
                              text: selectedOwnerEmail ?? '',
                            );
                            bool showEmailInput = selectedOwner == null;

                            return FutureBuilder<List<Map<String, dynamic>>>(
                              future: adminService.getAllOwners(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }

                                final owners = snapshot.data ?? [];

                                // Find selected owner if exists
                                if (selectedOwnerId != null &&
                                    selectedOwner == null &&
                                    owners.isNotEmpty) {
                                  selectedOwner = owners.firstWhere(
                                    (owner) =>
                                        owner['id'] == selectedOwnerId ||
                                        owner['uid'] == selectedOwnerId,
                                    orElse: () => {},
                                  );
                                  if (selectedOwner!.isEmpty) {
                                    selectedOwner = null;
                                  } else {
                                    selectedOwnerEmail =
                                        selectedOwner?['email'];
                                    ownerEmailController.text =
                                        selectedOwnerEmail ?? '';
                                  }
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Email input for new owner
                                    if (showEmailInput) ...[
                                      TextField(
                                        style: TextStyle(
                                          fontSize: formFieldFontSize,
                                          height: 1.2,
                                        ),
                                        controller: ownerEmailController,
                                        decoration: InputDecoration(
                                          label: Text(
                                            'البريد الإلكتروني للمالك الجديد *',
                                            style: TextStyle(
                                              fontSize: labelFontSize,
                                            ),
                                          ),
                                          hintText: 'example@gmail.com',
                                          hintStyle: TextStyle(
                                            fontSize: hintFontSize,
                                            color: Colors.grey.shade500,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme
                                              .surfaceContainerHighest,
                                          helperStyle: TextStyle(
                                            fontSize: hintFontSize - 1,
                                          ),

                                          helperText:
                                              'سيتم إنشاء حساب جديد للمالك مع كلمة مرور',
                                        ),
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        onChanged: (value) {
                                          selectedOwnerEmail = value.trim();
                                          selectedOwner = null;
                                          selectedOwnerId = null;
                                        },
                                      ),
                                      SizedBox(height: dialogSpacing),
                                      // Password input for new owner
                                      TextFormField(
                                        style: TextStyle(
                                          fontSize: formFieldFontSize,
                                          height: 1.2,
                                        ),
                                        keyboardType: TextInputType.text,
                                        controller: ownerPasswordController,
                                        obscureText: !isPasswordVisible,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'كلمة المرور مطلوبة';
                                          }
                                          if (value.length < 8) {
                                            return 'كلمة المرور يجب أن تكون 8 أحرف على الأقل';
                                          }
                                          if (value.length > 50) {
                                            return 'كلمة المرور يجب أن تكون أقل من 50 حرف';
                                          }
                                          // Check for uppercase, lowercase, and number
                                          if (!RegExp(
                                            r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)',
                                          ).hasMatch(value)) {
                                            return 'كلمة المرور يجب أن تحتوي على حرف كبير، حرف صغير، ورقم واحد على الأقل';
                                          }
                                          return null;
                                        },
                                        decoration: InputDecoration(
                                          label: Text(
                                            'كلمة المرور للمالك الجديد *',
                                            style: TextStyle(
                                              fontSize: labelFontSize,
                                            ),
                                          ),
                                          hintText: 'أدخل كلمة مرور قوية',
                                          hintStyle: TextStyle(
                                            fontSize: hintFontSize,
                                            color: Colors.grey.shade500,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: colorScheme
                                              .surfaceContainerHighest,
                                          helperText:
                                              'يجب أن تحتوي على 8 أحرف على الأقل، حرف كبير، حرف صغير، ورقم',
                                          helperStyle: TextStyle(
                                            fontSize: hintFontSize - 1,
                                          ),
                                          errorStyle: TextStyle(
                                            fontSize: errorFontSize,
                                            height: 0.8,
                                          ),
                                          errorMaxLines: 3,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              isPasswordVisible
                                                  ? Icons.visibility
                                                  : Icons.visibility_off,
                                            ),
                                            onPressed: () {
                                              setOwnerState(() {
                                                isPasswordVisible =
                                                    !isPasswordVisible;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      if (!isEdit) SizedBox(height: dialogSpacing),

                      // Show owner info in edit mode
                      if (isEdit)
                        FutureBuilder<String?>(
                          future: selectedOwnerEmail != null
                              ? Future.value(selectedOwnerEmail)
                              : (selectedOwnerId != null
                                    ? adminService.getAllOwners().then((
                                        owners,
                                      ) {
                                        final owner = owners.firstWhere(
                                          (o) =>
                                              (o['id'] ?? o['uid']) ==
                                              selectedOwnerId,
                                          orElse: () => {},
                                        );
                                        if (owner.isEmpty) return null;
                                        return owner['email'] as String?;
                                      })
                                    : Future.value(null)),
                          builder: (context, snapshot) {
                            final displayEmail =
                                snapshot.data ??
                                selectedOwnerEmail ??
                                'غير محدد';
                            return Container(
                              padding: EdgeInsets.all(isDesktop ? 16 : 12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'البريد الإلكتروني للمالك:',
                                    style: isDesktop
                                        ? theme.textTheme.labelMedium?.copyWith(
                                            fontSize: labelFontSize,
                                          )
                                        : theme.textTheme.labelMedium?.copyWith(
                                            fontSize: isDesktop ? 14 : 13,
                                          ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    displayEmail,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontSize: formFieldFontSize,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (isEdit) SizedBox(height: dialogSpacing),

                      // Name
                      TextField(
                        style: TextStyle(
                          fontSize: 20, // نفس حجم الخط للـ hintStyle
                          height: 1.2, // يقلل من ارتفاع السطر ويصغر cursor
                        ),
                        controller: nameController,
                        decoration: InputDecoration(
                          label: Text(
                            'اسم المطعم *',
                            style: TextStyle(fontSize: labelFontSize),
                          ),
                          hintText: 'أدخل اسم المطعم',
                          hintStyle: TextStyle(fontSize: labelFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      SizedBox(height: dialogSpacing),

                      // Phone
                      TextField(
                        style: TextStyle(
                          fontSize: 20, // نفس حجم الخط للـ hintStyle
                          height: 1.2, // يقلل من ارتفاع السطر ويصغر cursor
                        ),
                        controller: phoneController,
                        decoration: InputDecoration(
                          label: Text(
                            'رقم الهاتف *',
                            style: TextStyle(fontSize: labelFontSize),
                          ),
                          hintText: 'أدخل رقم الهاتف',
                          hintStyle: TextStyle(fontSize: labelFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      SizedBox(height: dialogSpacing),

                      // Governorate
                      FutureBuilder<List<String>>(
                        future: locationService.getGovernorates(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return CircularProgressIndicator();
                          }
                          final governorates = snapshot.data ?? [];
                          return DropdownButtonFormField<String>(
                            value: selectedGovernorate,
                            style: TextStyle(
                              fontSize: formFieldFontSize,
                              height: 1.2,
                            ),
                            decoration: InputDecoration(
                              label: Text(
                                'المحافظة *',
                                style: TextStyle(fontSize: labelFontSize),
                              ),
                              hintText: 'أختر المحافظة',
                              hintStyle: TextStyle(
                                fontSize: hintFontSize,
                                height: 1.2,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surfaceContainerHighest,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isDesktop ? 16 : 12,
                                vertical: isDesktop ? 16 : 14,
                              ),
                            ),
                            items: governorates.map((gov) {
                              return DropdownMenuItem(
                                value: gov,
                                child: Text(
                                  gov,
                                  style: TextStyle(fontSize: formFieldFontSize),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedGovernorate = value;
                                selectedCity = null;
                              });
                            },
                          );
                        },
                      ),
                      SizedBox(height: dialogSpacing),

                      // City
                      if (selectedGovernorate != null)
                        FutureBuilder<List<String>>(
                          future: locationService.getCitiesByGovernorate(
                            selectedGovernorate!,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return CircularProgressIndicator();
                            }
                            final cities = snapshot.data ?? [];
                            // Remove duplicates while preserving order
                            final uniqueCities = <String>[];
                            final seenCities = <String>{};
                            for (final city in cities) {
                              if (!seenCities.contains(city)) {
                                uniqueCities.add(city);
                                seenCities.add(city);
                              }
                            }

                            return DropdownButtonFormField<String>(
                              value: selectedCity,
                              style: TextStyle(
                                fontSize: 20, // نفس حجم الخط للـ hintStyle
                                height:
                                    1.2, // يقلل من ارتفاع السطر ويصغر cursor
                              ),
                              decoration: InputDecoration(
                                label: Text(
                                  'المدينة *',
                                  style: TextStyle(fontSize: labelFontSize),
                                ),
                                hintText: 'أختر المدينة',
                                hintStyle: TextStyle(fontSize: 20),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: colorScheme.surfaceContainerHighest,
                              ),
                              items: uniqueCities.map((city) {
                                return DropdownMenuItem(
                                  value: city,
                                  child: Text(city),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => selectedCity = value);
                              },
                            );
                          },
                        ),
                      if (selectedGovernorate != null)
                        SizedBox(height: dialogSpacing),

                      // Status
                      DropdownButtonFormField<String>(
                        style: TextStyle(
                          fontSize: formFieldFontSize,
                          height: 1.2,
                        ),
                        value: selectedStatus,
                        decoration: InputDecoration(
                          label: Text(
                            'الحالة',
                            style: TextStyle(fontSize: labelFontSize),
                          ),
                          hintText: 'أختر الحالة',
                          hintStyle: TextStyle(fontSize: hintFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 16 : 12,
                            vertical: isDesktop ? 16 : 14,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'active',
                            child: Text(
                              'نشط',
                              style: TextStyle(fontSize: formFieldFontSize),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text(
                              'غير نشط',
                              style: TextStyle(fontSize: formFieldFontSize),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedStatus = value),
                      ),
                      SizedBox(height: dialogSpacing),

                      // Description
                      TextField(
                        style: TextStyle(
                          fontSize: formFieldFontSize,
                          height: 1.2,
                        ),
                        controller: descriptionController,
                        decoration: InputDecoration(
                          label: Text(
                            'الوصف',
                            style: TextStyle(fontSize: labelFontSize),
                          ),
                          hintText: 'أدخل الوصف',
                          hintStyle: TextStyle(fontSize: hintFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: dialogSpacing),

                      // Logo Image Picker
                      Row(
                        children: [
                          if (selectedLogoBytes != null ||
                              (logoUrl != null && logoUrl!.isNotEmpty))
                            Container(
                              width: 80,
                              height: 80,
                              margin: EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: selectedLogoBytes != null
                                    ? Image.memory(
                                        selectedLogoBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : logoUrl != null && logoUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: logoUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : SizedBox.shrink(),
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () async {
                              try {
                                final picked = await imagePicker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (picked != null) {
                                  // Read image bytes for web compatibility
                                  final bytes = await picked.readAsBytes();
                                  setState(() {
                                    selectedLogo = picked;
                                    selectedLogoBytes = bytes;
                                    logoUrl = null;
                                  });
                                }
                              } catch (e) {
                                Get.snackbar(
                                  'خطأ',
                                  'فشل اختيار الصورة: $e',
                                  maxWidth: Get.width > 1200
                                      ? 400.0
                                      : (Get.width > 768 ? 350.0 : null),
                                  margin: Get.width > 768
                                      ? EdgeInsets.symmetric(
                                          horizontal: Get.width > 1200
                                              ? (Get.width - 400.0) / 2
                                              : (Get.width - 350.0) / 2,
                                          vertical: 16,
                                        )
                                      : EdgeInsets.all(16),
                                  snackStyle: SnackStyle.FLOATING,
                                  borderRadius: 12,
                                );
                              }
                            },
                            icon: Icon(Icons.image),
                            label: Text(
                              'اختر شعار المطعم',
                              style: TextStyle(
                                fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: dialogSpacing * 1.5),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text(
                              'إلغاء',
                              style: TextStyle(
                                fontSize: isDesktop ? 20 : (isTablet ? 16 : 14),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Obx(
                            () => ElevatedButton(
                              onPressed: controller.isLoading.value
                                  ? null
                                  : () async {
                                      // Set loading state immediately
                                      controller.isLoading.value = true;

                                      if (nameController.text.isEmpty ||
                                          phoneController.text.isEmpty ||
                                          selectedGovernorate == null ||
                                          selectedCity == null) {
                                        Get.snackbar(
                                          'خطأ',
                                          'يرجى ملء جميع الحقول المطلوبة',
                                        );
                                        controller.isLoading.value = false;
                                        return;
                                      }

                                      if (!isEdit) {
                                        // Validate owner selection
                                        if (selectedOwnerEmail == null ||
                                            selectedOwnerEmail!.isEmpty) {
                                          Get.snackbar(
                                            'خطأ',
                                            'يرجى اختيار المالك أو إدخال البريد الإلكتروني',
                                            maxWidth: Get.width > 1200
                                                ? 400.0
                                                : (Get.width > 768
                                                      ? 350.0
                                                      : null),
                                            margin: Get.width > 768
                                                ? EdgeInsets.symmetric(
                                                    horizontal: Get.width > 1200
                                                        ? (Get.width - 400.0) /
                                                              2
                                                        : (Get.width - 350.0) /
                                                              2,
                                                    vertical: 16,
                                                  )
                                                : EdgeInsets.all(16),
                                            snackStyle: SnackStyle.FLOATING,
                                            borderRadius: 12,
                                          );
                                          controller.isLoading.value = false;
                                          return;
                                        }

                                        // If owner selected from dropdown, use their ID
                                        // If email entered manually, create/get user first
                                        String finalOwnerId =
                                            selectedOwnerId ?? '';
                                        String finalOwnerEmail =
                                            selectedOwnerEmail!;

                                        if (finalOwnerId.isEmpty) {
                                          // Try to find existing user by email first (without creating Auth account)
                                          try {
                                            final existingUser = await adminService
                                                .getUserByEmailOnly(finalOwnerEmail);
                                            
                                            if (existingUser != null) {
                                              // User exists in users table, use their ID
                                              finalOwnerId = existingUser['id'] as String? ?? '';
                                              finalOwnerEmail = existingUser['email'] as String? ?? finalOwnerEmail;
                                              print(
                                                '[AdminRestaurantManagement] Found existing user: $finalOwnerId',
                                              );
                                            } else {
                                              // User doesn't exist - check if password is provided
                                              final password = ownerPasswordController.text.trim();
                                              
                                              if (password.isEmpty) {
                                                // No password provided - allow creating restaurant with email only
                                                // owner_id will be null/empty, restaurant will be linked by email
                                                print(
                                                  '[AdminRestaurantManagement] No password provided, creating restaurant with email only: $finalOwnerEmail',
                                                );
                                                // finalOwnerId will remain empty, which is OK
                                                // The restaurant will be created with owner_email only
                                              } else {
                                                // Password provided - try to create/get user
                                                // Validate form first
                                                if (!formKey.currentState!.validate()) {
                                                  controller.isLoading.value = false;
                                                  return;
                                                }

                                                try {
                                                  final user = await adminService
                                                      .createOrGetUserByEmail(
                                                        finalOwnerEmail,
                                                        password,
                                                      );
                                                  finalOwnerId =
                                                      user['id'] ?? user['uid'];
                                                  finalOwnerEmail =
                                                      user['email'] ??
                                                      finalOwnerEmail;
                                                } catch (e) {
                                                  final errorMsg = e.toString();
                                                  
                                                  // Special handling for rate limit - allow creating restaurant with email only
                                                  if (errorMsg.contains('RATE_LIMIT_HIT')) {
                                                    print(
                                                      '[AdminRestaurantManagement] Rate limit hit. Creating restaurant with email only. User can sign up later.',
                                                    );
                                                    Get.snackbar(
                                                      'تنبيه',
                                                      'تم تجاوز حد إنشاء الحسابات في Supabase.\n\n'
                                                      'سيتم إنشاء المطعم بربطه بالبريد الإلكتروني فقط.\n'
                                                      'يمكن لصاحب المطعم إنشاء حساب لاحقاً من التطبيق.',
                                                      maxWidth: Get.width > 1200
                                                          ? 400.0
                                                          : (Get.width > 768
                                                                ? 350.0
                                                                : null),
                                                      margin: Get.width > 768
                                                          ? EdgeInsets.symmetric(
                                                              horizontal:
                                                                  Get.width > 1200
                                                                      ? (Get.width -
                                                                                400.0) /
                                                                            2
                                                                      : (Get.width -
                                                                                350.0) /
                                                                            2,
                                                              vertical: 16,
                                                            )
                                                          : EdgeInsets.all(16),
                                                      snackStyle: SnackStyle.FLOATING,
                                                      borderRadius: 12,
                                                      duration: Duration(seconds: 6),
                                                      backgroundColor: Colors.orange.shade100,
                                                      colorText: Colors.orange.shade900,
                                                    );
                                                    // Continue - create restaurant with email only
                                                    // finalOwnerId will remain empty
                                                  } else {
                                                    // For other errors, do NOT create the restaurant
                                                    controller.isLoading.value = false;
                                                    
                                                    // Show error message
                                                    Get.snackbar(
                                                      'خطأ',
                                                      'فشل في إنشاء حساب المالك.\n\n'
                                                      '${errorMsg.contains('Exception:') ? errorMsg.split('Exception:')[1].trim() : errorMsg}\n\n'
                                                      'لم يتم إنشاء المطعم. يرجى إصلاح المشكلة والمحاولة مرة أخرى.',
                                                      maxWidth: Get.width > 1200
                                                          ? 400.0
                                                          : (Get.width > 768
                                                                ? 350.0
                                                                : null),
                                                      margin: Get.width > 768
                                                          ? EdgeInsets.symmetric(
                                                              horizontal:
                                                                  Get.width > 1200
                                                                      ? (Get.width -
                                                                                400.0) /
                                                                            2
                                                                      : (Get.width -
                                                                                350.0) /
                                                                            2,
                                                              vertical: 16,
                                                            )
                                                          : EdgeInsets.all(16),
                                                      snackStyle: SnackStyle.FLOATING,
                                                      borderRadius: 12,
                                                      duration: Duration(seconds: 6),
                                                      backgroundColor: Colors.red.shade100,
                                                      colorText: Colors.red.shade900,
                                                    );
                                                    
                                                    // Stop restaurant creation
                                                    return;
                                                  }
                                                }
                                              }
                                            }
                                          } catch (e) {
                                            print(
                                              '[AdminRestaurantManagement] Error checking existing user: $e',
                                            );
                                            // Continue - try to create restaurant with email only
                                          }
                                        }

                                        // Upload logo if selected
                                        String? finalLogoUrl = logoUrl;
                                        if (selectedLogo != null &&
                                            selectedLogoBytes != null) {
                                          try {
                                            // For web, use bytes; for mobile, use file path
                                            if (kIsWeb) {
                                              // Web: upload bytes directly
                                              finalLogoUrl = await storageService
                                                  .uploadImageBytes(
                                                    bytes: selectedLogoBytes!,
                                                    pathPrefix:
                                                        'restaurants/$finalOwnerId/logos',
                                                  );
                                            } else {
                                              // Mobile: use file path
                                              final logoFile = File(
                                                selectedLogo!.path,
                                              );
                                              if (!await logoFile.exists()) {
                                                throw Exception(
                                                  'الملف المحدد غير موجود',
                                                );
                                              }

                                              finalLogoUrl = await storageService
                                                  .uploadImage(
                                                    file: logoFile,
                                                    pathPrefix:
                                                        'restaurants/$finalOwnerId/logos',
                                                  );
                                            }
                                          } catch (e) {
                                            Get.snackbar(
                                              'خطأ',
                                              'فشل رفع الشعار: ${e.toString().replaceAll('Exception: ', '')}',
                                              maxWidth: Get.width > 1200
                                                  ? 400.0
                                                  : (Get.width > 768
                                                        ? 350.0
                                                        : null),
                                              margin: Get.width > 768
                                                  ? EdgeInsets.symmetric(
                                                      horizontal:
                                                          Get.width > 1200
                                                          ? (Get.width -
                                                                    400.0) /
                                                                2
                                                          : (Get.width -
                                                                    350.0) /
                                                                2,
                                                      vertical: 16,
                                                    )
                                                  : EdgeInsets.all(16),
                                              snackStyle: SnackStyle.FLOATING,
                                              borderRadius: 12,
                                              duration: Duration(seconds: 4),
                                            );
                                            controller.isLoading.value = false;
                                            return;
                                          }
                                        }

                                        final success = await controller
                                            .createRestaurant(
                                              ownerId: finalOwnerId,
                                              ownerEmail: finalOwnerEmail,
                                              name: nameController.text,
                                              phone: phoneController.text,
                                              governorate: selectedGovernorate!,
                                              city: selectedCity!,
                                              description:
                                                  descriptionController.text,
                                              logoPath: finalLogoUrl,
                                              status: selectedStatus,
                                            );

                                        if (success) {
                                          controller.loadRestaurants();
                                          Get.back();
                                          Get.snackbar(
                                            'نجح',
                                            'تم إنشاء المطعم بنجاح',
                                            duration: const Duration(
                                              seconds: 3,
                                            ),
                                            maxWidth: Get.width > 1200
                                                ? 500.0
                                                : (Get.width > 768
                                                      ? 450.0
                                                      : null),
                                            margin: Get.width > 768
                                                ? EdgeInsets.symmetric(
                                                    horizontal: Get.width > 1200
                                                        ? (Get.width - 500.0) /
                                                              2
                                                        : (Get.width - 450.0) /
                                                              2,
                                                    vertical: 16,
                                                  )
                                                : EdgeInsets.all(16),
                                            snackStyle: SnackStyle.FLOATING,
                                            borderRadius: 12,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'خطأ',
                                            controller.errorMessage.value,
                                            maxWidth: Get.width > 1200
                                                ? 400.0
                                                : (Get.width > 768
                                                      ? 350.0
                                                      : null),
                                            margin: Get.width > 768
                                                ? EdgeInsets.symmetric(
                                                    horizontal: Get.width > 1200
                                                        ? (Get.width - 400.0) /
                                                              2
                                                        : (Get.width - 350.0) /
                                                              2,
                                                    vertical: 16,
                                                  )
                                                : EdgeInsets.all(16),
                                            snackStyle: SnackStyle.FLOATING,
                                            borderRadius: 12,
                                          );
                                        }
                                      } else {
                                        // Edit mode
                                        // Upload logo if selected
                                        String? finalLogoUrl = logoUrl;
                                        if (selectedLogo != null &&
                                            selectedLogoBytes != null) {
                                          try {
                                            final ownerId =
                                                restaurant['owner_id'] ?? '';
                                            // For web, use bytes; for mobile, use file path
                                            if (kIsWeb) {
                                              // Web: upload bytes directly
                                              finalLogoUrl = await storageService
                                                  .uploadImageBytes(
                                                    bytes: selectedLogoBytes!,
                                                    pathPrefix:
                                                        'restaurants/$ownerId/logos',
                                                  );
                                            } else {
                                              // Mobile: use file path
                                              final logoFile = File(
                                                selectedLogo!.path,
                                              );
                                              if (!await logoFile.exists()) {
                                                throw Exception(
                                                  'الملف المحدد غير موجود',
                                                );
                                              }

                                              finalLogoUrl = await storageService
                                                  .uploadImage(
                                                    file: logoFile,
                                                    pathPrefix:
                                                        'restaurants/$ownerId/logos',
                                                  );
                                            }
                                          } catch (e) {
                                            Get.snackbar(
                                              'خطأ',
                                              'فشل رفع الشعار: ${e.toString().replaceAll('Exception: ', '')}',
                                              maxWidth: Get.width > 1200
                                                  ? 400.0
                                                  : (Get.width > 768
                                                        ? 350.0
                                                        : null),
                                              margin: Get.width > 768
                                                  ? EdgeInsets.symmetric(
                                                      horizontal:
                                                          Get.width > 1200
                                                          ? (Get.width -
                                                                    400.0) /
                                                                2
                                                          : (Get.width -
                                                                    350.0) /
                                                                2,
                                                      vertical: 16,
                                                    )
                                                  : EdgeInsets.all(16),
                                              snackStyle: SnackStyle.FLOATING,
                                              borderRadius: 12,
                                              duration: Duration(seconds: 4),
                                            );
                                            controller.isLoading.value = false;
                                            return;
                                          }
                                        }

                                        final success = await controller
                                            .updateRestaurant(
                                              restaurantId: restaurant['id'],
                                              name: nameController.text,
                                              phone: phoneController.text,
                                              governorate: selectedGovernorate!,
                                              city: selectedCity!,
                                              description:
                                                  descriptionController.text,
                                              logoPath: finalLogoUrl,
                                              status: selectedStatus,
                                            );

                                        if (success) {
                                          Get.back();
                                          Get.snackbar(
                                            'نجح',
                                            'تم تحديث المطعم',
                                            maxWidth: Get.width > 1200
                                                ? 400.0
                                                : (Get.width > 768
                                                      ? 350.0
                                                      : null),
                                            margin: Get.width > 768
                                                ? EdgeInsets.symmetric(
                                                    horizontal: Get.width > 1200
                                                        ? (Get.width - 400.0) /
                                                              2
                                                        : (Get.width - 350.0) /
                                                              2,
                                                    vertical: 16,
                                                  )
                                                : EdgeInsets.all(16),
                                            snackStyle: SnackStyle.FLOATING,
                                            borderRadius: 12,
                                          );
                                        } else {
                                          Get.snackbar(
                                            'خطأ',
                                            controller.errorMessage.value,
                                            maxWidth: Get.width > 1200
                                                ? 400.0
                                                : (Get.width > 768
                                                      ? 350.0
                                                      : null),
                                            margin: Get.width > 768
                                                ? EdgeInsets.symmetric(
                                                    horizontal: Get.width > 1200
                                                        ? (Get.width - 400.0) /
                                                              2
                                                        : (Get.width - 350.0) /
                                                              2,
                                                    vertical: 16,
                                                  )
                                                : EdgeInsets.all(16),
                                            snackStyle: SnackStyle.FLOATING,
                                            borderRadius: 12,
                                          );
                                        }
                                      }

                                      // Reset loading state
                                      controller.isLoading.value = false;
                                    },
                              child: controller.isLoading.value
                                  ? SizedBox(
                                      width: isDesktop
                                          ? 20
                                          : (isTablet ? 18 : 16),
                                      height: isDesktop
                                          ? 20
                                          : (isTablet ? 18 : 16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              colorScheme.onPrimary,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      isEdit ? 'تحديث' : 'إضافة',
                                      style: TextStyle(
                                        fontSize: isDesktop
                                            ? 20
                                            : (isTablet ? 16 : 14),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    AdminRestaurantController controller,
    Map<String, dynamic> restaurant,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    Get.dialog(
      AlertDialog(
        title: Text(
          'حذف المطعم',
          style: TextStyle(fontSize: isDesktop ? 25 : (isTablet ? 18 : 16)),
        ),
        content: Text(
          'هل أنت متأكد من حذف "${restaurant['name']}"؟',
          style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 14 : 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'إلغاء',
              style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 14 : 12)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              final success = await controller.deleteRestaurant(
                restaurant['id'],
              );
              if (success) {
                Get.snackbar(
                  'نجح',
                  'تم حذف المطعم',
                  maxWidth: Get.width > 1200
                      ? 400.0
                      : (Get.width > 768 ? 350.0 : null),
                  margin: Get.width > 768
                      ? EdgeInsets.symmetric(
                          horizontal: Get.width > 1200
                              ? (Get.width - 400.0) / 2
                              : (Get.width - 350.0) / 2,
                          vertical: 16,
                        )
                      : EdgeInsets.all(16),
                  snackStyle: SnackStyle.FLOATING,
                  borderRadius: 12,
                );
              } else {
                Get.snackbar(
                  'خطأ',
                  controller.errorMessage.value,
                  maxWidth: Get.width > 1200
                      ? 400.0
                      : (Get.width > 768 ? 350.0 : null),
                  margin: Get.width > 768
                      ? EdgeInsets.symmetric(
                          horizontal: Get.width > 1200
                              ? (Get.width - 400.0) / 2
                              : (Get.width - 350.0) / 2,
                          vertical: 16,
                        )
                      : EdgeInsets.all(16),
                  snackStyle: SnackStyle.FLOATING,
                  borderRadius: 12,
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'حذف',
              style: TextStyle(fontSize: isDesktop ? 20 : (isTablet ? 14 : 12)),
            ),
          ),
        ],
      ),
    );
  }
}
