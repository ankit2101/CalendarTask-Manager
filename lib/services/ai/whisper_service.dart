import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../recording/recording_service.dart';

enum WhisperModel {
  tiny('tiny', 'ggml-tiny.bin', 74),
  base('base', 'ggml-base.bin', 142),
  small('small', 'ggml-small.bin', 466),
  medium('medium', 'ggml-medium.bin', 1500),
  largeV3('large-v3', 'ggml-large-v3.bin', 2900);

  final String id;
  final String fileName;
  final int sizeMb;
  const WhisperModel(this.id, this.fileName, this.sizeMb);

  String get label => switch (this) {
    WhisperModel.tiny => 'Tiny (${sizeMb}MB)',
    WhisperModel.base => 'Base (${sizeMb}MB)',
    WhisperModel.small => 'Small (${sizeMb}MB)',
    WhisperModel.medium => 'Medium (${sizeMb}MB)',
    WhisperModel.largeV3 => 'Large v3 (${sizeMb}MB)',
  };

  static WhisperModel fromId(String id) =>
      WhisperModel.values.firstWhere((m) => m.id == id, orElse: () => WhisperModel.base);
}

enum WhisperStatus { idle, checkingBinary, binaryNotFound, downloadingModel, transcribing, done, error }

class WhisperProgress {
  final WhisperStatus status;
  final double? downloadProgress; // 0.0–1.0
  final String? message;
  const WhisperProgress(this.status, {this.downloadProgress, this.message});
}

class WhisperService {
  static final instance = WhisperService._();
  WhisperService._();

  final _progress = StreamController<WhisperProgress>.broadcast();
  Stream<WhisperProgress> get progressStream => _progress.stream;

  static const _modelBaseUrl =
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
  ));

  // ──────────────────────────────────────────────
  // Binary detection (whisper is now bundled as xcframework — no external binary needed)

  /// Always returns a sentinel value indicating the bundled xcframework is used.
  Future<String?> findBinary() async {
    // whisper is now built into the app via whisper.xcframework — no external CLI needed.
    return 'bundled';
  }

  // ──────────────────────────────────────────────
  // Model management

  Future<Directory> _modelsDir() async {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory('${appSupport.path}/whisper/models');
    await dir.create(recursive: true);
    return dir;
  }

  /// Returns the local path for a model, downloading it if needed.
  Future<String> ensureModel(WhisperModel model) async {
    final dir = await _modelsDir();
    final path = '${dir.path}/${model.fileName}';
    final file = File(path);
    if (await file.exists()) {
      final stat = await file.stat();
      if (stat.size > 10 * 1024 * 1024) return path; // valid file
      await file.delete(); // remove partial download
    }

    final url = '$_modelBaseUrl/${model.fileName}';
    _progress.add(WhisperProgress(WhisperStatus.downloadingModel,
        downloadProgress: 0, message: 'Downloading ${model.label}…'));

    await _dio.download(
      url,
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          _progress.add(WhisperProgress(WhisperStatus.downloadingModel,
              downloadProgress: received / total,
              message: 'Downloading ${model.label}… ${(received / 1e6).toStringAsFixed(0)}/${(total / 1e6).toStringAsFixed(0)} MB'));
        }
      },
    );
    return path;
  }

  Future<bool> isModelDownloaded(WhisperModel model) async {
    final dir = await _modelsDir();
    final file = File('${dir.path}/${model.fileName}');
    if (!await file.exists()) return false;
    final stat = await file.stat();
    return stat.size > 10 * 1024 * 1024; // Must be > 10MB (smallest model is 74MB)
  }

  Future<void> deleteModel(WhisperModel model) async {
    final dir = await _modelsDir();
    final f = File('${dir.path}/${model.fileName}');
    if (await f.exists()) await f.delete();
  }

  // ──────────────────────────────────────────────
  // Transcription

  /// Transcribes a WAV file using the bundled whisper.xcframework. Throws on failure.
  Future<String> transcribeFile({
    required String wavPath,
    required WhisperModel model,
  }) async {
    final modelPath = await ensureModel(model);
    _progress.add(const WhisperProgress(WhisperStatus.transcribing, message: 'Transcribing…'));
    // binaryPath is ignored by RecordingBridge — whisper is called natively via xcframework
    final result = await RecordingService.instance.transcribeAudio(
      wavPath: wavPath,
      modelPath: modelPath,
      binaryPath: '',
    );
    _progress.add(const WhisperProgress(WhisperStatus.done));
    return result;
  }
}
