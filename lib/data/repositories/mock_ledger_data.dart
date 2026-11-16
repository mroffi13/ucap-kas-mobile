import '../models/cash_transaction.dart';
import '../models/nota_invoice.dart';
import '../models/workspace.dart';

class MockLedgerData {
  const MockLedgerData._();

  static const List<Workspace> workspaces = [
    Workspace(
      id: 'ws-bengkel',
      name: 'Bengkel Jaya (UMKM)',
      shortName: 'Bengkel Jaya',
      balance: 14850000,
      monthlyInflow: 8400000,
      monthlyOutflow: 3550000,
      prevMonthlyInflow: 7800000,
      prevMonthlyOutflow: 3488889,
      focusType: 'umkm',
      quickCategories: ['Servis', 'Bahan Baku', 'Operasional'],
    ),
    Workspace(
      id: 'ws-dapur',
      name: 'Dapur Rumah Tangga',
      shortName: 'Dapur Rumah',
      balance: 3200000,
      monthlyInflow: 6500000,
      monthlyOutflow: 3300000,
      prevMonthlyInflow: 6000000,
      prevMonthlyOutflow: 3100000,
      focusType: 'rumah_tangga',
      quickCategories: ['Belanja Dapur', 'Tagihan & Listrik', 'Kebutuhan Anak'],
    ),
  ];

  static const List<CashTransaction> initialTransactions = [
    CashTransaction(
      id: 'tx-1',
      title: 'Servis AC Mobil Avanza',
      category: 'Jasa Servis',
      paymentMethod: 'Tunai',
      timeLabel: '14:20',
      dateGroup: 'HARI INI • RABU, 11 NOV 2026',
      amount: 450000,
    ),
    CashTransaction(
      id: 'tx-2',
      title: 'Beli Kampas Rem Beat',
      category: 'Bahan Baku',
      paymentMethod: 'QRIS',
      timeLabel: '11:05',
      dateGroup: 'HARI INI • RABU, 11 NOV 2026',
      amount: -180000,
      hasReceiptPhoto: true,
    ),
    CashTransaction(
      id: 'tx-3',
      title: 'Konsumsi Siang Karyawan',
      category: 'Operasional',
      paymentMethod: 'Tunai',
      timeLabel: '08:30',
      dateGroup: 'HARI INI • RABU, 11 NOV 2026',
      amount: -45000,
      customerName: 'Oleh Rian',
    ),
    CashTransaction(
      id: 'tx-4',
      title: 'Penjualan Oli Mesin Shell',
      category: 'Suku Cadang',
      paymentMethod: 'QRIS',
      timeLabel: '07:15',
      dateGroup: 'HARI INI • RABU, 11 NOV 2026',
      amount: 95000,
    ),
    CashTransaction(
      id: 'tx-5',
      title: 'Pelunasan CV Karya Mandiri',
      category: 'Jasa Servis',
      paymentMethod: 'QRIS',
      timeLabel: '16:40',
      dateGroup: 'KEMARIN • SELASA, 10 NOV 2026',
      amount: 1250000,
      notaRef: 'Nota #1106',
    ),
    CashTransaction(
      id: 'tx-6',
      title: 'Isi Freon R134a (2 Tabung)',
      category: 'Bahan Baku',
      paymentMethod: 'Transfer BCA',
      timeLabel: '13:10',
      dateGroup: 'KEMARIN • SELASA, 10 NOV 2026',
      amount: -320000,
    ),
  ];

  static const List<NotaInvoice> initialNotas = [
    NotaInvoice(
      number: 'NOTA/2026/1104',
      clientName: 'PT Maju Logistik',
      clientContact: 'Pak Hendra • 0812-3344-5566',
      subtitle: 'Servis 3 Mobil • Lewat 1 hari',
      dateIssued: '03 Nov 2026',
      dueDateLabel: 'Tempo: 10 Nov',
      amount: 750000,
      status: NotaStatus.jatuhTempo,
      items: [
        TransactionLineItem(name: '1. Servis Berkala & Oli (3 Mobil Blindvan)', quantity: 1, unitPrice: 600000),
        TransactionLineItem(name: '2. Filter Udara & Kampas Rem Depan (3 Set)', quantity: 1, unitPrice: 350000),
        TransactionLineItem(name: '3. Potongan Harga Pelanggan Rutin', quantity: 1, unitPrice: -200000),
      ],
    ),
    NotaInvoice(
      number: 'NOTA/2026/1108',
      clientName: 'Pak Budi — Servis AC',
      clientContact: '0812-8899-7766',
      subtitle: 'NOTA/2026/1108 • Tempo: Besok',
      dateIssued: '08 Nov 2026',
      dueDateLabel: 'Besok',
      amount: 600000,
      status: NotaStatus.menunggu,
      items: [
        TransactionLineItem(name: '1. Servis AC Mobil Avanza (1x)', quantity: 1, unitPrice: 450000),
        TransactionLineItem(name: '2. Tambah Freon AC R134a (1x)', quantity: 1, unitPrice: 150000),
      ],
    ),
    NotaInvoice(
      number: 'NOTA/2026/1107',
      clientName: 'Pak Joko — Oli & Busi',
      clientContact: '0813-1122-3344',
      subtitle: 'NOTA/2026/1107 • Lunas (Kas)',
      dateIssued: '07 Nov 2026',
      dueDateLabel: 'Lunas',
      amount: 55000,
      status: NotaStatus.lunas,
    ),
    NotaInvoice(
      number: 'NOTA/2026/1106',
      clientName: 'CV Karya Mandiri',
      clientContact: '0811-9988-7766',
      subtitle: 'Servis AC • Lunas (QRIS)',
      dateIssued: '05 Nov 2026',
      dueDateLabel: 'Lunas',
      amount: 1250000,
      status: NotaStatus.lunas,
    ),
  ];
}
