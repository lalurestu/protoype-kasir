import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/domain/entities/user_role.dart';

// Screens
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/kasir/presentation/screens/kasir_dashboard_screen.dart';
import '../../features/owner/presentation/screens/owner_dashboard_screen.dart';
import '../../features/owner/presentation/screens/manage_menu_screen.dart';
import '../../features/owner/presentation/screens/manage_kasir_screen.dart';
import '../../features/owner/presentation/screens/manage_stock_screen.dart';
import '../../features/owner/presentation/screens/manage_customers_screen.dart';
import '../../features/owner/presentation/screens/owner_shifts_screen.dart';
import '../../features/kasir/presentation/screens/pos_checkout_screen.dart';
import '../../features/kasir/presentation/screens/kasir_report_screen.dart';
import '../../features/owner/presentation/screens/owner_report_screen.dart';
import '../../features/super_admin/presentation/screens/admin_dashboard_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == '/login';

      // Not authenticated
      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // Authenticated but trying to access login
      if (isLoggingIn) {
        switch (authState.role) {
          case UserRole.kasir:
            return '/kasir';
          case UserRole.owner:
            return '/owner';
          case UserRole.superAdmin:
            return '/admin';
          default:
            return '/login';
        }
      }

      // Guards for Roles
      final path = state.uri.path;
      if (path.startsWith('/kasir') && authState.role != UserRole.kasir) {
        return _getRoleDashboard(authState.role);
      }
      if (path.startsWith('/owner') && authState.role != UserRole.owner) {
        return _getRoleDashboard(authState.role);
      }
      if (path.startsWith('/admin') && authState.role != UserRole.superAdmin) {
        return _getRoleDashboard(authState.role);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
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
        ],
      ),
      // Super admin routing
      GoRoute(
        path: '/admin',
        name: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
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
      return '/admin';
    default:
      return '/login';
  }
}
