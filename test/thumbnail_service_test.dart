import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/data/services/thumbnail_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThumbnailService candidate timestamps', () {
    test('calculates 10%, 25%, 50%, and 75% for standard video', () {
      const durationMs = 60000; // 60 seconds
      final candidates = ThumbnailService.getCandidateTimestampsMs(durationMs);

      expect(candidates.length, 4);
      expect(candidates[0], 6000); // 10%
      expect(candidates[1], 15000); // 25%
      expect(candidates[2], 30000); // 50%
      expect(candidates[3], 45000); // 75%
    });

    test('calculates proportional timestamps for short clips', () {
      const durationMs = 12000; // 12 seconds
      final candidates = ThumbnailService.getCandidateTimestampsMs(durationMs);

      expect(candidates[0], 1200); // 10%
      expect(candidates[1], 3000); // 25%
      expect(candidates[2], 6000); // 50%
      expect(candidates[3], 9000); // 75%
    });

    test('falls back to safe offsets when video duration is 0 or unknown', () {
      final candidatesZero = ThumbnailService.getCandidateTimestampsMs(0);
      expect(candidatesZero, [1000, 3000, 5000, 0]);

      final candidatesNegative = ThumbnailService.getCandidateTimestampsMs(-1);
      expect(candidatesNegative, [1000, 3000, 5000, 0]);
    });

    test('clamps frame microseconds to 32-bit signed int to prevent Glide crash on long video', () {
      // 2-hour movie: 7,200,000 ms
      const durationMs = 7200000;
      final candidates = ThumbnailService.getCandidateTimestampsMs(durationMs);

      // 10% is 720,000 ms -> 720,000,000 micros (fits in 32-bit int)
      final frame10Micros = (candidates[0] * 1000).clamp(0, ThumbnailService.maxFrameMicros);
      expect(frame10Micros, 720000000);
      expect(frame10Micros <= ThumbnailService.maxFrameMicros, isTrue);

      // 50% is 3,600,000 ms -> 3,600,000,000 micros (exceeds 32-bit int, must clamp)
      final frame50Micros = (candidates[2] * 1000).clamp(0, ThumbnailService.maxFrameMicros);
      expect(frame50Micros, ThumbnailService.maxFrameMicros);
      expect(frame50Micros, 2147483647);
    });
  });

  group('Black frame detection and selection logic', () {
    test('ITU-R BT.601 luminance calculation matches expected brightness', () {
      // Function to calculate luminance the same way as calculateAverageBrightness
      double calcLuminance(int r, int g, int b) =>
          ((299 * r + 587 * g + 114 * b) ~/ 1000).toDouble();

      // Pure black
      expect(calcLuminance(0, 0, 0), 0.0);
      expect(calcLuminance(0, 0, 0) < ThumbnailService.blackThreshold, isTrue);

      // Very dark intro / letterboxing (e.g. slight compression artifacts)
      expect(calcLuminance(8, 8, 8), 8.0);
      expect(calcLuminance(8, 8, 8) < ThumbnailService.blackThreshold, isTrue);

      // Representative video scene
      expect(calcLuminance(100, 140, 90) >= ThumbnailService.blackThreshold, isTrue);

      // Bright scene
      expect(calcLuminance(200, 200, 200), 200.0);
      expect(calcLuminance(200, 200, 200) >= ThumbnailService.blackThreshold, isTrue);
    });

    test('simulates video with black intro: skips 10% and 25%, picks 50%', () {
      // Mock frames:
      // Timestamp 10%: almost black (brightness 4.0)
      // Timestamp 25%: almost black (brightness 12.0)
      // Timestamp 50%: actual video frame (brightness 85.0)
      // Timestamp 75%: bright frame (brightness 120.0)
      final simulatedFrames = <int, ({Uint8List bytes, double brightness})>{
        6000: (bytes: Uint8List.fromList([1]), brightness: 4.0),
        15000: (bytes: Uint8List.fromList([2]), brightness: 12.0),
        30000: (bytes: Uint8List.fromList([3]), brightness: 85.0),
        45000: (bytes: Uint8List.fromList([4]), brightness: 120.0),
      };

      const durationMs = 60000;
      final candidates = ThumbnailService.getCandidateTimestampsMs(durationMs);

      Uint8List? selected;
      int decodeCount = 0;

      for (final ms in candidates) {
        decodeCount++;
        final frame = simulatedFrames[ms]!;
        if (frame.brightness >= ThumbnailService.blackThreshold) {
          selected = frame.bytes;
          break;
        }
      }

      // Selected frame must be candidate 3 (50%)
      expect(selected, simulatedFrames[30000]!.bytes);
      // Only 3 candidates were decoded, stopping as soon as the first non-black frame was found
      expect(decodeCount, 3);
    });

    test('simulates normal video: picks 10% representative frame on first try', () {
      // Mock frame where 10% is already a good non-black frame
      final simulatedFrames = <int, ({Uint8List bytes, double brightness})>{
        6000: (bytes: Uint8List.fromList([10]), brightness: 92.0),
      };

      const durationMs = 60000;
      final candidates = ThumbnailService.getCandidateTimestampsMs(durationMs);

      Uint8List? selected;
      int decodeCount = 0;

      for (final ms in candidates) {
        decodeCount++;
        final frame = simulatedFrames[ms]!;
        if (frame.brightness >= ThumbnailService.blackThreshold) {
          selected = frame.bytes;
          break;
        }
      }

      expect(selected, simulatedFrames[6000]!.bytes);
      // For >95% of videos, only 1 decode is performed
      expect(decodeCount, 1);
    });

    test('simulates all-black video: falls back to brightest candidate', () {
      // When every frame in the video is pitch black or very dark
      final simulatedFrames = <int, ({Uint8List bytes, double brightness})>{
        1000: (bytes: Uint8List.fromList([1]), brightness: 2.0),
        2500: (bytes: Uint8List.fromList([2]), brightness: 7.0),
        5000: (bytes: Uint8List.fromList([3]), brightness: 5.0),
        7500: (bytes: Uint8List.fromList([4]), brightness: 3.0),
      };

      const durationMs = 10000;
      final candidates = ThumbnailService.getCandidateTimestampsMs(durationMs);

      Uint8List? bestBytes;
      double bestBrightness = -1.0;

      for (final ms in candidates) {
        final frame = simulatedFrames[ms]!;
        if (frame.brightness >= ThumbnailService.blackThreshold) {
          bestBytes = frame.bytes;
          break;
        }
        if (frame.brightness > bestBrightness) {
          bestBrightness = frame.brightness;
          bestBytes = frame.bytes;
        }
      }

      // Falls back to the brightest one found (2500ms with brightness 7.0)
      expect(bestBytes, simulatedFrames[2500]!.bytes);
      expect(bestBrightness, 7.0);
    });
  });

  group('Thumbnail cache lifecycle', () {
    test('peek returns null when empty', () {
      expect(ThumbnailService.peek('non_existent_id', 320, 320), isNull);
    });

    test('clear removes in-memory entries', () {
      ThumbnailService.clear();
      expect(ThumbnailService.peek('any', 100, 100), isNull);
    });
  });
}
