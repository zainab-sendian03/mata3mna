import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom BottomNavigationBar widget for restaurant owner navigation
/// Implements bottom-heavy action placement for one-handed operation
/// Supports haptic feedback and platform-adaptive styling
enum CustomBottomBarVariant {
  /// Standard bottom navigation with icons and labels
  standard,

  /// Compact bottom navigation with icons only
  compact,

  /// Bottom navigation with floating action button
  withFAB,

  /// Bottom navigation with badge indicators
  withBadges,
}

class CustomBottomBar extends StatelessWidget {
  /// Current selected index
  final int currentIndex;

  /// Callback when item is tapped
  final ValueChanged<int> onTap;

  /// Variant of the bottom bar
  final CustomBottomBarVariant variant;

  /// Badge counts for each item (for withBadges variant)
  final List<int>? badgeCounts;

  /// Background color (defaults to theme surface color)
  final Color? backgroundColor;

  /// Whether to enable haptic feedback on tap
  final bool enableHaptics;

  /// Custom elevation
  final double? elevation;

  const CustomBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.variant = CustomBottomBarVariant.standard,
    this.badgeCounts,
    this.backgroundColor,
    this.enableHaptics = true,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Navigation items for restaurant owner dashboard
    final items = _buildNavigationItems(context);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.15),
            offset: const Offset(0, -2),
            blurRadius: 12,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            offset: const Offset(0, -4),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          child: SizedBox(
            height: variant == CustomBottomBarVariant.compact ? 56 : 64,
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                if (enableHaptics) {
                  HapticFeedback.lightImpact();
                }
                onTap(index);
              },
              items: items,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              selectedItemColor: colorScheme.primary,
              unselectedItemColor: colorScheme.onSurface.withValues(alpha: 0.6),
              selectedLabelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
              unselectedLabelStyle: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
              showSelectedLabels: variant != CustomBottomBarVariant.compact,
              showUnselectedLabels: variant != CustomBottomBarVariant.compact,
              elevation: 0,
              selectedFontSize: 12,
              unselectedFontSize: 12,
              iconSize: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// Build navigation items based on available routes
  List<BottomNavigationBarItem> _buildNavigationItems(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Define navigation items mapped to routes
    final navigationItems = [
      _NavigationItemData(
        icon: Icons.restaurant_menu_rounded,
        label: 'Menu',
        route: '/menu-management-screen',
      ),
      _NavigationItemData(
        icon: Icons.add_circle_outline_rounded,
        label: 'Add Item',
        route: '/add-edit-item-screen',
      ),
    ];

    return List.generate(navigationItems.length, (index) {
      final item = navigationItems[index];
      final hasBadge =
          variant == CustomBottomBarVariant.withBadges &&
          badgeCounts != null &&
          index < badgeCounts!.length &&
          badgeCounts![index] > 0;

      return BottomNavigationBarItem(
        icon: hasBadge
            ? _buildIconWithBadge(item.icon, badgeCounts![index], colorScheme)
            : Icon(item.icon),
        activeIcon: hasBadge
            ? _buildIconWithBadge(
                item.icon,
                badgeCounts![index],
                colorScheme,
                isActive: true,
              )
            : Icon(item.icon),
        label: item.label,
        tooltip: item.label,
      );
    });
  }

  /// Build icon with badge indicator
  Widget _buildIconWithBadge(
    IconData icon,
    int count,
    ColorScheme colorScheme, {
    bool isActive = false,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -8,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.surface, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onError,
                  height: 1.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

/// Data class for navigation items
class _NavigationItemData {
  final IconData icon;
  final String label;
  final String route;

  _NavigationItemData({
    required this.icon,
    required this.label,
    required this.route,
  });
}

/// Wrapper widget that handles navigation based on bottom bar selection
class CustomBottomBarNavigator extends StatefulWidget {
  /// Initial route index
  final int initialIndex;

  /// Variant of the bottom bar
  final CustomBottomBarVariant variant;

  /// Badge counts for navigation items
  final List<int>? badgeCounts;

  const CustomBottomBarNavigator({
    super.key,
    this.initialIndex = 0,
    this.variant = CustomBottomBarVariant.standard,
    this.badgeCounts,
  });

  @override
  State<CustomBottomBarNavigator> createState() =>
      _CustomBottomBarNavigatorState();
}

class _CustomBottomBarNavigatorState extends State<CustomBottomBarNavigator> {
  late int _currentIndex;

  // Route mapping
  final List<String> _routes = [
    '/menu-management-screen',
    '/add-edit-item-screen',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });

    // Navigate to the selected route
    Navigator.pushReplacementNamed(context, _routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return CustomBottomBar(
      currentIndex: _currentIndex,
      onTap: _onItemTapped,
      variant: widget.variant,
      badgeCounts: widget.badgeCounts,
    );
  }
}
