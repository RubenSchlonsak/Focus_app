class SessionMarker {
  final int timestampMs;
  final int surfaceIndex;
  final String surfaceName;
  final bool isCorrection;

  const SessionMarker({
    required this.timestampMs,
    required this.surfaceIndex,
    required this.surfaceName,
    this.isCorrection = false,
  });

  String get timeLabel {
    final s = timestampMs ~/ 1000;
    final ms = timestampMs % 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${(ms ~/ 100)}';
  }

  Map<String, dynamic> toJson() => {
        'timestamp_ms': timestampMs,
        'surface_index': surfaceIndex,
        'surface_name': surfaceName,
        'is_correction': isCorrection,
      };

  factory SessionMarker.fromJson(Map<String, dynamic> j) => SessionMarker(
        timestampMs: (j['timestamp_ms'] as num).toInt(),
        surfaceIndex: (j['surface_index'] as num).toInt(),
        surfaceName: j['surface_name'] as String,
        isCorrection: j['is_correction'] as bool? ?? false,
      );
}
