import '../ble/ble_constants.dart';

class StatusData {
  final int flags;
  final int audioGain;
  final int audioRateIdx;
  final int imuRateIdx;
  final int accelIdx;
  final int gyroIdx;
  final int audioDrops; // byte 6: audioDropCount & 0xFF

  const StatusData({
    required this.flags,
    required this.audioGain,
    required this.audioRateIdx,
    required this.imuRateIdx,
    required this.accelIdx,
    required this.gyroIdx,
    required this.audioDrops,
  });

  bool get imuActive   => (flags & 0x01) != 0;
  bool get audioActive => (flags & 0x02) != 0;
  bool get imuOk       => (flags & 0x04) != 0;
  int  get streamFlags => flags & 0x03;

  String get imuRateStr =>
      imuRateIdx < BleConstants.imuRates.length ? '${BleConstants.imuRates[imuRateIdx]} Hz' : '?';

  String get audioRateStr =>
      audioRateIdx < BleConstants.audioRates.length ? BleConstants.audioRates[audioRateIdx] : '?';

  String get accelRangeStr =>
      accelIdx < BleConstants.accelRanges.length ? BleConstants.accelRanges[accelIdx] : '?';

  String get gyroRangeStr =>
      gyroIdx < BleConstants.gyroRanges.length ? BleConstants.gyroRanges[gyroIdx] : '?';
}
