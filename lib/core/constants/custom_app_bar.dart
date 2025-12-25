import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom AppBar widget for restaurant management interface
/// Implements Contemporary Spatial Minimalism with touch-optimized controls
/// Supports multiple variants for different screen contexts
enum CustomAppBarVariant {
  /// Standard app bar with back button and title
  standard,

  /// App bar with search functionality
  search,

  /// App bar with action buttons (edit, delete, etc.)
  actions,

  /// App bar for modal screens with close button
  modal,

  /// App bar with category tabs
  tabbed,
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// The title text displayed in the app bar
  final String title;

  /// The variant of the app bar
  final CustomAppBarVariant variant;

  /// Whether to show the back button (default: true for standard variant)
  final bool showBackButton;

  /// Custom leading widget (overrides back button)
  final Widget? leading;

  /// List of action widgets displayed on the right
  final List<Widget>? actions;

  /// Callback when search text changes (for search variant)
  final ValueChanged<String>? onSearchChanged;

  /// Search hint text (for search variant)
  final String searchHint;

  /// Tab controller for tabbed variant
  final TabController? tabController;

  /// List of tab labels for tabbed variant
  final List<String>? tabs;

  /// Background color (defaults to theme surface color)
  final Color? backgroundColor;

  /// Whether the app bar is elevated (shows shadow)
  final bool elevated;

  /// Custom elevation value
  final double? elevation;

  /// Callback when back/close button is pressed
  final VoidCallback? onBackPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.variant = CustomAppBarVariant.standard,
    this.showBackButton = true,
    this.leading,
    this.actions,
    this.onSearchChanged,
    this.searchHint = 'Search menu items...',
    this.tabController,
    this.tabs,
    this.backgroundColor,
    this.elevated = true,
    this.elevation,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine background color
    final bgColor = backgroundColor ?? colorScheme.surface;

    // Determine elevation
    final appBarElevation = elevation ?? (elevated ? 1.0 : 0.0);

    return AppBar(
      backgroundColor: bgColor,
      elevation: appBarElevation,
      scrolledUnderElevation: elevated ? 2.0 : 0.0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      leading: _buildLeading(context),
      title: _buildTitle(context),
      actions: _buildActions(context),
      bottom: variant == CustomAppBarVariant.tabbed
          ? _buildTabBar(context)
          : null,
      centerTitle: false,
      titleSpacing: leading == null && !showBackButton ? 16.0 : 0.0,
    );
  }

  /// Build leading widget based on variant
  Widget? _buildLeading(BuildContext context) {
    if (leading != null) return leading;

    if (!showBackButton && variant != CustomAppBarVariant.modal) {
      return null;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Modal variant uses close icon
    if (variant == CustomAppBarVariant.modal) {
      return IconButton(
        icon: const Icon(Icons.close_rounded),
        iconSize: 24,
        color: colorScheme.onSurface,
        tooltip: 'Close',
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      );
    }

    // Standard back button
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      iconSize: 24,
      color: colorScheme.onSurface,
      tooltip: 'Back',
      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
    );
  }

  /// Build title widget based on variant
  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Search variant shows search field
    if (variant == CustomAppBarVariant.search) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: TextField(
          onChanged: onSearchChanged,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: searchHint,
            hintStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
              size: 20,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      );
    }

    // Standard title text
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        letterSpacing: 0.15,
      ),
    );
  }

  /// Build actions based on variant and provided actions
  List<Widget>? _buildActions(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Return provided actions if any
    if (actions != null && actions!.isNotEmpty) {
      return actions;
    }

    // Actions variant shows common action buttons
    if (variant == CustomAppBarVariant.actions) {
      return [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          iconSize: 22,
          color: colorScheme.onSurface,
          tooltip: 'Edit',
          onPressed: () {
            // Action handled by parent
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert_rounded),
          iconSize: 22,
          color: colorScheme.onSurface,
          tooltip: 'More options',
          onPressed: () {
            // Show menu
          },
        ),
        const SizedBox(width: 4),
      ];
    }

    // Search variant shows filter button
    if (variant == CustomAppBarVariant.search) {
      return [
        IconButton(
          icon: const Icon(Icons.tune_rounded),
          iconSize: 22,
          color: colorScheme.onSurface,
          tooltip: 'Filter',
          onPressed: () {
            // Show filter options
          },
        ),
        const SizedBox(width: 4),
      ];
    }

    return null;
  }

  /// Build tab bar for tabbed variant
  PreferredSizeWidget? _buildTabBar(BuildContext context) {
    if (tabs == null || tabs!.isEmpty || tabController == null) {
      return null;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TabBar(
      controller: tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: colorScheme.primary,
      indicatorWeight: 3.0,
      indicatorSize: TabBarIndicatorSize.label,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      tabs: tabs!.map((label) => Tab(text: label, height: 48)).toList(),
    );
  }

  @override
  Size get preferredSize {
    double height = kToolbarHeight;

    // Add tab bar height if tabbed variant
    if (variant == CustomAppBarVariant.tabbed &&
        tabs != null &&
        tabs!.isNotEmpty) {
      height += 48.0; // Tab bar height
    }

    return Size.fromHeight(height);
  }
}
