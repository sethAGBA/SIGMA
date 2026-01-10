enum ReportFrequency { daily, weekly, monthly, quartery }

enum ReportFormat { pdf, excel, word }

class CustomReportConfig {
  String? id;
  String title;
  String? description;

  // Indicators (List of IDs or keys)
  List<String> selectedIndicators;

  // Filters
  DateTime? startDate;
  DateTime? endDate;
  List<String> agencyIds; // Empty means all
  List<String> productIds; // Empty means all

  // Scheduling
  bool isScheduled;
  ReportFrequency frequency;
  List<String> emailRecipients;

  // Format
  ReportFormat format;

  CustomReportConfig({
    this.id,
    this.title = '',
    this.description,
    this.selectedIndicators = const [],
    this.startDate,
    this.endDate,
    this.agencyIds = const [],
    this.productIds = const [],
    this.isScheduled = false,
    this.frequency = ReportFrequency.monthly,
    this.emailRecipients = const [],
    this.format = ReportFormat.pdf,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'selected_indicators': selectedIndicators,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'agency_ids': agencyIds,
      'product_ids': productIds,
      'is_scheduled': isScheduled,
      'frequency': frequency.name,
      'email_recipients': emailRecipients,
      'format': format.name,
    };
  }

  factory CustomReportConfig.fromMap(Map<String, dynamic> map) {
    return CustomReportConfig(
      id: map['id'],
      title: map['title'] ?? '',
      description: map['description'],
      selectedIndicators: List<String>.from(map['selected_indicators'] ?? []),
      startDate: map['start_date'] != null
          ? DateTime.parse(map['start_date'])
          : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date']) : null,
      agencyIds: List<String>.from(map['agency_ids'] ?? []),
      productIds: List<String>.from(map['product_ids'] ?? []),
      isScheduled: map['is_scheduled'] ?? false,
      frequency: ReportFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => ReportFrequency.monthly,
      ),
      emailRecipients: List<String>.from(map['email_recipients'] ?? []),
      format: ReportFormat.values.firstWhere(
        (e) => e.name == map['format'],
        orElse: () => ReportFormat.pdf,
      ),
    );
  }
}
