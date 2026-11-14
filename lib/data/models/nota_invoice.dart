import 'cash_transaction.dart';

enum NotaStatus { jatuhTempo, menunggu, lunas }

class NotaInvoice {
  final String number;
  final String clientName;
  final String clientContact;
  final String subtitle;
  final String dateIssued;
  final String dueDateLabel;
  final int amount;
  final NotaStatus status;
  final List<TransactionLineItem> items;

  const NotaInvoice({
    required this.number,
    required this.clientName,
    required this.clientContact,
    required this.subtitle,
    required this.dateIssued,
    required this.dueDateLabel,
    required this.amount,
    required this.status,
    this.items = const [],
  });

  NotaInvoice copyWith({NotaStatus? status, String? subtitle}) {
    return NotaInvoice(
      number: number,
      clientName: clientName,
      clientContact: clientContact,
      subtitle: subtitle ?? this.subtitle,
      dateIssued: dateIssued,
      dueDateLabel: dueDateLabel,
      amount: amount,
      status: status ?? this.status,
      items: items,
    );
  }
}
