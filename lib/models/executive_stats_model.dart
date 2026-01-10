// lib/models/executive_stats_model.dart

class ActivityStats {
  final int activeClientsCount;
  final int newClientsMonth;
  final int lapsedClients;
  final double penetrationRate;
  final double retentionRate;

  ActivityStats({
    required this.activeClientsCount,
    required this.newClientsMonth,
    required this.lapsedClients,
    required this.penetrationRate,
    required this.retentionRate,
  });
}

class PortfolioStats {
  final double totalOutstanding;
  final int activeLoansCount;
  final double averageLoanAmount;
  final double monthlyGrowth;
  final double disbursementsMonth;
  final double repaymentsMonth;
  final Map<String, double> outstandingByProduct;

  PortfolioStats({
    required this.totalOutstanding,
    required this.activeLoansCount,
    required this.averageLoanAmount,
    required this.monthlyGrowth,
    required this.disbursementsMonth,
    required this.repaymentsMonth,
    required this.outstandingByProduct,
  });
}

class QualityStats {
  final double par30Rate;
  final double repaymentRate;
  final double writeOffRate;
  final double provisionsOutstandingRatio;
  final List<EvolutionPoint> par12MonthEvolution;
  final List<EvolutionPoint> repaymentRateEvolution;
  final double doubtfulDebts;

  QualityStats({
    required this.par30Rate,
    required this.repaymentRate,
    required this.writeOffRate,
    required this.provisionsOutstandingRatio,
    required this.par12MonthEvolution,
    required this.repaymentRateEvolution,
    required this.doubtfulDebts,
  });
}

class EvolutionPoint {
  final String label;
  final double value;
  EvolutionPoint(this.label, this.value);
}

class SavingsStats {
  final double totalSavings;
  final int accountsCount;
  final double averageSavings;
  final double savingsGrowth;
  final double savingsCreditRatio;

  final Map<String, double> savingsByType;

  SavingsStats({
    required this.totalSavings,
    required this.accountsCount,
    required this.averageSavings,
    required this.savingsGrowth,
    required this.savingsCreditRatio,
    required this.savingsByType,
  });
}

class AgentPerformanceMetric {
  final String name;
  final double volume;
  final double parRate;
  final double collectionRate;

  AgentPerformanceMetric({
    required this.name,
    required this.volume,
    required this.parRate,
    required this.collectionRate,
  });
}

class GeographicPoint {
  final String region;
  final double volume;
  final int clientCount;

  GeographicPoint({
    required this.region,
    required this.volume,
    required this.clientCount,
  });
}

class ProductDemand {
  final String name;
  final int requestCount;
  final double totalRequestedAmount;

  ProductDemand({
    required this.name,
    required this.requestCount,
    required this.totalRequestedAmount,
  });
}

class FinancialPerformance {
  final double netInterestIncome;
  final double feeIncome;
  final double operatingExpenses;
  final double netIncome;
  final double roe;
  final double roa;

  FinancialPerformance({
    required this.netInterestIncome,
    required this.feeIncome,
    required this.operatingExpenses,
    required this.netIncome,
    required this.roe,
    required this.roa,
  });
}

class ExecutiveDashboardStats {
  final ActivityStats activity;
  final PortfolioStats portfolio;
  final QualityStats quality;
  final SavingsStats savings;
  final List<AgentPerformanceMetric> topAgents;
  final List<GeographicPoint> geographicDistribution;
  final List<ProductDemand> popularProducts;
  final List<EvolutionPoint> outstanding12MonthEvolution;
  final FinancialPerformance financial;
  final DateTime lastUpdate;

  ExecutiveDashboardStats({
    required this.activity,
    required this.portfolio,
    required this.quality,
    required this.savings,
    required this.topAgents,
    required this.geographicDistribution,
    required this.popularProducts,
    required this.outstanding12MonthEvolution,
    required this.financial,
    required this.lastUpdate,
  });
}
