class PrintOrder {
  final String? id;
  final String studentId;
  final String orderId;
  final String status;
  final DateTime? slotTime;
  final double cost;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PrintOrder({
    this.id,
    required this.studentId,
    required this.orderId,
    this.status = 'pending',
    this.slotTime,
    required this.cost,
    this.createdAt,
    this.updatedAt,
  });

  factory PrintOrder.fromJson(Map<String, dynamic> json) {
    return PrintOrder(
      id: json['id'] as String?,
      studentId: json['student_id'] as String,
      orderId: json['order_id'] as String,
      status: json['status'] as String? ?? 'pending',
      slotTime: json['slot_time'] != null 
          ? DateTime.parse(json['slot_time'] as String) 
          : null,
      cost: (json['cost'] as num).toDouble(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'student_id': studentId,
      'order_id': orderId,
      'status': status,
      if (slotTime != null) 'slot_time': slotTime!.toIso8601String(),
      'cost': cost,
    };
  }

  // Status helpers
  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isReady => status == 'ready';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  String get displayStatus {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'processing':
        return 'Processing';
      case 'ready':
        return 'Ready for Pickup';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }
}
