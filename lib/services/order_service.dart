import 'package:flutter/foundation.dart';

// Order Status Enum
enum OrderStatus {
  pending,
  processing,
  printing,
  ready,
  completed,
  cancelled,
}

// Order Model
class PrintOrder {
  final String id;
  final String orderNumber;
  final DateTime createdAt;
  final List<String> fileNames;
  final int copies;
  final bool isColor;
  final bool isDoubleSided;
  final String paperSize;
  final int totalAmount;
  OrderStatus status;

  PrintOrder({
    required this.id,
    required this.orderNumber,
    required this.createdAt,
    required this.fileNames,
    required this.copies,
    required this.isColor,
    required this.isDoubleSided,
    required this.paperSize,
    required this.totalAmount,
    required this.status,
  });
}

/// Singleton service to manage orders across the app
class OrderService extends ChangeNotifier {
  // Private constructor
  OrderService._();
  
  // Static instance - lazily initialized
  static OrderService? _instance;
  
  // Factory constructor that returns the singleton
  static OrderService get instance {
    _instance ??= OrderService._();
    return _instance!;
  }
  
  // Alternative factory constructor for compatibility
  factory OrderService() => instance;

  final List<PrintOrder> _orders = [];
  int _orderCounter = 1;

  List<PrintOrder> get allOrders => List<PrintOrder>.from(_orders);
  
  List<PrintOrder> get activeOrders {
    try {
      return _orders
          .where((o) => o.status != OrderStatus.completed && o.status != OrderStatus.cancelled)
          .toList();
    } catch (e) {
      return [];
    }
  }

  List<PrintOrder> get pastOrders {
    try {
      return _orders
          .where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.cancelled)
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  int get activeCount => activeOrders.length;
  int get pastCount => pastOrders.length;
  int get totalSpent => _orders.fold<int>(0, (sum, o) => sum + o.totalAmount);

  /// Add a new order from the Upload screen
  PrintOrder addOrder({
    required List<String> fileNames,
    required int copies,
    required bool isColor,
    required bool isDoubleSided,
    required String paperSize,
    required int totalAmount,
  }) {
    final order = PrintOrder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      orderNumber: 'XF-2026-${_orderCounter.toString().padLeft(3, '0')}',
      createdAt: DateTime.now(),
      fileNames: fileNames,
      copies: copies,
      isColor: isColor,
      isDoubleSided: isDoubleSided,
      paperSize: paperSize,
      totalAmount: totalAmount,
      status: OrderStatus.pending,
    );

    _orders.insert(0, order); // Add to beginning (most recent first)
    _orderCounter++;
    notifyListeners();

    // Simulate order processing (for demo purposes)
    _simulateOrderProgress(order);

    return order;
  }

  /// Simulate order progress (for demonstration)
  Future<void> _simulateOrderProgress(PrintOrder order) async {
    // After 5 seconds, move to processing
    await Future.delayed(const Duration(seconds: 5));
    if (order.status == OrderStatus.pending) {
      order.status = OrderStatus.processing;
      notifyListeners();
    }

    // After 10 more seconds, move to printing
    await Future.delayed(const Duration(seconds: 10));
    if (order.status == OrderStatus.processing) {
      order.status = OrderStatus.printing;
      notifyListeners();
    }

    // After 15 more seconds, move to ready
    await Future.delayed(const Duration(seconds: 15));
    if (order.status == OrderStatus.printing) {
      order.status = OrderStatus.ready;
      notifyListeners();
    }
  }

  /// Mark an order as completed
  void completeOrder(String orderId) {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      order.status = OrderStatus.completed;
      notifyListeners();
    } catch (e) {
      debugPrint('Order not found: $orderId');
    }
  }

  /// Mark an order as cancelled
  void cancelOrder(String orderId) {
    try {
      final order = _orders.firstWhere((o) => o.id == orderId);
      order.status = OrderStatus.cancelled;
      notifyListeners();
    } catch (e) {
      debugPrint('Order not found: $orderId');
    }
  }

  /// Clear all orders (for testing)
  void clearOrders() {
    _orders.clear();
    _orderCounter = 1;
    notifyListeners();
  }
}
