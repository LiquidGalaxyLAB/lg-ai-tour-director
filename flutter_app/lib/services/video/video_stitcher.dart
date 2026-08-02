import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  static Future<String> saveToDownloads(String sourcePath) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = 'TourDirectorFilm_$ts.mp4';

    Directory? dir;
    if (Platform.isAndroid) {
      final status = await Permission.manageExternalStorage.request();
      if (!status.isGranted) {
        throw VideoGenerationException(
          type: VideoGenerationError.unknown,
          rawMessage: 'Permission denied',
          userMessage:
              'Storage permission is required to save the film to your '
              'Downloads folder. Please grant it in your device settings.',
        );
      }
      const downloads = '/storage/emulated/0/Download';
      if (await Directory(downloads).exists()) dir = Directory(downloads);
      dir ??= await getExternalStorageDirectory();
    }
    dir ??= await getApplicationDocumentsDirectory();

    final destPath = '${dir.path}/$name';
    await File(sourcePath).copy(destPath);
    debugPrint('[AIFilm] [Stitch] saved to: $destPath');
    return destPath;
  }
}
