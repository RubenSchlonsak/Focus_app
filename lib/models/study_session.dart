import 'subject.dart';
import 'session_marker.dart';

class StudySession {
  final String sessionId;
  final String directoryPath;
  final DateTime startTime;
  final int durationMs;
  final Subject subject;
  final List<String> surfaces;
  final List<SessionMarker> markers;
  final int imuSampleCount;
  final int audioSampleCount;
  final int imuRateHz;
  final int audioSampleRate;

  const StudySession({
    required this.sessionId,
    required this.directoryPath,
    required this.startTime,
    required this.durationMs,
    required this.subject,
    required this.surfaces,
    required this.markers,
    required this.imuSampleCount,
    required this.audioSampleCount,
    required this.imuRateHz,
    required this.audioSampleRate,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  String get displayName {
    final parts = directoryPath.replaceAll('\\', '/').split('/');
    final last = parts.last;
    return last.isNotEmpty ? last : sessionId;
  }

  String get folderName {
    final parts = directoryPath.replaceAll('\\', '/').split('/');
    return parts.length >= 2 ? parts[parts.length - 2] : '';
  }

  String get durationLabel {
    final t = duration;
    final m = t.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = t.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${t.inHours > 0 ? '${t.inHours}h ' : ''}$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'start_time': startTime.toIso8601String(),
        'duration_ms': durationMs,
        'subject': subject.toJson(),
        'device_config': {
          'imu_rate_hz': imuRateHz,
          'audio_sample_rate': audioSampleRate,
        },
        'surfaces': surfaces,
        'markers': markers.map((m) => m.toJson()).toList(),
        'imu_sample_count': imuSampleCount,
        'audio_sample_count': audioSampleCount,
      };

  factory StudySession.fromJson(Map<String, dynamic> j, String dirPath) {
    final cfg = j['device_config'] as Map<String, dynamic>? ?? {};
    final markersJson = j['markers'] as List<dynamic>? ?? [];
    return StudySession(
      sessionId: j['session_id'] as String,
      directoryPath: dirPath,
      startTime: DateTime.parse(j['start_time'] as String),
      durationMs: (j['duration_ms'] as num).toInt(),
      subject: Subject.fromJson(j['subject'] as Map<String, dynamic>),
      surfaces: (j['surfaces'] as List<dynamic>).cast<String>(),
      markers: markersJson
          .map((m) => SessionMarker.fromJson(m as Map<String, dynamic>))
          .toList(),
      imuSampleCount: (j['imu_sample_count'] as num).toInt(),
      audioSampleCount: (j['audio_sample_count'] as num).toInt(),
      imuRateHz: (cfg['imu_rate_hz'] as num? ?? 104).toInt(),
      audioSampleRate: (cfg['audio_sample_rate'] as num? ?? 16000).toInt(),
    );
  }
}
