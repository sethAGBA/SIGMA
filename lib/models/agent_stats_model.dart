class AgentStats {
  // Portfolio
  final int assignedClients;
  final double outstandingAmount;
  final int activeLoansCount;
  final double parRatio;
  final double repaymentRate;

  // Monthly Activity
  final int newClients;
  final int loansDisbursedCount;
  final double disbursedAmount;
  final double collectedAmount;
  final int visitsCount;
  final double objectiveAchievementRate;

  // Performance (Generic/KPIs)
  final double productivityRate; // e.g., loans per month
  final double processingTimeDays; // Average days
  final double clientSatisfactionScore; // out of 5 or 10
  final double qualityScore; // 0-100 or 0-5

  // Objectives & Bonus
  final double monthlyObjectiveAmount;
  final double bonusEarned;

  const AgentStats({
    this.assignedClients = 0,
    this.outstandingAmount = 0.0,
    this.activeLoansCount = 0,
    this.parRatio = 0.0,
    this.repaymentRate = 0.0,
    this.newClients = 0,
    this.loansDisbursedCount = 0,
    this.disbursedAmount = 0.0,
    this.collectedAmount = 0.0,
    this.visitsCount = 0,
    this.objectiveAchievementRate = 0.0,
    this.productivityRate = 0.0,
    this.processingTimeDays = 0.0,
    this.clientSatisfactionScore = 0.0,
    this.qualityScore = 0.0,
    this.monthlyObjectiveAmount = 0.0,
    this.bonusEarned = 0.0,
  });
}

class GlobalTeamStats {
  final double totalOutstanding;
  final int totalActiveClients;
  final double avgParRatio;
  final double monthlyCollection;
  final double avgProductivity;
  final int newClientsMonth;

  GlobalTeamStats({
    this.totalOutstanding = 0.0,
    this.totalActiveClients = 0,
    this.avgParRatio = 0.0,
    this.monthlyCollection = 0.0,
    this.avgProductivity = 0.0,
    this.newClientsMonth = 0,
  });
}
