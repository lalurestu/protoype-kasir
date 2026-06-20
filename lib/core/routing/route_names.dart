class RouteNames {
  static const login = 'login';

  // Kasir Routes
  static const kasirDashboard = 'kasir-dashboard';
  static const kasirReport = 'kasir-report';
  static const posCheckout = 'pos-checkout';
  static const printerSettings = 'printer-settings';
  static const kasirManageCustomers = 'kasir-manage-customers';

  // Owner Routes
  static const ownerDashboard = 'owner-dashboard';
  static const ownerReport = 'owner-report';
  static const ownerShifts = 'owner-shifts';
  static const manageMenu = 'manage-menu';
  static const manageKasir = 'manage-kasir';
  static const manageStock = 'manage-stock';
  static const manageCustomers = 'manage-customers';

  // NOTE: Super Admin TIDAK ada di sini.
  // Super Admin hanya dapat diakses melalui portal Web (admin/index.html).
  // Flutter app hanya untuk role: Kasir & Owner.
}
