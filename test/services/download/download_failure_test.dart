import 'dart:io' show FileSystemException, OSError;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echo_loop/services/download/download_failure.dart';

void main() {
  group('classifyDownloadFailure', () {
    test('FileSystemException errno 28 → insufficientStorage', () {
      final e = const FileSystemException(
        'writeFrom failed',
        '/tmp/temp.tar',
        OSError('No space left on device', 28),
      );
      expect(
        classifyDownloadFailure(e),
        DownloadFailureKind.insufficientStorage,
      );
    });

    test('异常文案含 errno = 28 → insufficientStorage（无 OSError 也兜住）', () {
      expect(
        classifyDownloadFailure(Exception('OS Error: ... errno = 28')),
        DownloadFailureKind.insufficientStorage,
      );
    });

    test('DioException（非取消）→ network', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionTimeout,
      );
      expect(classifyDownloadFailure(e), DownloadFailureKind.network);
    });

    test('SHA 不匹配 → verification', () {
      expect(
        classifyDownloadFailure(StateError('archive SHA-256 mismatch')),
        DownloadFailureKind.verification,
      );
    });

    test('解包后关键文件缺失 → verification', () {
      expect(
        classifyDownloadFailure(StateError('key files missing after extract')),
        DownloadFailureKind.verification,
      );
    });

    test('其它异常 → unknown', () {
      expect(
        classifyDownloadFailure(StateError('something else')),
        DownloadFailureKind.unknown,
      );
    });
  });
}
