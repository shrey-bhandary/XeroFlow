import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Create from Supabase JSON
  factory PrintOrder.fromJson(Map<String, dynamic> json) {
    return PrintOrder(
      id: json['id'] ?? '',
      orderNumber: json['order_id'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      fileNames: (json['file_names'] as List<dynamic>?)?.cast<String>() ?? [],
      copies: json['copies'] ?? 1,
      isColor: json['is_color'] ?? false,
      isDoubleSided: json['is_double_sided'] ?? false,
      paperSize: json['paper_size'] ?? 'A4',
      totalAmount: (json['cost'] as num?)?.toInt() ?? 0,
      status: _parseStatus(json['status']),
    );
  }

  static OrderStatus _parseStatus(String? status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'processing':
        return OrderStatus.processing;
      case 'printing':
        return OrderStatus.printing;
      case 'ready':
        return OrderStatus.ready;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  String get statusString {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.processing:
        return 'processing';
      case OrderStatus.printing:
        return 'printing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }
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

  // Supabase client
  SupabaseClient get _supabase => Supabase.instance.client;

  final List<PrintOrder> _orders = [];
  int _orderCounter = 1;
  bool _initialized = false;

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

  /// Initialize and load orders from Supabase
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('orders')
          .select()
          .eq('student_id', userId)
          .order('created_at', ascending: false);

      _orders.clear();
      for (final json in response) {
        _orders.add(PrintOrder.fromJson(json));
      }
      _initialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }
  }

  /// Refresh orders from Supabase
  Future<void> refreshOrders() async {
    _initialized = false;
    await initialize();
  }

  /// Add a new order from the Upload screen - saves to Supabase
  Future<PrintOrder?> addOrder({
    required List<String> fileNames,
    List<String>? fileUrls,
    required int copies,
    required bool isColor,
    required bool isDoubleSided,
    required String paperSize,
    required int totalAmount,
    DateTime? slotTime,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('No user logged in');
        return null;
      }

      // Generate order ID
      final dateStr = DateTime.now().toIso8601String().split('T')[0].replaceAll('-', '');
      final randomPart = (DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
      final orderNumber = 'XF-$dateStr-$randomPart';

      // Build the order data
      final orderData = <String, dynamic>{
        'student_id': userId,
        'order_id': orderNumber,
        'status': 'pending',
        'cost': totalAmount,
        'file_names': fileNames,
        'copies': copies,
        'is_color': isColor,
        'is_double_sided': isDoubleSided,
        'paper_size': paperSize,
      };

      // Add file_urls if provided
      if (fileUrls != null && fileUrls.isNotEmpty) {
        orderData['file_urls'] = fileUrls;
      }

      // Add slot_time if provided
      if (slotTime != null) {
        orderData['slot_time'] = slotTime.toIso8601String();
      }

      // Insert order into Supabase
      final response = await _supabase.from('orders').insert(orderData).select().single();

      final order = PrintOrder.fromJson(response);
      _orders.insert(0, order);
      _orderCounter++;
      notifyListeners();

      return order;
    } catch (e) {
      debugPrint('Error creating order: $e');
      return null;
    }
  }

  /// Update order status in Supabase
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      await _supabase.from('orders').update({
        'status': newStatus.toString().split('.').last,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Update local cache
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        _orders[orderIndex].status = newStatus;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  /// Mark an order as completed
  Future<void> completeOrder(String orderId) async {
    await updateOrderStatus(orderId, OrderStatus.completed);
  }

  /// Mark an order as cancelled
  Future<void> cancelOrder(String orderId) async {
    await updateOrderStatus(orderId, OrderStatus.cancelled);
  }

  /// Clear all orders (for testing)
  void clearOrders() {
    _orders.clear();
    _orderCounter = 1;
    _initialized = false;
    notifyListeners();
  }

  /// Subscribe to realtime order updates
  void subscribeToOrderUpdates() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase
        .channel('orders-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: userId,
          ),
          callback: (payload) {
            // Refresh orders when changes occur
            refreshOrders();
          },
        )
        .subscribe();
  }
}
