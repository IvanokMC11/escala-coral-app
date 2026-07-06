class Member {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String role;
  final bool isActive;
  final String? createdAt;

  Member({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.role,
    this.isActive = true,
    this.createdAt,
  });

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        role: json['role'] ?? 'member',
        isActive: (json['is_active'] ?? 1) == 1,
        createdAt: json['created_at'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
      };

  bool get isAdmin => role == 'admin';
}
