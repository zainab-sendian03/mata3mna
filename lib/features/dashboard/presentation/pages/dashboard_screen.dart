import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/config/themes/app_icon.dart';
import 'package:mata3mna/features/auth/presentation/controllers/auth_controller.dart';
import 'package:mata3mna/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:mata3mna/features/dashboard/presentation/widgets/stat_card.dart';
import 'package:mata3mna/features/dashboard/presentation/widgets/category_distribution_chart.dart';
import 'package:mata3mna/features/dashboard/presentation/widgets/popular_items_list.dart';
import 'package:mata3mna/features/dashboard/presentation/widgets/recent_restaurants_list.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/admin_restaurant_management_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/admin_item_management_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/admin_category_management_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/location_management_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Dashboard screen showing restaurant statistics and analytics
/// Modern web-like design with responsive layout for mobile and desktop
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum DashboardPage {
  dashboard,
  restaurants,
  items,
  categories,
  locations,
  settings,
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  bool _sidebarExpanded = true;
  DashboardPage _selectedPage = DashboardPage.dashboard;

  // Animation controllers for expandable sections
  late AnimationController _categoryDistributionController;
  late AnimationController _popularItemsController;

  // Expanded states
  bool _categoryDistributionExpanded = true;
  bool _popularItemsExpanded = true;

  bool get _isWeb => kIsWeb;

  @override
  void initState() {
    super.initState();
    // Initialize animation controllers
    _categoryDistributionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _popularItemsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Start with expanded state
    _categoryDistributionController.forward();
    _popularItemsController.forward();
  }

  @override
  void dispose() {
    _categoryDistributionController.dispose();
    _popularItemsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final authController = Get.find<AuthController>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive breakpoints
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;
    final isMobile = screenWidth <= 768;
    // Show sidebar only on desktop/tablet web (not on mobile - mobile uses drawer)
    final showSidebar = (isDesktop || isTablet) && _isWeb;

    return Scaffold(
      drawer: isMobile
          ? SafeArea(
              child: _buildSidebar(
                context,
                authController,
                theme,
                colorScheme,
                false, // false يعني width صغير أو drawer
                false, // showSidebar = false for mobile drawer
              ),
            )
          : null,
      backgroundColor: colorScheme.surfaceContainerLowest,
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          );
        }

        if (controller.errorMessage.value.isNotEmpty) {
          return SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomIconWidget(
                    iconName: 'error_outline',
                    color: colorScheme.error,
                    size: isDesktop ? 64.0 : (isTablet ? 56.0 : 48.0),
                  ),
                  SizedBox(height: 16),
                  Text(
                    controller.errorMessage.value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => controller.refresh(),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Row(
            children: [
              // Sidebar for desktop/tablet only (mobile uses drawer)
              if (showSidebar)
                _buildSidebar(
                  context,
                  authController,
                  theme,
                  colorScheme,
                  isDesktop,
                  showSidebar,
                ),

              // Main content area
              Expanded(
                child: Column(
                  children: [
                    // Top App Bar (only show for dashboard page or when sidebar is shown)
                    if (showSidebar || isMobile)
                      _buildAppBar(
                        context,
                        controller,
                        theme,
                        colorScheme,
                        isDesktop,
                        isTablet,
                        isMobile,
                        showSidebar,
                      ),

                    // Main content
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => controller.refresh(),
                        child: _buildContent(
                          context,
                          controller,
                          theme,
                          colorScheme,
                          isDesktop,
                          isTablet,
                          isMobile,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    AuthController authController,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool showSidebar,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 768;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    // Responsive calculations based on screen width
    final sidebarWidth = _sidebarExpanded
        ? (isMobile
              ? 260.0
              : (isTablet
                    ? 220.0
                    : (280.0 * (screenWidth / 1920)).clamp(240.0, 280.0)))
        : (isMobile ? 0.0 : 80.0);

    // Responsive font size: scales from 12px at 1200px to 18px at 1920px+
    final headerFontSize = isMobile
        ? 18.0
        : (isTablet
              ? 16.0
              : (14.0 + (screenWidth - 1200) / 80).clamp(14.0, 20.0));
    final iconSize = isMobile
        ? 24.0
        : (isTablet
              ? 22.0
              : (20.0 + (screenWidth - 1200) / 60).clamp(20.0, 32.0));
    final padding = isMobile
        ? 12.0
        : (isTablet
              ? 14.0
              : (12.0 + (screenWidth - 1200) / 100).clamp(12.0, 24.0));

    // On mobile, if sidebar is collapsed, don't show it
    if (isMobile && !_sidebarExpanded) {
      return const SizedBox.shrink();
    }

    return Container(
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo/Header
          Container(
            padding: EdgeInsets.all(
              _sidebarExpanded ? padding : (isDesktop ? 8.0 : 4.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.dashboard,
                  color: colorScheme.primary,
                  size: iconSize,
                ),
                SizedBox(width: padding * 0.3),
                Expanded(
                  child: Text(
                    'لوحة التحكم',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: headerFontSize,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Show toggle button on desktop or mobile
                if (isDesktop || isMobile)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(
                      _sidebarExpanded
                          ? Icons.chevron_right
                          : Icons.chevron_left,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _sidebarExpanded = !_sidebarExpanded;
                      });
                    },
                  ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withOpacity(0.2)),

          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSidebarItem(
                  context,
                  Icons.dashboard,
                  'لوحة التحكم',
                  () {
                    setState(() {
                      _selectedPage = DashboardPage.dashboard;
                    });
                    if (!showSidebar) {
                      Navigator.of(context).pop(); // Close drawer on mobile
                    }
                  },
                  _selectedPage == DashboardPage.dashboard,
                  theme,
                  colorScheme,
                  isDesktop,
                  screenWidth,
                ),
                _buildSidebarItem(
                  context,
                  Icons.restaurant,
                  'إدارة المطاعم',
                  () {
                    setState(() {
                      _selectedPage = DashboardPage.restaurants;
                    });
                    if (!showSidebar) {
                      Navigator.of(context).pop(); // Close drawer on mobile
                    }
                  },
                  _selectedPage == DashboardPage.restaurants,
                  theme,
                  colorScheme,
                  isDesktop,
                  screenWidth,
                ),
                _buildSidebarItem(
                  context,
                  Icons.restaurant_menu,
                  'إدارة العناصر',
                  () {
                    setState(() {
                      _selectedPage = DashboardPage.items;
                    });
                    if (!showSidebar) {
                      Navigator.of(context).pop(); // Close drawer on mobile
                    }
                  },
                  _selectedPage == DashboardPage.items,
                  theme,
                  colorScheme,
                  isDesktop,
                  screenWidth,
                ),
                // _buildSidebarItem(
                //   context,
                //   Icons.category,
                //   'إدارة الفئات',
                //   () {
                //     setState(() {
                //       _selectedPage = DashboardPage.categories;
                //     });
                //     if (!showSidebar) {
                //       Navigator.of(context).pop(); // Close drawer on mobile
                //     }
                //   },
                //   _selectedPage == DashboardPage.categories,
                //   theme,
                //   colorScheme,
                //   isDesktop,
                // ),
                _buildSidebarItem(
                  context,
                  Icons.location_on,
                  'إدارة المناطق',
                  () {
                    setState(() {
                      _selectedPage = DashboardPage.locations;
                    });
                    if (!showSidebar) {
                      Navigator.of(context).pop(); // Close drawer on mobile
                    }
                  },
                  _selectedPage == DashboardPage.locations,
                  theme,
                  colorScheme,
                  isDesktop,
                  screenWidth,
                ),
                // _buildSidebarItem(
                //   context,
                //   Icons.settings,
                //   'الإعدادات',
                //   () {
                //     setState(() {
                //       _selectedPage = DashboardPage.settings;
                //     });
                //     if (!showSidebar) {
                //       Navigator.of(context).pop(); // Close drawer on mobile
                //     }
                //   },
                //   _selectedPage == DashboardPage.settings,
                //   theme,
                //   colorScheme,
                //   isDesktop,
                //   screenWidth,
                // ),
              ],
            ),
          ),

          Divider(height: 1, color: colorScheme.outline.withOpacity(0.2)),

          // User section
          Container(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                if (_sidebarExpanded) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: (16.0 + (screenWidth - 1200) / 100).clamp(
                          16.0,
                          20.0,
                        ),
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.person,
                          size: (16.0 + (screenWidth - 1200) / 100).clamp(
                            16.0,
                            20.0,
                          ),
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      SizedBox(width: padding * 0.6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'المسؤول',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: (14.0 + (screenWidth - 1200) / 80)
                                    .clamp(14.0, 20.0),
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              'Admin',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: (12.0 + (screenWidth - 1200) / 100)
                                    .clamp(12.0, 20.0),
                                color: colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: padding * 0.8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final shouldLogout = await Get.dialog<bool>(
                        AlertDialog(
                          title: Text(
                            'تسجيل الخروج',
                            style: TextStyle(
                              fontSize: isDesktop ? 20 : (isTablet ? 18 : 16),
                            ),
                          ),
                          content: Text(
                            'هل أنت متأكد من تسجيل الخروج؟',
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : (isTablet ? 15 : 14),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(result: false),
                              child: Text(
                                'إلغاء',
                                style: TextStyle(
                                  fontSize: isDesktop
                                      ? 16
                                      : (isTablet ? 15 : 14),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Get.back(result: true),
                              child: Text(
                                'تسجيل الخروج',
                                style: TextStyle(
                                  fontSize: isDesktop
                                      ? 16
                                      : (isTablet ? 15 : 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (shouldLogout == true) {
                        await authController.signOut();
                        Get.offAllNamed(AppPages.adminLogin);
                      }
                    },
                    icon: Icon(
                      Icons.logout,
                      size: (16.0 + (screenWidth - 1200) / 120).clamp(
                        16.0,
                        18.0,
                      ),
                    ),
                    label: _sidebarExpanded
                        ? Text(
                            'تسجيل الخروج',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: (13.0 + (screenWidth - 1200) / 100)
                                  .clamp(13.0, 20.0),
                              color: colorScheme.primary,
                            ),
                          )
                        : const SizedBox(),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: (8.0 + (screenWidth - 1200) / 100).clamp(
                          8.0,
                          16.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
    bool isActive,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    double screenWidth,
  ) {
    // Calculate breakpoints from screen width
    final isMobile = screenWidth <= 768;
    final isTablet = screenWidth > 768 && screenWidth <= 1200;

    // Responsive calculations
    final itemIconSize = isMobile
        ? 24.0
        : (isTablet
              ? 22.0
              : (20.0 + (screenWidth - 1200) / 60).clamp(20.0, 24.0));
    final itemFontSize = isMobile
        ? 14.0
        : (isTablet
              ? 13.0
              : (12.0 + (screenWidth - 1200) / 100).clamp(12.0, 16.0));
    final itemPadding = isMobile
        ? 8.0
        : (isTablet
              ? 10.0
              : (8.0 + (screenWidth - 1200) / 100).clamp(8.0, 16.0));
    final itemMargin = isMobile
        ? 8.0
        : (isTablet
              ? 12.0
              : (12.0 + (screenWidth - 1200) / 120).clamp(12.0, 16.0));

    if (!_sidebarExpanded) {
      return Tooltip(
        message: label,
        textStyle: TextStyle(
          fontSize: (11.0 + (screenWidth - 1200) / 150).clamp(11.0, 13.0),
          color: Colors.white,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: (8.0 + (screenWidth - 1200) / 200).clamp(8.0, 12.0),
          vertical: (4.0 + (screenWidth - 1200) / 300).clamp(4.0, 6.0),
        ),
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: itemMargin, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(
              icon,
              size: itemIconSize,
              color: isActive
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface.withOpacity(0.7),
            ),
            onPressed: onTap,
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: screenWidth < 1400,
        contentPadding: EdgeInsets.symmetric(
          horizontal: itemPadding,
          vertical: screenWidth < 1400 ? 4 : 8,
        ),
        leading: Icon(
          icon,
          size: itemIconSize,
          color: isActive
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface.withOpacity(0.7),
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: itemFontSize,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildAppBar(
    BuildContext context,
    DashboardController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
    bool showSidebar,
  ) {
    return isMobile
        ? Row(
            children: [
              // Menu button for mobile drawer
              if (isMobile)
                Builder(
                  builder: (context) {
                    return IconButton(
                      icon: Icon(_sidebarExpanded ? Icons.close : Icons.menu),
                      onPressed: () {
                        // Always open drawer on mobile
                        Scaffold.of(context).openDrawer();
                      },
                    );
                  },
                ),
            ],
          )
        : SizedBox.shrink();
  }

  Widget _buildContent(
    BuildContext context,
    DashboardController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    // Show different content based on selected page
    switch (_selectedPage) {
      case DashboardPage.dashboard:
        return SingleChildScrollView(
          padding: EdgeInsets.all(
            isDesktop
                ? 50
                : isTablet
                ? 24
                : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1400 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  if (isDesktop || isTablet)
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.primaryContainer.withOpacity(0.7),
                          ],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.dashboard_customize,
                            size: 48,
                            color: colorScheme.onPrimaryContainer,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'مرحباً بك في لوحة التحكم',
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onPrimaryContainer,
                                      ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'إدارة شاملة لجميع المطاعم والعناصر',
                                  style: isDesktop
                                      ? theme.textTheme.displaySmall?.copyWith(
                                          color: colorScheme.onPrimaryContainer
                                              .withOpacity(0.8),
                                        )
                                      : theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onPrimaryContainer
                                              .withOpacity(0.8),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isDesktop || isTablet) SizedBox(height: 24),

                  // Statistics Cards Grid
                  _buildStatsGrid(
                    context,
                    controller,
                    theme,
                    colorScheme,
                    isDesktop,
                    isTablet,
                    isMobile,
                  ),

                  SizedBox(height: isDesktop ? 32 : 24),

                  // Main Content Grid
                  _buildMainContent(
                    context,
                    controller,
                    theme,
                    colorScheme,
                    isDesktop,
                    isTablet,
                    isMobile,
                  ),
                ],
              ),
            ),
          ),
        );

      case DashboardPage.restaurants:
        return const AdminRestaurantManagementScreen(hideAppBar: true);

      case DashboardPage.items:
        return const AdminItemManagementScreen();

      case DashboardPage.categories:
        return const AdminCategoryManagementScreen(hideAppBar: true);

      case DashboardPage.locations:
        return const LocationManagementScreen(hideAppBar: true);

      case DashboardPage.settings:
        return Center(
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 50 : 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings,
                  size: isDesktop ? 64 : 48,
                  color: colorScheme.onSurface.withOpacity(0.5),
                ),
                // SizedBox(height: 16),
                // Text(
                //   'الإعدادات',
                //   style: theme.textTheme.headlineMedium?.copyWith(
                //     color: colorScheme.onSurface.withOpacity(0.7),
                //   ),
                // ),
                SizedBox(height: 8),
                Text(
                  'قريباً...',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildStatsGrid(
    BuildContext context,
    DashboardController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    final crossAxisCount = isDesktop ? 4 : (isTablet ? 2 : 2);
    final childAspectRatio = isDesktop ? 1.7 : (isTablet ? 2.0 : 1.3);
    final spacing = isDesktop ? 20.0 : (isTablet ? 16.0 : 12.0);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: spacing,
      mainAxisSpacing: spacing,
      childAspectRatio: childAspectRatio,
      children: [
        StatCard(
          title: 'إجمالي المطاعم',
          value: controller.totalRestaurants.value.toString(),
          icon: Icons.restaurant,
          color: colorScheme.primary,
        ),
        StatCard(
          title: 'إجمالي العناصر',
          value: controller.totalMenuItems.value.toString(),
          icon: Icons.restaurant_menu,
          color: colorScheme.secondary,
        ),
        StatCard(
          title: 'إجمالي الفئات',
          value: controller.totalCategories.value.toString(),
          icon: Icons.category,
          color: colorScheme.tertiary,
        ),
        StatCard(
          title: 'إجمالي المستخدمين',
          value: controller.totalUsers.value.toString(),
          icon: Icons.people,
          color: colorScheme.error,
        ),
      ],
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    DashboardController controller,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDesktop,
    bool isTablet,
    bool isMobile,
  ) {
    if (isMobile) {
      return _buildMobileContent(controller, theme, colorScheme);
    }

    // Desktop/Tablet Layout
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Main Content)
        Expanded(
          flex: isDesktop ? 2 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Distribution
              if (controller.itemsByCategory.isNotEmpty) ...[
                _buildSectionHeader(
                  'توزيع العناصر حسب الفئة',
                  Icons.pie_chart,
                  theme,
                  colorScheme,
                  onTap: () {
                    setState(() {
                      _categoryDistributionExpanded =
                          !_categoryDistributionExpanded;
                      if (_categoryDistributionExpanded) {
                        _categoryDistributionController.forward();
                      } else {
                        _categoryDistributionController.reverse();
                      }
                    });
                  },
                  isExpanded: _categoryDistributionExpanded,
                ),
                SizeTransition(
                  sizeFactor: _categoryDistributionController,
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 24 : 20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CategoryDistributionChart(
                          distribution: controller.itemsByCategory,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
              ],

              // Popular Items
              if (controller.popularItems.isNotEmpty) ...[
                _buildSectionHeader(
                  'العناصر الشائعة',
                  Icons.trending_up,
                  theme,
                  colorScheme,
                  onTap: () {
                    setState(() {
                      _popularItemsExpanded = !_popularItemsExpanded;
                      if (_popularItemsExpanded) {
                        _popularItemsController.forward();
                      } else {
                        _popularItemsController.reverse();
                      }
                    });
                  },
                  isExpanded: _popularItemsExpanded,
                ),
                SizeTransition(
                  sizeFactor: _popularItemsController,
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(isDesktop ? 24 : 20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: PopularItemsList(items: controller.popularItems),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
              ],

              // Recent Items
              if (controller.recentItems.isNotEmpty) ...[
                _buildSectionHeader(
                  'العناصر المضافة مؤخراً',
                  Icons.access_time,
                  theme,
                  colorScheme,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(isDesktop ? 24 : 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: PopularItemsList(items: controller.recentItems),
                ),
              ],
            ],
          ),
        ),

        SizedBox(width: isDesktop ? 24 : 16),

        // Right Column (Sidebar Content)
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Recent Restaurants
              if (controller.recentRestaurants.isNotEmpty) ...[
                _buildSectionHeader(
                  'المطاعم المضافة مؤخراً',
                  Icons.store,
                  theme,
                  colorScheme,
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(isDesktop ? 24 : 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: RecentRestaurantsList(
                    restaurants: controller.recentRestaurants,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent(
    DashboardController controller,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Distribution
        if (controller.itemsByCategory.isNotEmpty) ...[
          _buildSectionHeader(
            'توزيع العناصر حسب الفئة',
            Icons.pie_chart,
            theme,
            colorScheme,
            onTap: () {
              setState(() {
                _categoryDistributionExpanded = !_categoryDistributionExpanded;
                if (_categoryDistributionExpanded) {
                  _categoryDistributionController.forward();
                } else {
                  _categoryDistributionController.reverse();
                }
              });
            },
            isExpanded: _categoryDistributionExpanded,
          ),
          SizeTransition(
            sizeFactor: _categoryDistributionController,
            child: Column(
              children: [
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: CategoryDistributionChart(
                    distribution: controller.itemsByCategory,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],

        // Popular Items
        if (controller.popularItems.isNotEmpty) ...[
          _buildSectionHeader(
            'العناصر الشائعة',
            Icons.trending_up,
            theme,
            colorScheme,
            onTap: () {
              setState(() {
                _popularItemsExpanded = !_popularItemsExpanded;
                if (_popularItemsExpanded) {
                  _popularItemsController.forward();
                } else {
                  _popularItemsController.reverse();
                }
              });
            },
            isExpanded: _popularItemsExpanded,
          ),
          SizeTransition(
            sizeFactor: _popularItemsController,
            child: Column(
              children: [
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: PopularItemsList(items: controller.popularItems),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
        ],

        // Recent Items
        if (controller.recentItems.isNotEmpty) ...[
          _buildSectionHeader(
            'العناصر المضافة مؤخراً',
            Icons.access_time,
            theme,
            colorScheme,
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: PopularItemsList(items: controller.recentItems),
          ),
          SizedBox(height: 24),
        ],

        // Recent Restaurants
        if (controller.recentRestaurants.isNotEmpty) ...[
          _buildSectionHeader(
            'المطاعم المضافة مؤخراً',
            Icons.store,
            theme,
            colorScheme,
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: RecentRestaurantsList(
              restaurants: controller.recentRestaurants,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    ThemeData theme,
    ColorScheme colorScheme, {
    VoidCallback? onTap,
    bool? isExpanded,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            if (onTap != null && isExpanded != null)
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.expand_more,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
