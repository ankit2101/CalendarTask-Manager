import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/calendar_event.dart';
import '../recording/recording_service.dart';
import 'task_extractor.dart';

/// On-device instruction-tuned models available for local task extraction.
/// Each is a quantized GGUF run natively via the bundled llama.xcframework —
/// the LLM analogue of [WhisperModel]. URLs point at public GGUF mirrors.
enum LocalLlmModel {
  qwen1_5b(
    'qwen2.5-1.5b',
    'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    1100,
    'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
  ),
  llama3_2_3b(
    'llama-3.2-3b',
    'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    2020,
    'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
  ),
  qwen3b(
    'qwen2.5-3b',
    'Qwen2.5-3B-Instruct-Q4_K_M.gguf',
    1930,
    'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
  );

  final String id;
  final String fileName;
  final int sizeMb;
  final String url;
  const LocalLlmModel(this.id, this.fileName, this.sizeMb, this.url);

  String get label => switch (this) {
        LocalLlmModel.qwen1_5b => 'Qwen2.5 1.5B (${sizeMb}MB)',
        LocalLlmModel.llama3_2_3b => 'Llama 3.2 3B (${sizeMb}MB)',
        LocalLlmModel.qwen3b => 'Qwen2.5 3B (${sizeMb}MB)',
      };

  static LocalLlmModel fromId(String id) =>
      LocalLlmModel.values.firstWhere((m) => m.id == id, orElse: () => LocalLlmModel.qwen1_5b);
}

enum LocalLlmStatus { idle, downloadingModel, generating, done, error }

class LocalLlmProgress {
  final LocalLlmStatus status;
  final double? downloadProgress; // 0.0–1.0
  final String? message;
  const LocalLlmProgress(this.status, {this.downloadProgress, this.message});
}

/// On-device task extractor backed by a bundled llama.cpp (llama.xcframework).
/// Mirrors [WhisperService]: it manages GGUF model downloads and runs
/// inference natively, and implements [TaskExtractor] so it is a drop-in
/// alternative to the cloud [ClaudeClient].
class LocalLlmService implements TaskExtractor {
  static final instance = LocalLlmService._();
  LocalLlmService._();

  final _progress = StreamController<LocalLlmProgress>.broadcast();
  Stream<LocalLlmProgress> get progressStream => _progress.stream;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  CancelToken? _cancelToken;

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
  ));

  /// Whether the native llama backend is linked into this build.
  Future<bool> isBackendAvailable() => RecordingService.instance.isLocalLlmAvailable();

  // ──────────────────────────────────────────────
  // Model management (parallels WhisperService)

  Future<Directory> _modelsDir() async {
    final appSupport = await getApplicationSupportDirectory();
    final dir = Directory('${appSupport.path}/llm/models');
    await dir.create(recursive: true);
    return dir;
  }

  Future<bool> isModelDownloaded(LocalLlmModel model) async {
    final dir = await _modelsDir();
    final file = File('${dir.path}/${model.fileName}');
    if (!await file.exists()) return false;
    final stat = await file.stat();
    return stat.size > 100 * 1024 * 1024; // smallest model is ~1GB
  }

  Future<void> deleteModel(LocalLlmModel model) async {
    final dir = await _modelsDir();
    final f = File('${dir.path}/${model.fileName}');
    if (await f.exists()) await f.delete();
  }

  void cancelDownload() => _cancelToken?.cancel('User cancelled');

  /// Returns the local path for a model, downloading it if needed. Downloads to
  /// a temp `.part` path and only commits it once size-validated, so an
  /// interrupted download never leaves a partial file that would later fail to load.
  Future<String> ensureModel(LocalLlmModel model) async {
    final dir = await _modelsDir();
    final path = '${dir.path}/${model.fileName}';
    final file = File(path);
    if (await file.exists()) {
      final stat = await file.stat();
      if (stat.size > 100 * 1024 * 1024) return path;
      await file.delete();
    }

    final partPath = '$path.part';
    _cancelToken = CancelToken();
    _isDownloading = true;
    _downloadProgress = 0;
    _progress.add(LocalLlmProgress(LocalLlmStatus.downloadingModel,
        downloadProgress: 0, message: 'Downloading ${model.label}…'));

    try {
      await _dio.download(
        model.url,
        partPath,
        cancelToken: _cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            _downloadProgress = received / total;
            _progress.add(LocalLlmProgress(LocalLlmStatus.downloadingModel,
                downloadProgress: _downloadProgress,
                message:
                    'Downloading ${model.label}… ${(received / 1e6).toStringAsFixed(0)}/${(total / 1e6).toStringAsFixed(0)} MB'));
          }
        },
      );

      final partFile = File(partPath);
      final downloadedSize = await partFile.length();
      final minBytes = (model.sizeMb * 1024 * 1024 * 0.9).round();
      if (downloadedSize < minBytes) {
        await partFile.delete();
        throw Exception(
            'Downloaded model is incomplete (${(downloadedSize / 1e6).toStringAsFixed(0)} MB, expected ~${model.sizeMb} MB)');
      }
      await partFile.rename(path);
    } on DioException catch (e) {
      await _deleteIfExists(partPath);
      if (CancelToken.isCancel(e)) {
        _isDownloading = false;
        _progress.add(const LocalLlmProgress(LocalLlmStatus.idle, message: 'Download cancelled'));
        throw Exception('Download cancelled');
      }
      rethrow;
    } catch (_) {
      await _deleteIfExists(partPath);
      rethrow;
    } finally {
      _isDownloading = false;
      _cancelToken = null;
    }
    return path;
  }

  Future<void> _deleteIfExists(String path) async {
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  // ──────────────────────────────────────────────
  // Inference

  /// The model selected for inference. Set by the provider from settings so
  /// each extraction uses the user's chosen model without threading it through.
  LocalLlmModel model = LocalLlmModel.qwen1_5b;

  Future<String> _generate(String prompt, {int maxTokens = 1024}) async {
    final modelPath = await ensureModel(model);
    _progress.add(const LocalLlmProgress(LocalLlmStatus.generating, message: 'Generating…'));
    try {
      final out = await RecordingService.instance
          .runLocalLlm(modelPath: modelPath, prompt: prompt, maxTokens: maxTokens);
      _progress.add(const LocalLlmProgress(LocalLlmStatus.done));
      return out;
    } catch (e) {
      _progress.add(LocalLlmProgress(LocalLlmStatus.error, message: e.toString()));
      // Surface a clear, user-facing message for the common "not built" case.
      if (e.toString().contains('LLM_UNAVAILABLE')) {
        throw Exception(
            'On-device model backend is not available in this build. Switch Task Extraction to Cloud in Settings, or rebuild the app.');
      }
      rethrow;
    }
  }

  @override
  Future<List<ActionItem>> extractActionItems(
    NormalizedEvent event, {
    String? transcript,
    String? summary,
    String? notes,
  }) async {
    final prompt = ExtractionPrompts.buildExtractPrompt(
      event,
      transcript: transcript,
      summary: summary,
      notes: notes,
    );
    final out = await _generate(prompt, maxTokens: 1024);
    return ExtractionPrompts.parseActionItems(out);
  }

  @override
  Future<({String summary, List<ActionItem> actionItems})> summarizeTranscript(
    String transcript,
    NormalizedEvent event,
  ) async {
    final prompt = ExtractionPrompts.buildSummarizePrompt(transcript, event);
    final out = await _generate(prompt, maxTokens: 2048);
    return ExtractionPrompts.parseSummary(out);
  }
}
