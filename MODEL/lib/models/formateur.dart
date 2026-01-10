class Formateur {
  final String id;
  final String name;
  final String speciality;
  final double hourlyRate;
  final String avatar; // existing
  final String photo; // synonym/explicit
  final String email;
  final String phone;
  final String address;

  Formateur({
    required this.id,
    required this.name,
    required this.speciality,
    required this.hourlyRate,
    this.avatar = '',
    this.photo = '',
    this.email = '',
    this.phone = '',
    this.address = '',
  });

  Map<String, dynamic> toMap(String formationId) {
    return {
      'id': id,
      'formationId': formationId,
      'name': name,
      'speciality': speciality,
      'hourlyRate': hourlyRate,
      'avatar': avatar,
      'photo': photo,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }

  factory Formateur.fromMap(Map<String, dynamic> m) {
    // accept both 'photo' and legacy 'avatar'
    final avatarVal = (m['avatar'] as String?) ?? (m['photo'] as String?) ?? '';
    return Formateur(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      speciality: m['speciality'] as String? ?? '',
      hourlyRate: (m['hourlyRate'] as num?)?.toDouble() ?? 0.0,
      avatar: avatarVal,
      photo: (m['photo'] as String?) ?? avatarVal,
      email: m['email'] as String? ?? '',
      phone: m['phone'] as String? ?? '',
      address: m['address'] as String? ?? '',
    );
  }
}