import 'package:universal_io/io.dart';
import 'package:subtitle/subtitle.dart';
import '../models/sentence.dart';

/// 字幕解析错误类型。
///
/// - [unsupportedFormat]：扩展名不在 srt/vtt 白名单（例如 .lrc、.ass、.txt）。
/// - [formatInvalid]：扩展名匹配但内容无法解析（损坏、二进制、不是 SRT/VTT 时间戳）。
/// - [empty]：解析成功但没有任何字幕条目（空文件、仅 WEBVTT 头、全 NOTE 块）。
enum SubtitleParseErrorKind { unsupportedFormat, formatInvalid, empty }

/// 字幕解析异常。
///
/// 仅由 [SubtitleParser.parseSubtitleStrict] 抛出。[detail] 对
/// [SubtitleParseErrorKind.unsupportedFormat] 表示实际扩展名（不含点），用于 UI 显示。
class SubtitleParseException implements Exception {
  final SubtitleParseErrorKind kind;
  final String? detail;
  const SubtitleParseException(this.kind, [this.detail]);

  @override
  String toString() =>
      'SubtitleParseException(kind: $kind${detail != null ? ', detail: $detail' : ''})';
}

class SubtitleParser {
  /// 解析字幕文件，失败时静默返回空列表。
  ///
  /// 用于加载用户已上传过的字幕（即已通过 [parseSubtitleStrict] 校验）。
  /// 容错性高，避免运行期因字幕异常导致 app 崩溃。
  static Future<List<Sentence>> parseSubtitle(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      final controller = SubtitleController(
        provider: SubtitleProvider.fromString(
          data: content,
          type: _getSubtitleType(filePath),
        ),
      );

      await controller.initial();
      final subtitles = controller.subtitles;

      return subtitles.asMap().entries.map((entry) {
        final subtitle = entry.value;
        return Sentence(
          index: entry.key,
          text: subtitle.data.trim(),
          startTime: subtitle.start,
          endTime: subtitle.end,
        );
      }).toList();
    } catch (e) {
      print('Error parsing subtitle: $e');
      return [];
    }
  }

  /// 严格解析字幕文件，区分扩展名错误、内容错误、空文件三种失败。
  ///
  /// 用于上传入口校验。校验失败抛 [SubtitleParseException]，由调用方决定提示。
  static Future<List<Sentence>> parseSubtitleStrict(String filePath) async {
    // 1. 扩展名白名单
    final ext = _extensionOf(filePath);
    if (ext != 'srt' && ext != 'vtt') {
      throw SubtitleParseException(
        SubtitleParseErrorKind.unsupportedFormat,
        ext,
      );
    }

    // 2. 读文件 + 调用解析器
    final List<Subtitle> subtitles;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw const SubtitleParseException(
          SubtitleParseErrorKind.formatInvalid,
          'file not found',
        );
      }
      final content = await file.readAsString();
      final controller = SubtitleController(
        provider: SubtitleProvider.fromString(
          data: content,
          type: ext == 'vtt' ? SubtitleType.vtt : SubtitleType.srt,
        ),
      );
      await controller.initial();
      subtitles = controller.subtitles;
    } on SubtitleParseException {
      rethrow;
    } catch (e) {
      throw SubtitleParseException(
        SubtitleParseErrorKind.formatInvalid,
        e.toString(),
      );
    }

    // 3. 空内容
    if (subtitles.isEmpty) {
      throw const SubtitleParseException(SubtitleParseErrorKind.empty);
    }

    return subtitles.asMap().entries.map((entry) {
      final subtitle = entry.value;
      return Sentence(
        index: entry.key,
        text: subtitle.data.trim(),
        startTime: subtitle.start,
        endTime: subtitle.end,
      );
    }).toList();
  }

  /// 提取文件扩展名（小写、不含点）。
  static String _extensionOf(String filePath) {
    final lastDot = filePath.lastIndexOf('.');
    if (lastDot < 0 || lastDot == filePath.length - 1) return '';
    return filePath.substring(lastDot + 1).toLowerCase();
  }

  static SubtitleType _getSubtitleType(String filePath) {
    switch (_extensionOf(filePath)) {
      case 'srt':
        return SubtitleType.srt;
      case 'vtt':
        return SubtitleType.vtt;
      default:
        return SubtitleType.srt; // default to SRT
    }
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '$minutes:${twoDigits(seconds)}';
  }
}
