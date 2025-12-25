import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/core/constants/customButton.dart';
import 'package:mata3mna/core/databases/cache/cache_helper.dart';
import 'package:mata3mna/core/services/supabase_storage_service.dart';
import 'package:mata3mna/features/restaurant_info/data/services/restaurant_firestore_service.dart';
import 'package:mata3mna/features/dashboard/data/services/location_firestore_service.dart';
import 'package:sizer/sizer.dart';

class RestaurantInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? itemData;

  const RestaurantInfoScreen({super.key, this.itemData});

  @override
  State<RestaurantInfoScreen> createState() => _RestaurantInfoScreenState();
}

class _RestaurantInfoScreenState extends State<RestaurantInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final RestaurantFirestoreService _restaurantService =
      Get.find<RestaurantFirestoreService>();
  final SupabaseStorageService _storageService =
      Get.find<SupabaseStorageService>();
  final CacheHelper _cacheHelper = Get.find<CacheHelper>();
  final LocationFirestoreService _locationService =
      Get.find<LocationFirestoreService>();

  // Check if in edit mode - either from widget.itemData or from Get.arguments
  bool get _isEditMode {
    if (widget.itemData != null) return true;
    final args = Get.arguments;
    return args != null && args is Map<String, dynamic>;
  }

  Map<String, dynamic>? get _restaurantData {
    if (widget.itemData != null) return widget.itemData;
    final args = Get.arguments;
    if (args != null && args is Map<String, dynamic>) {
      return args;
    }
    return null;
  }

  String? _selectedGovernorate;
  String? _selectedCity;
  XFile? _logoFile;
  String? _existingLogoUrl;
  bool _isSubmitting = false;
  bool _isLoading = false;
  bool _isLoadingLocations = false;

  List<String> _governorates = [];
  Map<String, List<String>> _citiesByGovernorate = {};

  @override
  void initState() {
    super.initState();

    // Prevent admins from accessing this page
    final userRole = _cacheHelper.getData(key: 'userRole') as String?;
    if (userRole == 'admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Get.offAllNamed('/dashboard');
      });
      return;
    }

    _loadLocations();
    if (_isEditMode) {
      _loadRestaurantInfo();
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoadingLocations = true);
    try {
      // Load governorates
      _governorates = await _locationService.getGovernorates();

      // If no governorates exist, initialize default locations
      if (_governorates.isEmpty) {
        await _locationService.initializeDefaultLocations();
        _governorates = await _locationService.getGovernorates();
      }

      // Load cities grouped by governorate
      _citiesByGovernorate = await _locationService.getCitiesByGovernorateMap();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      // ignore: avoid_print
      print('[RestaurantInfoScreen] Error loading locations: $e');
      // Fallback to empty lists if loading fails
      _governorates = [];
      _citiesByGovernorate = {};
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocations = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadRestaurantInfo() async {
    setState(() => _isLoading = true);
    try {
      // First try to use data passed as argument
      Map<String, dynamic>? restaurantInfo = _restaurantData;

      // If not provided, load from Firestore
      if (restaurantInfo == null) {
        final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
        final ownerEmail = _cacheHelper.getData(key: 'userEmail') as String?;
        if (ownerId == null || ownerId.isEmpty) {
          print('[RestaurantInfoScreen] No ownerId found');
          return;
        }
        print(
          '[RestaurantInfoScreen] Loading restaurant info for ownerId: $ownerId, email: $ownerEmail',
        );
        restaurantInfo = await _restaurantService.getRestaurantInfoByOwnerId(
          ownerId,
          ownerEmail: ownerEmail,
        );
        print('[RestaurantInfoScreen] Loaded restaurant info: $restaurantInfo');
      } else {
        print(
          '[RestaurantInfoScreen] Using restaurant data from arguments: $restaurantInfo',
        );
      }

      if (restaurantInfo != null && mounted) {
        _nameController.text = restaurantInfo['name'] as String? ?? '';
        _phoneController.text = restaurantInfo['phone'] as String? ?? '';
        _descriptionController.text =
            restaurantInfo['description'] as String? ?? '';
        _selectedGovernorate = restaurantInfo['governorate'] as String?;
        _selectedCity = restaurantInfo['city'] as String?;
        _existingLogoUrl = restaurantInfo['logoPath'] as String?;

        setState(() {});
      }
    } catch (e) {
      // ignore: avoid_print
      print('[RestaurantInfoScreen] Error loading restaurant info: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditMode ? 'تعديل معلومات المطعم' : 'إتمام معلومات المطعم',
            style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          centerTitle: true,
          backgroundColor: colorScheme.primary,
        ),
        body: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(5.w),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'يرجى إكمال بيانات مطعمك للمتابعة',
                          style: theme.textTheme.titleMedium,
                        ),
                        SizedBox(height: 2.h),
                        _buildTextField(
                          controller: _nameController,
                          label: 'اسم المطعم',
                          hint: 'أدخل اسم المطعم',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'اسم المطعم مطلوب';
                            }
                            return null;
                          },
                          icon: Icons.storefront,
                        ),
                        SizedBox(height: 2.h),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'رقم الهاتف',
                          hint: '05xxxxxxxx',
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'رقم الهاتف مطلوب';
                            }
                            if (value.length < 8) {
                              return 'يرجى إدخال رقم صحيح';
                            }
                            return null;
                          },
                          icon: Icons.phone,
                        ),
                        SizedBox(height: 2.h),
                        _buildGovernorateDropdown(colorScheme),
                        SizedBox(height: 2.h),
                        _buildCityDropdown(colorScheme),
                        SizedBox(height: 2.h),
                        _buildDescriptionField(colorScheme),
                        SizedBox(height: 2.h),
                        _buildLogoPicker(colorScheme),
                        SizedBox(height: 4.h),
                        SizedBox(
                          width: double.infinity,
                          child: CustomButton(
                            theme: theme,
                            onPressed: _isSubmitting ? () {} : _handleSubmit,
                            label: _isSubmitting
                                ? 'جاري الحفظ...'
                                : (_isEditMode ? 'حفظ التعديل' : 'حفظ ومتابعة'),
                            color: colorScheme.primary,
                            txtColor: Colors.white,
                            icon: null,
                            isLoading: _isSubmitting,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildGovernorateDropdown(ColorScheme colorScheme) {
    if (_isLoadingLocations) {
      return DropdownButtonFormField<String>(
        decoration: const InputDecoration(
          labelText: 'المحافظة',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        items: [],
        hint: const Text('جاري التحميل...'),
        onChanged: (_) {},
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedGovernorate,
      decoration: InputDecoration(
        labelText: 'المحافظة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _governorates
          .map((gov) => DropdownMenuItem(value: gov, child: Text(gov)))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedGovernorate = value;
          _selectedCity = null;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى اختيار المحافظة';
        }
        return null;
      },
    );
  }

  Widget _buildCityDropdown(ColorScheme colorScheme) {
    final cities = _selectedGovernorate != null
        ? _citiesByGovernorate[_selectedGovernorate] ?? []
        : <String>[];

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
      value: _selectedCity,
      decoration: InputDecoration(
        labelText: 'المدينة / المنطقة',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: uniqueCities
          .map((city) => DropdownMenuItem(value: city, child: Text(city)))
          .toList(),
      onChanged: (value) {
        setState(() {
          _selectedCity = value;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'يرجى اختيار المدينة';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField(ColorScheme colorScheme) {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      decoration: InputDecoration(
        labelText: 'وصف المطعم (اختياري)',
        hintText: 'أضف وصفاً مختصراً عن المطعم والخدمات المقدمة',
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLogoPicker(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'شعار المطعم (اختياري)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 1.h),
        Row(
          children: [
            Expanded(
              child: CustomButton(
                theme: Theme.of(context),
                isOutline: true,
                onPressed: _isSubmitting ? () {} : _pickLogo,
                label: _logoFile != null || _existingLogoUrl != null
                    ? 'تغيير الشعار'
                    : 'تحميل الشعار',
                color: colorScheme.primary,
                txtColor: colorScheme.primary,
                icon: Icon(Icons.upload, color: colorScheme.primary),
              ),
            ),
            SizedBox(width: 3.w),
            if (_logoFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_logoFile!.path),
                  width: 18.w,
                  height: 18.w,
                  fit: BoxFit.cover,
                ),
              )
            else if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: _existingLogoUrl!,
                  width: 18.w,
                  height: 18.w,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 18.w,
                    height: 18.w,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    return Container(
                      width: 18.w,
                      height: 18.w,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.image_not_supported,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickLogo() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _logoFile = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    if (_isEditMode && widget.itemData != null) {}
    try {
      final ownerId = _cacheHelper.getData(key: 'userUid') as String?;
      if (ownerId == null || ownerId.isEmpty) {
        throw Exception('لا يمكن العثور على معرف المالك');
      }

      final ownerEmail =
          _cacheHelper.getData(key: 'userEmail') as String? ?? '';
      if (ownerEmail.isEmpty) {
        throw Exception('لا يمكن العثور على بريد المالك');
      }

      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final description = _descriptionController.text.trim();
      final governorate = _selectedGovernorate!;
      final city = _selectedCity!;
      String? logoUrl;

      if (_logoFile != null) {
        // Using menu_items path as it has proper RLS policies configured
        // TODO: Add RLS policy for restaurant_logos path in Supabase
        logoUrl = await _storageService.uploadImage(
          file: File(_logoFile!.path),
          pathPrefix: 'menu_items/$ownerId/logos',
        );
      } else if (_existingLogoUrl != null && _existingLogoUrl!.isNotEmpty) {
        // Keep existing logo if no new one is uploaded
        logoUrl = _existingLogoUrl;
      }

      await _restaurantService.saveRestaurantInfo(
        ownerId: ownerId,
        ownerEmail: ownerEmail,
        name: name,
        phone: phone,
        governorate: governorate,
        city: city,
        infoCompleted: true,
        description: description,
        logoPath: logoUrl,
      );

      await _cacheHelper.saveData(key: 'restaurantName', value: name);
      await _cacheHelper.saveData(key: 'restaurantInfoCompleted', value: true);

      Get.snackbar(
        'تم الحفظ',
        'تم حفظ معلومات المطعم بنجاح',
        snackPosition: SnackPosition.BOTTOM,
      );

      Get.offAllNamed(AppPages.home);
    } catch (e) {
      // ignore: avoid_print
      print('[RestaurantInfoScreen] Failed to save info: $e');

      String errorMessage = 'فشل حفظ معلومات المطعم';
      final errorStr = e.toString();

      if (errorStr.contains('unavailable') ||
          errorStr.contains('UNAUTHENTICATED')) {
        errorMessage =
            'خطأ في الاتصال بخدمة Firebase.\n'
            'يرجى:\n'
            '1. التحقق من اتصال الإنترنت\n'
            '2. التأكد من تفعيل Identity Toolkit API في Google Cloud Console\n'
            '3. المحاولة مرة أخرى';
      } else if (errorStr.contains('permission') ||
          errorStr.contains('PERMISSION_DENIED')) {
        errorMessage =
            'ليس لديك صلاحية لحفظ معلومات المطعم.\n'
            'يرجى التحقق من إعدادات Firebase Security Rules';
      } else {
        errorMessage = 'فشل حفظ معلومات المطعم: $e';
      }

      Get.snackbar(
        'خطأ',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
