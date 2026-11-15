class Workspace {
  final String id;
  final String name;
  final String shortName;
  final int balance;
  final int monthlyInflow;
  final int monthlyOutflow;
  final bool isPro;
  final String focusType;
  final String role;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;

  const Workspace({
    required this.id,
    required this.name,
    required this.shortName,
    required this.balance,
    required this.monthlyInflow,
    required this.monthlyOutflow,
    this.isPro = true,
    this.focusType = 'umkm',
    this.role = 'owner',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountHolder = '',
  });

  Workspace copyWith({
    String? id,
    String? name,
    String? shortName,
    int? balance,
    int? monthlyInflow,
    int? monthlyOutflow,
    bool? isPro,
    String? focusType,
    String? role,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      balance: balance ?? this.balance,
      monthlyInflow: monthlyInflow ?? this.monthlyInflow,
      monthlyOutflow: monthlyOutflow ?? this.monthlyOutflow,
      isPro: isPro ?? this.isPro,
      focusType: focusType ?? this.focusType,
      role: role ?? this.role,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
    );
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      shortName: (json['short_name'] ?? '').toString(),
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      monthlyInflow: (json['monthly_inflow'] as num?)?.toInt() ?? 0,
      monthlyOutflow: (json['monthly_outflow'] as num?)?.toInt() ?? 0,
      isPro: json['is_pro'] as bool? ?? false,
      focusType: (json['focus_type'] ?? 'umkm').toString(),
      role: (json['role'] ?? 'owner').toString(),
      bankName: (json['bank_name'] ?? '').toString(),
      bankAccountNumber: (json['bank_account_number'] ?? '').toString(),
      bankAccountHolder: (json['bank_account_holder'] ?? '').toString(),
    );
  }
}
