class UserModel {
  final int id;
  final String name;
  final String email;
  final String? nik;
  final String? nip;
  final String? noHp;
  final String? jabatan;
  final String? pangkatGol;
  final String? unit;
  final String jenisAbsensi;
  final String role;
  final String? foto;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.nik,
    this.nip,
    this.noHp,
    this.jabatan,
    this.pangkatGol,
    this.unit,
    this.jenisAbsensi = 'normal',
    required this.role,
    this.foto,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      nik: json['nik'],
      nip: json['nip'],
      noHp: json['no_hp'],
      jabatan: json['jabatan'],
      pangkatGol: json['pangkat_gol'],
      unit: json['unit'],
      jenisAbsensi: json['jenis_absensi'] ?? 'normal',
      role: json['role'] ?? 'pegawai',
      foto: json['foto'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'nik': nik,
        'nip': nip,
        'no_hp': noHp,
        'jabatan': jabatan,
        'pangkat_gol': pangkatGol,
        'unit': unit,
        'jenis_absensi': jenisAbsensi,
        'role': role,
        'foto': foto,
      };

  bool get isAdmin => role == 'admin';
  bool get isShift => jenisAbsensi == 'shift';
}
