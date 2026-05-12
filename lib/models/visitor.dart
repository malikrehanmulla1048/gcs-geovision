class Visitor {
  final int? id;
  final String name;
  final String phone;
  final String purpose;
  final String host;
  final String dept;
  final String idnum;
  String status; // 'On Campus' | 'Checking In' | 'Exited'
  final String gate;
  final DateTime checkinAt;
  final double? lat;
  final double? lng;

  Visitor({
    this.id,
    required this.name,
    required this.phone,
    required this.purpose,
    required this.host,
    required this.dept,
    required this.idnum,
    required this.status,
    required this.gate,
    required this.checkinAt,
    this.lat,
    this.lng,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (name.isNotEmpty) return name[0].toUpperCase();
    return 'VX';
  }

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'name':      name,
    'phone':     phone,
    'purpose':   purpose,
    'host':      host,
    'dept':      dept,
    'idnum':     idnum,
    'status':    status,
    'gate':      gate,
    'checkinAt': checkinAt.toIso8601String(),
    'lat':       lat,
    'lng':       lng,
  };

  factory Visitor.fromMap(Map<String, dynamic> m) => Visitor(
    id:        m['id'] as int?,
    name:      m['name'] as String,
    phone:     m['phone'] as String,
    purpose:   m['purpose'] as String,
    host:      m['host'] as String,
    dept:      m['dept'] as String? ?? '—',
    idnum:     m['idnum'] as String,
    status:    m['status'] as String,
    gate:      m['gate'] as String,
    checkinAt: DateTime.parse(m['checkinAt'] as String),
    lat:       (m['lat'] as num?)?.toDouble(),
    lng:       (m['lng'] as num?)?.toDouble(),
  );
}
