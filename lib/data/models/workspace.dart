enum MonthlyTrendType {
  noPrevData,
  up,
  down,
  flat,
}

class MonthlyComparisonSummary {
  final MonthlyTrendType trend;
  final String label;

  const MonthlyComparisonSummary({
    required this.trend,
    required this.label,
  });
}

class Workspace {
  final String id;
  final String name;
  final String shortName;
  final int balance;
  final int monthlyInflow;
  final int monthlyOutflow;
  final int prevMonthlyInflow;
  final int prevMonthlyOutflow;
  final bool isPro;
  final String focusType;
  final String role;
  final String bankName;
  final String bankAccountNumber;
  final String bankAccountHolder;
  final String logoUrl;
  final List<String> quickCategories;

  const Workspace({
    required this.id,
    required this.name,
    required this.shortName,
    required this.balance,
    required this.monthlyInflow,
    required this.monthlyOutflow,
    this.prevMonthlyInflow = 0,
    this.prevMonthlyOutflow = 0,
    this.isPro = true,
    this.focusType = 'umkm',
    this.role = 'owner',
    this.bankName = '',
    this.bankAccountNumber = '',
    this.bankAccountHolder = '',
    this.logoUrl = '',
    this.quickCategories = const ['Servis', 'Bahan Baku', 'Operasional'],
  });

  static List<String> defaultCategoriesForFocus(String focusType) {
    switch (focusType.trim().toLowerCase()) {
      case 'rumah_tangga':
        return const ['Belanja Dapur', 'Tagihan & Listrik', 'Kebutuhan Anak'];
      case 'komunitas':
        return const ['Iuran Kas', 'Konsumsi', 'Perlengkapan'];
      default:
        return const ['Servis', 'Bahan Baku', 'Operasional'];
    }
  }

  static List<String> normalizeQuickCategories(
    List<String> raw, {
    String focusType = 'umkm',
  }) {
    final defaults = defaultCategoriesForFocus(focusType);
    final result = <String>[];
    for (final item in raw) {
      final trimmed = item.trim();
      if (trimmed.isEmpty) continue;
      final capped =
          trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
      result.add(capped);
      if (result.length == 3) break;
    }
    for (int i = result.length; i < 3; i++) {
      result.add(defaults[i]);
    }
    return List.unmodifiable(result);
  }

  MonthlyComparisonSummary compareMonthlyNet({
    required int currentInflow,
    required int currentOutflow,
  }) {
    if (prevMonthlyInflow == 0 && prevMonthlyOutflow == 0) {
      final hasCurrentActivity = currentInflow > 0 || currentOutflow > 0;
      return MonthlyComparisonSummary(
        trend: MonthlyTrendType.noPrevData,
        label: hasCurrentActivity
            ? 'Bulan pertama pembukuan aktif'
            : 'Belum ada data bulan lalu',
      );
    }

    final currentNet = currentInflow - currentOutflow;
    final prevNet = prevMonthlyInflow - prevMonthlyOutflow;

    if (prevNet == 0) {
      if (currentNet > 0) {
        return const MonthlyComparisonSummary(
          trend: MonthlyTrendType.up,
          label: 'Naik dari posisi impas bulan lalu',
        );
      } else if (currentNet < 0) {
        return const MonthlyComparisonSummary(
          trend: MonthlyTrendType.down,
          label: 'Turun dari posisi impas bulan lalu',
        );
      }
      return const MonthlyComparisonSummary(
        trend: MonthlyTrendType.flat,
        label: 'Stabil (0%) dibanding bulan lalu',
      );
    }

    final rawPct = ((currentNet - prevNet) / prevNet.abs()) * 100.0;
    final roundedTenths = (rawPct * 10).round() / 10.0;
    if (roundedTenths == 0.0) {
      return const MonthlyComparisonSummary(
        trend: MonthlyTrendType.flat,
        label: 'Stabil (0%) dibanding bulan lalu',
      );
    }

    final absVal = roundedTenths.abs();
    final formattedPct = absVal == absVal.roundToDouble()
        ? absVal.toInt().toString()
        : absVal.toStringAsFixed(1).replaceAll('.', ',');

    if (roundedTenths > 0) {
      return MonthlyComparisonSummary(
        trend: MonthlyTrendType.up,
        label: 'Naik $formattedPct% dibanding bulan lalu',
      );
    }
    return MonthlyComparisonSummary(
      trend: MonthlyTrendType.down,
      label: 'Turun $formattedPct% dibanding bulan lalu',
    );
  }

  Workspace copyWith({
    String? id,
    String? name,
    String? shortName,
    int? balance,
    int? monthlyInflow,
    int? monthlyOutflow,
    int? prevMonthlyInflow,
    int? prevMonthlyOutflow,
    bool? isPro,
    String? focusType,
    String? role,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountHolder,
    String? logoUrl,
    List<String>? quickCategories,
  }) {
    final nextFocus = focusType ?? this.focusType;
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      balance: balance ?? this.balance,
      monthlyInflow: monthlyInflow ?? this.monthlyInflow,
      monthlyOutflow: monthlyOutflow ?? this.monthlyOutflow,
      prevMonthlyInflow: prevMonthlyInflow ?? this.prevMonthlyInflow,
      prevMonthlyOutflow: prevMonthlyOutflow ?? this.prevMonthlyOutflow,
      isPro: isPro ?? this.isPro,
      focusType: nextFocus,
      role: role ?? this.role,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      logoUrl: logoUrl ?? this.logoUrl,
      quickCategories: quickCategories != null
          ? normalizeQuickCategories(quickCategories, focusType: nextFocus)
          : this.quickCategories,
    );
  }

  factory Workspace.fromJson(Map<String, dynamic> json) {
    final focus = (json['focus_type'] ?? 'umkm').toString();
    final rawCats = (json['quick_categories'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    return Workspace(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      shortName: (json['short_name'] ?? '').toString(),
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      monthlyInflow: (json['monthly_inflow'] as num?)?.toInt() ?? 0,
      monthlyOutflow: (json['monthly_outflow'] as num?)?.toInt() ?? 0,
      prevMonthlyInflow: (json['prev_monthly_inflow'] as num?)?.toInt() ?? 0,
      prevMonthlyOutflow: (json['prev_monthly_outflow'] as num?)?.toInt() ?? 0,
      isPro: json['is_pro'] as bool? ?? false,
      focusType: focus,
      role: (json['role'] ?? 'owner').toString(),
      bankName: (json['bank_name'] ?? '').toString(),
      bankAccountNumber: (json['bank_account_number'] ?? '').toString(),
      bankAccountHolder: (json['bank_account_holder'] ?? '').toString(),
      logoUrl: (json['logo_url'] ?? '').toString(),
      quickCategories: normalizeQuickCategories(rawCats, focusType: focus),
    );
  }
}
