import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../../models/video_generation_result.dart';

class VideoStitcher {
  const VideoStitcher._();

  static final Dio _dio = Dio();

  static Future<String> stitch({
    required List<String> inputPaths,
    required String outputPath,
    required void Function(String) onProgress,
  }) async {
    debugPrint(
      '[AIFilm] [Stitch] stitching ${inputPaths.length} clips → '
      '$outputPath',
    );
    onProgress('Stitching ${inputPaths.length} clips...');

    final tempDir = await getTemporaryDirectory();
    final filmDir = Directory('${tempDir.path}/ai_film');
    if (!await filmDir.exists()) await filmDir.create(recursive: true);
    await Directory(File(outputPath).parent.path).create(recursive: true);

    final listFile = File(
      '${filmDir.path}/concat_${DateTime.now().millisecondsSinceEpoch}.txt',
    );
    final buffer = StringBuffer();
    for (final p in inputPaths) {
      buffer.writeln("file '${p.replaceAll("'", r"'\''")}'");
    }
    await listFile.writeAsString(buffer.toString());

    final cmd =
        "-f concat -safe 0 -i '${listFile.path}' -c copy -y '$outputPath'";
    final session = await FFmpegKit.execute(cmd);
    final returnCode = await session.getReturnCode();
    debugPrint(
      '[AIFilm] [Stitch] FFmpeg return code: '
      '${returnCode?.getValue()}',
    );
    try {
      await listFile.delete();
    } catch (_) {}

    if (!ReturnCode.isSuccess(returnCode)) {
      throw VideoGenerationException(
        type: VideoGenerationError.stitchFailed,
        rawMessage: 'ffmpeg return code ${returnCode?.getValue()}',
        userMessage:
            'Failed to stitch video clips. FFmpeg error: '
            '${returnCode?.getValue()}',
      );
    }
    return outputPath;
  }

  /// Download [url] to `{temp}/ai_film/{filename}` and return the local path.
  static Future<String> downloadClip({
    required String url,
    required String filename,
    required void Function(double progress) onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filmDir = Directory('${tempDir.path}/ai_film');
      if (!await filmDir.exists()) await filmDir.create(recursive: true);
      final path = '${filmDir.path}/$filename';
      debugPrint('[AIFilm] [Download] $url → $filename');
      await _dio.download(
        url,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress(received / total);
        },
      );
      return path;
    } catch (e) {
      debugPrint('[AIFilm] [Download] failed: $e');
      throw VideoGenerationException(
        type: VideoGenerationError.downloadFailed,
        rawMessage: e.toString(),
        userMessage:
            'Failed to download a generated clip. Check your connection and '
            'try again.',
      );
    }
  }

  /// Delete each temp clip, ignoring errors.
  static Future<void> cleanupTempClips(List<String> paths) async {
    for (final path in paths) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  /// Persists the finished film and returns a File()-readable path for playback
  /// and sharing. On Android it also best-effort exports to the Gallery; if that
  /// fails the film is kept in app storage, so saving never loses it.
  static Future<String> saveToDownloads(String sourcePath) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = 'TourDirectorFilm_$ts.mp4';

    if (Platform.isAndroid) {
      // MediaStore's Video collection only accepts RELATIVE_PATH under Movies/
      // (Download throws on Android 13+), so we export under Movies/TourDirector.
      // Wrapped defensively: a failure must not lose the app-storage copy below.
      try {
        final result = await SaverGallery.saveFile(
          filePath: sourcePath,
          fileName: name,
          androidRelativePath: 'Movies/TourDirector',
          skipIfExists: false,
        );
        debugPrint(
          result.isSuccess
              ? '[AIFilm] [Stitch] exported to Movies/TourDirector/$name'
              : '[AIFilm] [Stitch] MediaStore export failed '
                    '(${result.errorMessage}); keeping app-storage copy',
        );
      } catch (e) {
        debugPrint(
          '[AIFilm] [Stitch] MediaStore export threw ($e); '
          'keeping app-storage copy',
        );
      }
    }

    // Always keep a readable app-storage copy for playback + sharing.
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/$name';
    await File(sourcePath).copy(destPath);
    debugPrint('[AIFilm] [Stitch] saved app-storage copy: $destPath');
    return destPath;
  }
}
