class UserModel {
  final String email;
  final String password;
  final String role; // 'admin' | 'student'
  final String name;
  final String? studentId;
  final String? phone;
  final String? dept;
  final String? year;
  final bool faceEnrolled;
  final String? pfp; // base64 image or file path
  final DateTime? joinedAt;

  const UserModel({
    required this.email,
    required this.password,
    required this.role,
    required this.name,
    this.studentId,
    this.phone,
    this.dept,
    this.year,
    this.faceEnrolled = false,
    this.pfp,
    this.joinedAt,
  });

  bool get isAdmin => role == 'admin';

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'U';
  }

  Map<String, dynamic> toMap() => {
    'email': email,
    'password': password,
    'role': role,
    'name': name,
    'studentId': studentId,
    'phone': phone,
    'dept': dept,
    'year': year,
    'faceEnrolled': faceEnrolled ? 1 : 0,
    'pfp': pfp,
    'joinedAt': joinedAt?.toIso8601String(),
  };

  factory UserModel.fromMap(Map<String, dynamic> m) => UserModel(
    email:        m['email'] as String,
    password:     m['password'] as String,
    role:         m['role'] as String,
    name:         m['name'] as String,
    studentId:    m['studentId'] as String?,
    phone:        m['phone'] as String?,
    dept:         m['dept'] as String?,
    year:         m['year'] as String?,
    faceEnrolled: (m['faceEnrolled'] as int? ?? 0) == 1,
    pfp:          m['pfp'] as String?,
    joinedAt:     m['joinedAt'] != null ? DateTime.tryParse(m['joinedAt']) : null,
  );

  UserModel copyWith({
    String? name, String? phone, String? dept, String? year,
    bool? faceEnrolled, String? pfp,
  }) => UserModel(
    email: email, password: password, role: role,
    name: name ?? this.name,
    studentId: studentId,
    phone: phone ?? this.phone,
    dept: dept ?? this.dept,
    year: year ?? this.year,
    faceEnrolled: faceEnrolled ?? this.faceEnrolled,
    pfp: pfp ?? this.pfp,
    joinedAt: joinedAt,
  );
}
