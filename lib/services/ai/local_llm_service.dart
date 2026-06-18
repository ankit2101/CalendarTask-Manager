import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/calendar_event.dart';
import '../recording/recording_service.dart';
import 'task_extractor.dart';

/// On-device instruction-tuned models available for local task extraction.
/// Each is a quantized GGUF run natively via the bundled llama.xcframework —
/// the LLM analogue of [WhisperModel].
///
/// URLs are pinned to an immutable HuggingFace commit revision (not `main`), and
/// every download is verified against the exact byte size and SHA-256 below, so a
/// changed, re-uploaded, or tampered file is rejected rather than loaded natively.
/// To update: bump the revision in the URL and refresh [sizeBytes]/[sha256] from
/// that revision's LFS pointer (`/raw/<rev>/<file>`).
enum LocalLlmModel {
  qwen1_5b(
    'qwen2.5-1.5b',
    'Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    986048768,
    '1adf0b11065d8ad2e8123ea110d1ec956dab4ab038eab665614adba04b6c3370',
    'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/9eadc66189c7641e1ddd226b8267a9119b2ce2d4/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
  ),
  llama3_2_3b(
    'llama-3.2-3b',
    'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    2019377696,
    '6c1a2b41161032677be168d354123594c0e6e67d2b9227c84f296ad037c728ff',
    'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/5ab33fa94d1d04e903623ae72c95d1696f09f9e8/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
  ),
  qwen3b(
    'qwen2.5-3b',
    'Qwen2.5-3B-Instruct-Q4_K_M.gguf',
    1929903264,
    '9c9f56a391a3abbd5b89d0245bf6106081bcc3173119d4229235dd9d23253f94',
    'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/f302c64a2269a69fb27b2f9473b362f5bb8e78d8/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
  );

  final String id;
  final String fileName;
  final int sizeBytes;
  final String sha256; // lowercase hex, verified after download
  final String url;
  const LocalLlmModel(this.id, this.fileName, this.sizeBytes, this.sha256, this.url);

  int get sizeMb => (sizeBytes / (1024 * 1024)).round();

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
    // A committed file is only ever written after full size + SHA-256
    // verification (see [ensureModel]), so an exact byte-size match is a
    // sufficient cheap check here — re-hashing multi-GB files on every Settings
    // open would be wasteful.
    final stat = await file.stat();
    return stat.size == model.sizeBytes;
  }

  Future<void> deleteModel(LocalLlmModel model) async {
    final dir = await _modelsDir();
    final f = File('${dir.path}/${model.fileName}');
    if (await f.exists()) await f.delete();
  }

  void cancelDownload() => _cancelToken?.cancel('User cancelled');

  /// Returns the local path for a model, downloading it if needed. Downloads to
  /// a temp `.part` path and only commits it once size- and SHA-256-validated, so
  /// an interrupted or tampered download never leaves a file that would later be
  /// loaded into the native runner.
  Future<String> ensureModel(LocalLlmModel model) async {
    final dir = await _modelsDir();
    final path = '${dir.path}/${model.fileName}';
    final file = File(path);
    if (await file.exists()) {
      final stat = await file.stat();
      if (stat.size == model.sizeBytes) return path;
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
      if (downloadedSize != model.sizeBytes) {
        await partFile.delete();
        throw Exception(
            'Downloaded model has unexpected size (${(downloadedSize / 1e6).toStringAsFixed(0)} MB, expected ${(model.sizeBytes / 1e6).toStringAsFixed(0)} MB)');
      }
      _progress.add(LocalLlmProgress(LocalLlmStatus.downloadingModel,
          downloadProgress: 1, message: 'Verifying ${model.label}…'));
      final actualHash = await _sha256OfFile(partFile);
      if (actualHash != model.sha256) {
        await partFile.delete();
        throw Exception(
            'Downloaded model failed integrity check (SHA-256 mismatch). The file may be corrupt or tampered with.');
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

  /// Streams the file through SHA-256 so we never hold a multi-GB model in
  /// memory. Returns the lowercase hex digest.
  Future<String> _sha256OfFile(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
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
