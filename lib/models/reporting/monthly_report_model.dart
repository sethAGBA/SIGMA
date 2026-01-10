// lib/models/reporting/monthly_report_model.dart

class MonthlyReportStats {
  final DateTime month;

  // I. SYNTHÈSE EXÉCUTIVE
  final double encoursTotal;
  final double encoursVariation; // Percentage
  final double par30Rate;
  final double repaymentRate;
  final int newClientsCount;
  final double netIncome;

  // II. ACTIVITÉ CRÉDIT
  final int loanRequestsReceived;
  final int loansApproved;
  final double approvalRate; // (loansApproved / loanRequestsReceived) * 100
  final double disbursedAmount;
  final double repaidAmount;

  // III. QUALITÉ DU PORTEFEUILLE
  final double par1_30Rate;
  final double par31_90Rate;
  final double par90PlusRate;
  final double writeOffAmount;

  // IV. ÉPARGNE
  final double totalSavings;
  final double savingsGrowth; // Absolute or percentage variation
  final int newAccountsCount;
  final double savingsCreditRatio;

  // V. PERFORMANCE FINANCIÈRE
  final double financialProductsIncome;
  final double operatingExpenses;
  final double roa;
  final double roe;

  MonthlyReportStats({
    required this.month,
    required this.encoursTotal,
    required this.encoursVariation,
    required this.par30Rate,
    required this.repaymentRate,
    required this.newClientsCount,
    required this.netIncome,
    required this.loanRequestsReceived,
    required this.loansApproved,
    required this.approvalRate,
    required this.disbursedAmount,
    required this.repaidAmount,
    required this.par1_30Rate,
    required this.par31_90Rate,
    required this.par90PlusRate,
    required this.writeOffAmount,
    required this.totalSavings,
    required this.savingsGrowth,
    required this.newAccountsCount,
    required this.savingsCreditRatio,
    required this.financialProductsIncome,
    required this.operatingExpenses,
    required this.roa,
    required this.roe,
  });
}
