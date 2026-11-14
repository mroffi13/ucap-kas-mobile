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
    this.items = const [],
  });

  bool get isInflow => amount >= 0;
}
