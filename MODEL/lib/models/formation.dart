import 'formateur.dart';
import 'session.dart';
import 'dart:convert';

class Formation {
  final String id;
  final String title;
  final String description;
  final String duration;
  final double price;
  final String imageUrl;
  final String category;
  final String level;
  final bool isActive;
  final String objectives;
  final String prerequisites;
  final List<String> pedagogicalDocuments;
  final List<Formateur> formateurs;
  final List<Session> sessions;
  final int enrolledStudents;
  final double revenue;
  final double directCosts;
  final double indirectCosts;

  Formation({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.level,
    this.isActive = true,
    this.objectives = '',
    this.prerequisites = '',
    this.pedagogicalDocuments = const [],
    this.formateurs = const [],
    this.sessions = const [],
    this.enrolledStudents = 0,
    this.revenue = 0,
    this.directCosts = 0,
    this.indirectCosts = 0,
  });

  double get margin => revenue - (directCosts + indirectCosts);
  double get marginPercentage => revenue > 0 ? (margin / revenue) * 100 : 0;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'duration': duration,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'level': level,
      'isActive': isActive ? 1 : 0,
      'objectives': objectives,
      'prerequisites': prerequisites,
      'pedagogicalDocuments': jsonEncode(pedagogicalDocuments),
      'enrolledStudents': enrolledStudents,
      'revenue': revenue,
      'directCosts': directCosts,
      'indirectCosts': indirectCosts,
    };
  }

  factory Formation.fromMap(Map<String, dynamic> m, {List<Formateur>? formateurs, List<Session>? sessions}) {
    return Formation(
      id: m['id'] as String,
      title: m['title'] as String? ?? '',
      description: m['description'] as String? ?? '',
      duration: m['duration'] as String? ?? '',
      price: (m['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: m['imageUrl'] as String? ?? '',
      category: m['category'] as String? ?? '',
      level: m['level'] as String? ?? '',
      isActive: (m['isActive'] as int?) == 1,
      objectives: m['objectives'] as String? ?? '',
      prerequisites: m['prerequisites'] as String? ?? '',
      pedagogicalDocuments: (m['pedagogicalDocuments'] != null) ? List<String>.from(jsonDecode(m['pedagogicalDocuments'] as String)) : const [],
      formateurs: formateurs ?? const [],
      sessions: sessions ?? const [],
      enrolledStudents: (m['enrolledStudents'] as num?)?.toInt() ?? 0,
      revenue: (m['revenue'] as num?)?.toDouble() ?? 0.0,
      directCosts: (m['directCosts'] as num?)?.toDouble() ?? 0.0,
      indirectCosts: (m['indirectCosts'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Formation copyWith({
    String? id,
    String? title,
    String? description,
    String? duration,
    double? price,
    String? imageUrl,
    String? category,
    String? level,
    bool? isActive,
    String? objectives,
    String? prerequisites,
    List<String>? pedagogicalDocuments,
    List<Formateur>? formateurs,
    List<Session>? sessions,
    int? enrolledStudents,
    double? revenue,
    double? directCosts,
    double? indirectCosts,
  }) {
    return Formation(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      duration: duration ?? this.duration,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      level: level ?? this.level,
      isActive: isActive ?? this.isActive,
      objectives: objectives ?? this.objectives,
      prerequisites: prerequisites ?? this.prerequisites,
      pedagogicalDocuments: pedagogicalDocuments ?? this.pedagogicalDocuments,
      formateurs: formateurs ?? this.formateurs,
      sessions: sessions ?? this.sessions,
      enrolledStudents: enrolledStudents ?? this.enrolledStudents,
      revenue: revenue ?? this.revenue,
      directCosts: directCosts ?? this.directCosts,
      indirectCosts: indirectCosts ?? this.indirectCosts,
    );
  }
}