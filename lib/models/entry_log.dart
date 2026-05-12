class EntryLog {
  final int? id;
  final String userId;
  final String name;
  final String gate;
  final String type; // 'entry' | 'exit' | 'denied'
  final DateTime timestamp;
  final double? confidence;
  final String? dept;
  final String? initials;
  final String? color; // gradient colors CSV

  const EntryLog({
    this.id,
    required this.userId,
    required this.name,
    required this.gate,
    required this.type,
    required this.timestamp,
    this.confidence,
    this.dept,
    this.initials,
    this.color,
  });

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'userId':     userId,
    'name':       name,
    'gate':       gate,
    'type':       type,
    'timestamp':  timestamp.toIso8601String(),
    'confidence': confidence,
    'dept':       dept,
    'initials':   initials,
    'color':      color,
  };

  factory EntryLog.fromMap(Map<String, dynamic> m) => EntryLog(
    id:         m['id'] as int?,
    userId:     m['userId'] as String,
    name:       m['name'] as String,
    gate:       m['gate'] as String,
    type:       m['type'] as String,
    timestamp:  DateTime.parse(m['timestamp'] as String),
    confidence: (m['confidence'] as num?)?.toDouble(),
    dept:       m['dept'] as String?,
    initials:   m['initials'] as String?,
    color:      m['color'] as String?,
  );

  String get typeLabel {
    switch (type) {
      case 'entry':  return '→ Entry';
      case 'exit':   return '← Exit';
      case 'denied': return '🚫 Denied';
      default:       return type;
    }
  }
}
