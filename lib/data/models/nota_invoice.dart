import 'cash_transaction.dart';

enum NotaStatus { jatuhTempo, menunggu, lunas }

extension NotaStatusCodec on NotaStatus {
  String get apiValue => switch (this) {
        NotaStatus.jatuhTempo => 'jatuh_tempo',
        NotaStatus.menunggu => 'menunggu',
        NotaStatus.lunas => 'lunas',
      };

  static NotaStatus fromApi(String raw) {
    return switch (raw.toLowerCase().trim()) {
      'jatuh_tempo' => NotaStatus.jatuhTempo,
      'lunas' => NotaStatus.lunas,
      _ => NotaStatus.menunggu,
    };
  }
}

class NotaInvoice {
  final String id;
  final String number;
  final String clientName;
  final String clientContact;
  final String subtitle;
  final String dateIssued;
  final String dueDateLabel;
  final DateTime? dueAt;
  final int amount;
  final NotaStatus status;
  final String notes;
  final List<TransactionLineItem> items;

  const NotaInvoice({
    this.id = '',
    required this.number,
    required this.clientName,
    required this.clientContact,
    required this.subtitle,
    required this.dateIssued,
    required this.dueDateLabel,
    this.dueAt,
    required this.amount,
    required this.status,
    this.notes = '',
    this.items = const [],
  });

  NotaInvoice copyWith({
    String? id,
    String? number,
    String? clientName,
    String? clientContact,
    String? subtitle,
    String? dateIssued,
    String? dueDateLabel,
    DateTime? dueAt,
    int? amount,
    NotaStatus? status,
    String? notes,
    List<TransactionLineItem>? items,
  }) {
    return NotaInvoice(
      id: id ?? this.id,
      number: number ?? this.number,
      clientName: clientName ?? this.clientName,
      clientContact: clientContact ?? this.clientContact,
      subtitle: subtitle ?? this.subtitle,
      dateIssued: dateIssued ?? this.dateIssued,
      dueDateLabel: dueDateLabel ?? this.dueDateLabel,
      dueAt: dueAt ?? this.dueAt,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      items: items ?? this.items,
    );
  }

  factory NotaInvoice.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const [];
    final rawDueAt = (json['due_at'] ?? '').toString().trim();
    return NotaInvoice(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? json['invoice_number'] ?? '').toString(),
      clientName: (json['client_name'] ?? '').toString(),
      clientContact: (json['client_contact'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      dateIssued: (json['date_issued'] ?? '').toString(),
      dueDateLabel: (json['due_date_label'] ?? '').toString(),
      dueAt: rawDueAt.isEmpty ? null : DateTime.tryParse(rawDueAt),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: NotaStatusCodec.fromApi((json['status'] ?? 'menunggu').toString()),
      notes: (json['notes'] ?? '').toString(),
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TransactionLineItem.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (number.isNotEmpty) 'invoice_number': number,
      'client_name': clientName,
      'client_contact': clientContact,
      'subtitle': subtitle,
      'due_date_label': dueDateLabel,
      if (dueAt != null) 'due_at': dueAt!.toUtc().toIso8601String(),
      'amount': amount,
      'status': status.apiValue,
      'notes': notes,
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
