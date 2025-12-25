import 'package:get/get.dart';
import 'package:mata3mna/config/routes/app_pages.dart';
import 'package:mata3mna/features/auth/presentation/pages/login_page.dart';
import 'package:mata3mna/features/auth/presentation/pages/admin_login_page.dart';
import 'package:mata3mna/features/auth/presentation/pages/sign_up_page.dart';
import 'package:mata3mna/features/auth/presentation/pages/start_page.dart';
import 'package:mata3mna/features/auth/presentation/pages/verify_email_page.dart';
import 'package:mata3mna/features/cart/presentation/cart_page.dart';
import 'package:mata3mna/features/home/presentation/pages/home_page.dart';
import 'package:mata3mna/features/home/presentation/pages/customer_view_screen.dart';
import 'package:mata3mna/features/items_managment/presentation/pages/add_items_secreen.dart';
import 'package:mata3mna/features/restaurant_info/presentation/pages/restaurant_info_screen.dart';
import 'package:mata3mna/features/restaurant_info/presentation/pages/restaurant_detail_screen.dart';
import 'package:mata3mna/features/home/presentation/pages/item_detail_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/location_management_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/admin_restaurant_management_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/admin_item_management_screen.dart';
import 'package:mata3mna/features/dashboard/presentation/pages/admin_category_management_screen.dart';
import 'package:mata3mna/config/routes/route_middleware.dart';

class AppRoutes {
  static final List<GetPage> routes = [
    GetPage(
      name: AppPages.root,
      page: () => const ChooseRolePage(),
      transition: Transition.fadeIn,
      middlewares: [AdminRedirectMiddleware()],
    ),
    GetPage(
      name: AppPages.signUp,
      page: () => const SignUpPage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppPages.login,
      page: () => const LoginPage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppPages.adminLogin,
      page: () => const AdminLoginPage(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: AppPages.verifyEmail,
      page: () {
        final args = Get.arguments as Map<String, dynamic>;
        return VerifyEmailScreen(
          email: args['email'],
          onResendVerification: args['onResendVerification'],
          onCheckVerification: args['onCheckVerification'],
          onLogout: args['onLogout'],
        );
      },
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.home,
      page: () => const MenuManagementScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.customerView,
      page: () => const CustomerViewScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.completeRestaurantInfo,
      page: () => const RestaurantInfoScreen(),
      transition: Transition.fadeIn,
      middlewares: [OwnerOnlyMiddleware()],
    ),

    GetPage(
      name: AppPages.addItem,
      page: () {
        final args = Get.arguments as Map<String, dynamic>?;
        return AddEditItemScreen(
          itemData: args != null ? args['item'] as Map<String, dynamic>? : null,
        );
      },
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.restaurantDetail,
      page: () => const RestaurantDetailScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.cart,
      page: () => CartPage(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.itemDetail,
      page: () => const ItemDetailScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.dashboard,
      page: () => const DashboardScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.locationManagement,
      page: () => const LocationManagementScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.adminRestaurantManagement,
      page: () => const AdminRestaurantManagementScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.adminItemManagement,
      page: () => const AdminItemManagementScreen(),
      transition: Transition.fadeIn,
    ),

    GetPage(
      name: AppPages.adminCategoryManagement,
      page: () => const AdminCategoryManagementScreen(),
      transition: Transition.fadeIn,
    ),
  ];
}
