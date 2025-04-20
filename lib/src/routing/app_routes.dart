/// Constants for application routes
class AppRoutes {
  // Base routes
  static const String home = '/';
  static const String login = '/login';
  
  // Order routes
  static const String orders = '/orders';
  static const String addOrder = '/orders/add';
  static const String editOrder = '/orders/edit/:orderId';
  static const String orderDetails = '/orders/:orderId';
  static const String picking = '/orders/:orderId/picking';
  
  // Item routes
  static const String addItem = '/items/add';
  static const String editItem = '/items/edit/:itemId';
  
  // Route names (for named navigation)
  static const String homeName = 'home';
  static const String loginName = 'login';
  static const String ordersName = 'orders';
  static const String addOrderName = 'addOrder';
  static const String editOrderName = 'editOrder';
  static const String orderDetailsName = 'orderDetails';
  static const String pickingName = 'picking';
  static const String addItemName = 'addItem';
  static const String editItemName = 'editItem';
  static const String managePickers = 'manage-pickers';
  static const String pickers = '/pickers';
} 