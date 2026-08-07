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

  static Future<String> saveToDownloads(String sourcePath) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = 'TourDirectorFilm_$ts.mp4';

    if (Platform.isAndroid) {
      // Android 13+ (API 33+): register the file with MediaStore so it shows up
      // in Files/Gallery apps WITHOUT needing the restricted
      // MANAGE_EXTERNAL_STORAGE ("All files access") permission.
      final result = await SaverGallery.saveFile(
        filePath: sourcePath,
        fileName: name,
        androidRelativePath: 'Download',
        skipIfExists: false,
      );
      if (!result.isSuccess) {
        throw VideoGenerationException(
          type: VideoGenerationError.unknown,
          rawMessage: result.errorMessage ?? 'saver_gallery save failed',
          userMessage:
              'Could not save the film to your device. '
              '${result.errorMessage ?? ''}'.trim(),
        );
      }
      debugPrint('[AIFilm] [Stitch] saved to MediaStore Download/$name');
      // MediaStore doesn't return a File()-readable path, so keep playing and
      // sharing from the readable stitched file in app storage.
      return sourcePath;
    }

    // Other platforms: copy into app documents and return that path.
    final dir = await getApplicationDocumentsDirectory();
    final destPath = '${dir.path}/$name';
    await File(sourcePath).copy(destPath);
    debugPrint('[AIFilm] [Stitch] saved to: $destPath');
    return destPath;
  }
}
