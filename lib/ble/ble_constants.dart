class BleConstants {
  static const String targetDeviceName = 'FOCUS-Sense';
  static const String serviceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  // Update the first 3 UUID groups once you know the device's full UUIDs.
  // The spec guarantees the suffix: …-b7f5-ea07361b26xx
  static const String imuCharUuid    = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const String audioCharUuid  = 'beb5483e-36e1-4688-b7f5-ea07361b26a9';
  static const String cmdCharUuid    = 'beb5483e-36e1-4688-b7f5-ea07361b26aa';
  static const String cfgCharUuid    = 'beb5483e-36e1-4688-b7f5-ea07361b26ab';
  static const String statusCharUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26ac';
  static const String infoCharUuid   = 'beb5483e-36e1-4688-b7f5-ea07361b26ad';

  static const int targetMtu = 247;

  // CFG ids
  static const int cfgAudioGain   = 0x10;
  static const int cfgAudioRate   = 0x11;
  static const int cfgImuRate     = 0x20;
  static const int cfgAccelRange  = 0x21;
  static const int cfgGyroRange   = 0x22;

  // Lookup tables (index → label)
  static const List<int>    imuRates    = [13, 26, 52, 104, 208];
  static const List<String> accelRanges = ['±2 g', '±4 g', '±8 g', '±16 g'];
  static const List<String> gyroRanges  = ['±125 dps', '±245 dps', '±500 dps', '±1000 dps', '±2000 dps'];
  static const List<String> audioRates  = ['8 kHz', '16 kHz'];
}
