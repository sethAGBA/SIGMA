import 'loan_model.dart';
import 'client_model.dart';
import 'repayment_schedule_model.dart';
import 'recovery_action_model.dart';

class DelinquentLoanDetails {
  final Loan loan;
  final Client client;
  final List<RepaymentSchedule> unpaidSchedules;
  final double penalitesAccumulees;
  final double provisionConstituee;
  final int joursRetard;
  final List<RecoveryAction> recoveryActions;
  final List<GuaranteeStatus> guarantees;

  DelinquentLoanDetails({
    required this.loan,
    required this.client,
    required this.unpaidSchedules,
    required this.penalitesAccumulees,
    required this.provisionConstituee,
    required this.joursRetard,
    this.recoveryActions = const [],
    this.guarantees = const [],
  });
}

class GuaranteeStatus {
  final String type;
  final double estimatedValue;
  final String status; // En possession, À réaliser, Réalisée
  final String description;

  GuaranteeStatus({
    required this.type,
    required this.estimatedValue,
    required this.status,
    required this.description,
  });
}
