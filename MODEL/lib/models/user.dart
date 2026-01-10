
import 'dart:convert'; // Required for jsonEncode/jsonDecode
import 'package:flutter/material.dart'; // Required for IconData, Color, etc. if used in models

// Models
class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? passwordHash; // New field for password hash
  final List<Permission> permissions;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isActive;
  final bool mustChangePassword;
  final bool is2faEnabled;
  final String? twoFaSecret;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.passwordHash, // Make it optional for now
    this.permissions = const [],
    required this.createdAt,
    required this.lastLogin,
    this.isActive = true,
    this.mustChangePassword = false,
    this.is2faEnabled = false,
    this.twoFaSecret,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.index, // Store enum as int
      'passwordHash': passwordHash, // Add passwordHash
      'permissions': jsonEncode(permissions.map((p) => p.toMap()).toList()), // Convert list of Permission to JSON string
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastLogin': lastLogin.millisecondsSinceEpoch,
      'isActive': isActive ? 1 : 0,
      'mustChangePassword': mustChangePassword ? 1 : 0,
      'is2faEnabled': is2faEnabled ? 1 : 0,
      'twoFaSecret': twoFaSecret,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: UserRole.values[map['role'] as int], // Convert int back to enum
      passwordHash: map['passwordHash'] as String?, // Add passwordHash
      permissions: (map['permissions'] != null && map['permissions'] is String)
              ? (jsonDecode(map['permissions'] as String) as List<dynamic>)
                  .map((p) => Permission.fromMap(p as Map<String, dynamic>))
                  .toList()
              : const [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      lastLogin: DateTime.fromMillisecondsSinceEpoch(map['lastLogin'] as int),
      isActive: (map['isActive'] as int) == 1,
      mustChangePassword: (map['mustChangePassword'] as int? ?? 0) == 1,
      is2faEnabled: (map['is2faEnabled'] as int? ?? 0) == 1,
      twoFaSecret: map['twoFaSecret'] as String?,
    );
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    String? passwordHash, // Add passwordHash
    List<Permission>? permissions,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? isActive,
    bool? mustChangePassword,
    bool? is2faEnabled,
    String? twoFaSecret,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash, // Add passwordHash
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      isActive: isActive ?? this.isActive,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      is2faEnabled: is2faEnabled ?? this.is2faEnabled,
      twoFaSecret: twoFaSecret ?? this.twoFaSecret,
    );
  }
}

enum UserRole { admin, comptable, commercial, secretaire }

class Permission {
  final String module;
  final List<String> actions; // create, read, update, delete

  Permission({required this.module, required this.actions});

  Map<String, dynamic> toMap() {
    return {
      'module': module,
      'actions': actions, // Store list of strings directly
    };
  }

  factory Permission.fromMap(Map<String, dynamic> map) {
    return Permission(
      module: map['module'] as String,
      actions: (map['actions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );
  }
}

class AuditLog {
  final String id;
  final String userId;
  final String userName;
  final String action;
  final String module;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  AuditLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.action,
    required this.module,
    required this.timestamp,
    this.details = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'action': action,
      'module': module,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'details': jsonEncode(details), // Encode map to JSON string
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      action: map['action'] as String,
      module: map['module'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      details: (map['details'] != null && map['details'] is String)
          ? jsonDecode(map['details'] as String) as Map<String, dynamic>
          : const {}, // Decode JSON string to map
    );
  }
}
