import 'dart:typed_data';

const List<int> _stepTable = [
  7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41,
  45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209,
  230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876,
  963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024,
  3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493,
  10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086,
  29794, 32767,
];

const List<int> _indexTable = [
  -1, -1, -1, -1, 2, 4, 6, 8,
  -1, -1, -1, -1, 2, 4, 6, 8,
];

/// Decodes one IMA-ADPCM BLE audio packet into int16 PCM samples.
///
/// Packet layout (firmware):
///   [0..3]  uint32  t_us        — device timestamp (ignored)
///   [4..5]  int16   predictor   — ADPCM predictor state at packet start
///   [6]     uint8   step_index  — ADPCM step index at packet start
///   [7]     uint8   pad
///   [8..]   ADPCM nibbles, lo nibble = first sample, hi nibble = second
List<int> decodeAdpcmPacket(List<int> packet) {
  if (packet.length < 9) return const [];

  final bd = ByteData.sublistView(Uint8List.fromList(packet));
  int predictor = bd.getInt16(4, Endian.little);
  int stepIndex = packet[6].clamp(0, 88);

  final out = <int>[];

  void decodeNibble(int nibble) {
    final step = _stepTable[stepIndex];
    int delta = step >> 3;
    if (nibble & 4 != 0) delta += step;
    if (nibble & 2 != 0) delta += step >> 1;
    if (nibble & 1 != 0) delta += step >> 2;
    if (nibble & 8 != 0) delta = -delta;
    predictor = (predictor + delta).clamp(-32768, 32767);
    stepIndex = (stepIndex + _indexTable[nibble]).clamp(0, 88);
    out.add(predictor);
  }

  for (int i = 8; i < packet.length; i++) {
    decodeNibble(packet[i] & 0x0F);
    decodeNibble((packet[i] >> 4) & 0x0F);
  }
  return out;
}
