import 'package:flutter_test/flutter_test.dart';
import 'package:echo_loop/services/tts/piper_voices.dart';
import 'package:echo_loop/services/tts/tts_engine.dart';

void main() {
  group('piperVoices 目录', () {
    test('共 9 个音色：6 美音 + 3 英音', () {
      expect(piperVoices.length, 9);
      expect(piperVoicesByAccent(TtsAccent.us).length, 6);
      expect(piperVoicesByAccent(TtsAccent.uk).length, 3);
    });

    test('id 唯一', () {
      final ids = piperVoices.map((v) => v.id).toSet();
      expect(ids.length, 9);
    });

    test('归档路径以 .tar.gz 结尾（extractFileToDisk 据扩展名识别）', () {
      for (final v in piperVoices) {
        expect(v.archivePath.endsWith('.tar.gz'), isTrue, reason: v.id);
      }
    });

    test('口音与 id 前缀一致：en_US=美音 en_GB=英音', () {
      for (final v in piperVoices) {
        if (v.id.startsWith('en_US')) {
          expect(v.accent, TtsAccent.us, reason: v.id);
        } else if (v.id.startsWith('en_GB')) {
          expect(v.accent, TtsAccent.uk, reason: v.id);
        }
      }
    });
  });

  group('piperVoiceById', () {
    test('已知 id 往返', () {
      final v = piperVoiceById(piperDefaultVoiceUs);
      expect(v, isNotNull);
      expect(v!.id, piperDefaultVoiceUs);
    });

    test('未知 id 返回 null', () {
      expect(piperVoiceById('not_a_voice'), isNull);
    });
  });

  group('piperDefaultVoice', () {
    test('美音默认属于美音', () {
      final v = piperDefaultVoice(TtsAccent.us);
      expect(v.id, piperDefaultVoiceUs);
      expect(v.accent, TtsAccent.us);
    });

    test('英音默认属于英音', () {
      final v = piperDefaultVoice(TtsAccent.uk);
      expect(v.id, piperDefaultVoiceUk);
      expect(v.accent, TtsAccent.uk);
    });
  });
}
