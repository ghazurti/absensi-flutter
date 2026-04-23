class AbsensiModel {
  final int id;
  final int userId;
  final int? shiftId;
  final DateTime tanggal;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? fotoCheckIn;
  final String? fotoCheckOut;
  final double? latitudeIn;
  final double? longitudeIn;
  final String status;
  final String? keterangan;

  AbsensiModel({
    required this.id,
    required this.userId,
    this.shiftId,
    required this.tanggal,
    this.checkIn,
    this.checkOut,
    this.fotoCheckIn,
    this.fotoCheckOut,
    this.latitudeIn,
    this.longitudeIn,
    required this.status,
    this.keterangan,
  });

  static DateTime _parseUtc(String s) {
    if (!s.contains('Z') && !s.contains('+')) return DateTime.parse('${s}Z').toLocal();
    return DateTime.parse(s).toLocal();
  }

  factory AbsensiModel.fromJson(Map<String, dynamic> json) {
    return AbsensiModel(
      id: json['id'],
      userId: json['user_id'],
      shiftId: json['shift_id'],
      tanggal: _parseUtc(json['tanggal']),
      checkIn: json['check_in'] != null ? _parseUtc(json['check_in']) : null,
      checkOut: json['check_out'] != null ? _parseUtc(json['check_out']) : null,
      fotoCheckIn: json['foto_check_in'],
      fotoCheckOut: json['foto_check_out'],
      latitudeIn: json['latitude_in'] != null ? double.tryParse(json['latitude_in'].toString()) : null,
      longitudeIn: json['longitude_in'] != null ? double.tryParse(json['longitude_in'].toString()) : null,
      status: json['status'] ?? 'hadir',
      keterangan: json['keterangan'],
    );
  }

  bool get sudahCheckIn => checkIn != null;
  bool get sudahCheckOut => checkOut != null;
}
