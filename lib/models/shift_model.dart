class ShiftModel {
  final int id;
  final int userId;
  final DateTime tanggal;
  final String jenisShift;
  final String jamMasuk;
  final String jamKeluar;
  final String? keterangan;

  ShiftModel({
    required this.id,
    required this.userId,
    required this.tanggal,
    required this.jenisShift,
    required this.jamMasuk,
    required this.jamKeluar,
    this.keterangan,
  });

  factory ShiftModel.fromJson(Map<String, dynamic> json) {
    return ShiftModel(
      id: json['id'],
      userId: json['user_id'],
      tanggal: DateTime.parse(json['tanggal']),
      jenisShift: json['jenis_shift'],
      jamMasuk: json['jam_masuk'],
      jamKeluar: json['jam_keluar'],
      keterangan: json['keterangan'],
    );
  }

  String get labelShift {
    switch (jenisShift) {
      case 'pagi':
        return 'Pagi';
      case 'siang':
        return 'Siang';
      case 'malam':
        return 'Malam';
      default:
        return jenisShift;
    }
  }
}
