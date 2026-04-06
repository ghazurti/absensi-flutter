class UserModel {
  final int id;
  final String name;
  final String email;
  final String? nip;
  final String? noHp;
  final String? jabatan;
  final String? unit;
  final String role;
  final String? foto;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.nip,
    this.noHp,
    this.jabatan,
    this.unit,
    required this.role,
    this.foto,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      nip: json['nip'],
      noHp: json['no_hp'],
      jabatan: json['jabatan'],
      unit: json['unit'],
      role: json['role'] ?? 'pegawai',
      foto: json['foto'],
    );
  }

  bool get isAdmin => role == 'admin';
}
