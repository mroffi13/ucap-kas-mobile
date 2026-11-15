class TransactionLineItem {
  final String name;
  final int quantity;
  final int unitPrice;

  const TransactionLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  int get subtotal => quantity * unitPrice;

  TransactionLineItem copyWith({String? name, int? quantity, int? unitPrice}) {
    return TransactionLineItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }

  factory TransactionLineItem.fromJson(Map<String, dynamic> json) {
    return TransactionLineItem(
      name: (json['name'] ?? '').toString(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }
}

class CashTransaction {
  final String id;
  final String title;
  final String category;
  final String paymentMethod;
  final String timeLabel;
  final String dateGroup;
  final int amount;
  final String? customerName;
  final String? notaRef;
  final bool hasReceiptPhoto;
  final String source;
  final List<TransactionLineItem> items;

  const CashTransaction({
    required this.id,
    required this.title,
    required this.category,
    required this.paymentMethod,
    required this.timeLabel,
    required this.dateGroup,
    required this.amount,
    this.customerName,
    this.notaRef,
    this.hasReceiptPhoto = false,
    this.source = 'manual',
    this.items = const [],
  });

  bool get isInflow => amount >= 0;

  factory CashTransaction.fromJson(Map<String, dynamic> json) {
    final rawAmount = (json['amount'] as num?)?.toInt() ?? 0;
    final type = (json['type'] ?? 'inflow').toString().toLowerCase();
    final signedAmount = type == 'outflow' ? -rawAmount.abs() : rawAmount.abs();
    final rawCustomer = (json['customer_name'] ?? '').toString().trim();
    final rawNotaRef = (json['nota_ref'] ?? '').toString().trim();
    final rawItems = (json['items'] as List<dynamic>? ?? const []);

    return CashTransaction(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      category: (json['category'] ?? 'Lainnya').toString(),
      paymentMethod: (json['payment_method'] ?? 'Tunai').toString(),
      timeLabel: (json['time_label'] ?? '').toString(),
      dateGroup: (json['date_group'] ?? 'Hari Ini').toString(),
      amount: signedAmount,
      customerName: rawCustomer.isEmpty ? null : rawCustomer,
      notaRef: rawNotaRef.isEmpty ? null : rawNotaRef,
      hasReceiptPhoto: json['has_receipt_photo'] as bool? ?? false,
      source: (json['source'] ?? 'manual').toString(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TransactionLineItem.fromJson)
          .toList(),
    );
  }
}
