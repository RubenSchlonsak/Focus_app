class InfoData {
  // Parsed from INFO characteristic (11 bytes, little-endian):
  // [0]   flags       uint8   bit0=imuOn, bit1=audioOn, bit2=imuOk
  // [1]   audioGain   uint8
  // [2-5] audioRateHz uint32
  // [6-7] imuRateHz   uint16
  // [8]   accelRangeG uint8
  // [9-10] gyroRangeDps uint16
  final int flags;
  final int audioGain;
  final int audioRateHz;
  final int imuRateHz;
  final int accelRangeG;
  final int gyroRangeDps;

  const InfoData({
    required this.flags,
    required this.audioGain,
    required this.audioRateHz,
    required this.imuRateHz,
    required this.accelRangeG,
    required this.gyroRangeDps,
  });

  bool get imuActive   => (flags & 0x01) != 0;
  bool get audioActive => (flags & 0x02) != 0;
  bool get imuOk       => (flags & 0x04) != 0;

  String get audioRateStr {
    if (audioRateHz >= 1000) return '${audioRateHz ~/ 1000} kHz';
    return '$audioRateHz Hz';
  }

  String get imuRateStr    => '$imuRateHz Hz';
  String get accelRangeStr => '±$accelRangeG g';
  String get gyroRangeStr  => '±$gyroRangeDps dps';
}
