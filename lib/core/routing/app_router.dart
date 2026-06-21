import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/domain/entities/user_role.dart';

// Screens — Flutter app hanya untuk Kasir & Owner
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/pin_lock_screen.dart';
import '../../features/kasir/presentation/screens/kasir_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/manage_menu_screen.dart';
import '../../features/owner/presentation/screens/manage_kasir_screen.dart';
import '../../features/owner/presentation/screens/manage_stock_screen.dart';
import '../../features/owner/presentation/screens/manage_customers_screen.dart';
import '../../features/owner/presentation/screens/owner_shifts_screen.dart';
import '../../features/kasir/presentation/screens/pos_checkout_screen.dart';
import '../../features/kasir/presentation/screens/kasir_report_screen.dart';
import '../../features/kasir/presentation/screens/printer_settings_screen.dart';
import '../../features/kasir/presentation/screens/kasir_expense_screen.dart';
import '../../features/owner/presentation/screens/owner_report_screen.dart';
import '../../features/owner/presentation/screens/owner_store_settings_screen.dart';
import '../../features/owner/presentation/screens/manage_promo_screen.dart';
import '../../features/owner/presentation/screens/owner_tax_service_screen.dart';
import '../../features/owner/presentation/screens/owner_low_stock_screen.dart';
import '../../features/owner/presentation/screens/owner_license_screen.dart';

/// Notifier yang jadi jembatan antara Riverpod state dan GoRouter,
/// sehingga GoRouter TIDAK perlu direcreate setiap auth state berubah.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Dengerin perubahan authProvider, kalau berubah kasih tau router
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final isLoggingIn = state.uri.path == '/login';

    // Belum login -> paksa ke login
    if (!authState.isAuthenticated) {
      return isLoggingIn ? null : '/login';
    }

    // Sudah login tapi PIN belum diverifikasi -> paksa ke pin-lock
    if (!authState.isPinVerified) {
      return state.uri.path == '/pin-lock' ? null : '/pin-lock';
    }

    // Jika sudah verifikasi PIN tapi mencoba akses /login atau /pin-lock -> arahkan ke dashboard
    if (isLoggingIn || state.uri.path == '/pin-lock') {
      return _getRoleDashboard(authState.role);
    }

    // Super Admin tidak boleh masuk Flutter — redirect ke login
    // Super Admin hanya bisa menggunakan portal Web (admin/index.html)
    if (authState.role == UserRole.superAdmin) {
      return '/login';
    }

    // Guard per role
    final path = state.uri.path;
    if (path.startsWith('/kasir') && authState.role != UserRole.kasir) {
      return _getRoleDashboard(authState.role);
    }
    if (path.startsWith('/owner') && authState.role != UserRole.owner) {
      return _getRoleDashboard(authState.role);
    }

    return null;
  }
}

final routerNotifierProvider = ChangeNotifierProvider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/pin-lock',
        builder: (context, state) => const PinLockScreen(),
      ),
      GoRoute(
        path: '/kasir',
        name: RouteNames.kasirDashboard,
        builder: (context, state) => const KasirDashboardScreen(),
        routes: [
          GoRoute(
            path: 'checkout',
            name: RouteNames.posCheckout,
            builder: (context, state) => const PosCheckoutScreen(),
          ),
          GoRoute(
            path: 'report',
            name: RouteNames.kasirReport,
            builder: (context, state) => const KasirReportScreen(),
          ),
          GoRoute(
            path: 'printer-settings',
            name: RouteNames.printerSettings,
            builder: (context, state) => const PrinterSettingsScreen(),
          ),
          GoRoute(
            path: 'expense',
            name: RouteNames.kasirExpense,
            builder: (context, state) => const KasirExpenseScreen(),
          ),
          GoRoute(
            path: 'manage-customers',
            name: RouteNames.kasirManageCustomers,
            builder: (context, state) => const ManageCustomersScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/owner',
        name: RouteNames.ownerDashboard,
        builder: (context, state) => const OwnerDashboardScreen(),
        routes: [
          GoRoute(
            path: 'manage-menu',
            name: RouteNames.manageMenu,
            builder: (context, state) => const ManageMenuScreen(),
          ),
          GoRoute(
            path: 'manage-kasir',
            name: RouteNames.manageKasir,
            builder: (context, state) => const ManageKasirScreen(),
          ),
          GoRoute(
            path: 'manage-stock',
            name: RouteNames.manageStock,
            builder: (context, state) => const ManageStockScreen(),
          ),
          GoRoute(
            path: 'manage-customers',
            name: RouteNames.manageCustomers,
            builder: (context, state) => const ManageCustomersScreen(),
          ),
          GoRoute(
            path: 'shifts',
            name: RouteNames.ownerShifts,
            builder: (context, state) => const OwnerShiftsScreen(),
          ),
          GoRoute(
            path: 'report',
            name: RouteNames.ownerReport,
            builder: (context, state) => const OwnerReportScreen(),
          ),
          GoRoute(
            path: 'store-settings',
            name: RouteNames.storeSettings,
            builder: (context, state) => const OwnerStoreSettingsScreen(),
          ),
          GoRoute(
            path: 'manage-promo',
            name: RouteNames.managePromo,
            builder: (context, state) => const ManagePromoScreen(),
          ),
          GoRoute(
            path: 'tax-service',
            name: RouteNames.ownerTaxService,
            builder: (context, state) => const OwnerTaxServiceScreen(),
          ),
          GoRoute(
            path: 'low-stock-alert',
            name: RouteNames.ownerLowStockAlert,
            builder: (context, state) => const OwnerLowStockScreen(),
          ),
          GoRoute(
            path: 'license',
            name: RouteNames.ownerLicense,
            builder: (context, state) => const OwnerLicenseScreen(),
          ),
        ],
      ),
      // NOTE: Tidak ada route /admin di Flutter.
      // Super Admin HANYA dapat menggunakan portal Web: admin/index.html
    ],
  );
});

String _getRoleDashboard(UserRole role) {
  switch (role) {
    case UserRole.kasir:
      return '/kasir';
    case UserRole.owner:
      return '/owner';
    case UserRole.superAdmin:
      // Super Admin tidak punya dashboard di Flutter — kembali ke login
      return '/login';
    default:
      return '/login';
  }
}
