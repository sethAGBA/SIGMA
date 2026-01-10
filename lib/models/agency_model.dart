class Agency {
  final String id;
  final String name;
  final String code;
  final String address;
  final String phone;
  final String email;
  final double latitude;
  final double longitude;
  final String coverageArea;
  final DateTime openingDate;
  final bool isActive;
  final AgencyStats stats;
  final AgencyTeam team;

  Agency({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.phone,
    required this.email,
    required this.latitude,
    required this.longitude,
    required this.coverageArea,
    required this.openingDate,
    required this.isActive,
    required this.stats,
    required this.team,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'coverage_area': coverageArea,
      'opening_date': openingDate.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      // Stats and Team are calculated or stored separately usually,
      // but for simplicity we can ignore them in simple CRUD or manage linked tables.
      // For now, let's assume they are computed on read or defaults.
    };
  }

  factory Agency.fromMap(Map<String, dynamic> map) {
    return Agency(
      id: map['id'],
      name: map['name'],
      code: map['code'],
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      latitude: map['latitude'] ?? 0.0,
      longitude: map['longitude'] ?? 0.0,
      coverageArea: map['coverage_area'] ?? '',
      openingDate: DateTime.parse(map['opening_date']),
      isActive: map['is_active'] == 1,
      stats: AgencyStats(
        activeClients: 0,
        totalOutstanding: 0,
        parRatio: 0,
        totalStaff: 0,
      ),
      team: AgencyTeam(
        managerName: '',
        loanOfficersCount: 0,
        cashiersCount: 0,
        backOfficeCount: 0,
      ),
    );
  }

  Agency copyWith({
    String? id,
    String? name,
    String? code,
    String? address,
    String? phone,
    String? email,
    double? latitude,
    double? longitude,
    String? coverageArea,
    DateTime? openingDate,
    bool? isActive,
    AgencyStats? stats,
    AgencyTeam? team,
  }) {
    return Agency(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      coverageArea: coverageArea ?? this.coverageArea,
      openingDate: openingDate ?? this.openingDate,
      isActive: isActive ?? this.isActive,
      stats: stats ?? this.stats,
      team: team ?? this.team,
    );
  }
}

class AgencyStats {
  final int activeClients;
  final double totalOutstanding;
  final double parRatio;
  final int totalStaff;

  // Portfolio Extras
  final int activeLoansCount;
  final double avgLoanAmount;

  // Savings
  final int savingsAccountsCount;
  final double totalSavings;
  final double avgSavings;
  final int newAccountsMonth;

  // Performance
  final double financialProductsAmount;
  final double operationalExpensesAmount;
  final double netResultAmount;

  // Team
  final String managerName;
  final int loanOfficersCount;
  final int cashiersCount;
  final int backOfficeCount;

  AgencyStats({
    required this.activeClients,
    required this.totalOutstanding,
    required this.parRatio,
    required this.totalStaff,
    this.activeLoansCount = 0,
    this.avgLoanAmount = 0,
    this.savingsAccountsCount = 0,
    this.totalSavings = 0,
    this.avgSavings = 0,
    this.newAccountsMonth = 0,
    this.financialProductsAmount = 0,
    this.operationalExpensesAmount = 0,
    this.netResultAmount = 0,
    this.managerName = '',
    this.loanOfficersCount = 0,
    this.cashiersCount = 0,
    this.backOfficeCount = 0,
  });
}

class AgencyTeam {
  final String managerName;
  final int loanOfficersCount;
  final int cashiersCount;
  final int backOfficeCount;

  AgencyTeam({
    required this.managerName,
    required this.loanOfficersCount,
    required this.cashiersCount,
    required this.backOfficeCount,
  });
}
