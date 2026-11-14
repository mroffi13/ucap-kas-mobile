class Workspace {
  final String id;
  final String name;
  final String shortName;
  final int balance;
  final int monthlyInflow;
  final int monthlyOutflow;
  final bool isPro;

  const Workspace({
    required this.id,
    required this.name,
    required this.shortName,
    required this.balance,
    required this.monthlyInflow,
    required this.monthlyOutflow,
    this.isPro = true,
  });
}
