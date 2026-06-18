import 'package:dio/dio.dart';
import '../../models/calendar_event.dart';
import '../../models/settings.dart';
import 'task_extractor.dart';

class ClaudeClient implements TaskExtractor {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.anthropic.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
    headers: {
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    },
  ));

  String? _apiKey;
  String _modelId = kDefaultClaudeModelId;

  void setApiKey(String key) {
    _apiKey = key;
  }

  void setModel(String modelId) {
    _modelId = modelId;
  }

  @override
  Future<List<ActionItem>> extractActionItems(
    NormalizedEvent event, {
    String? transcript,
    String? summary,
    String? notes,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Claude API key not configured');
    }

    final prompt = ExtractionPrompts.buildExtractPrompt(
      event,
      transcript: transcript,
      summary: summary,
      notes: notes,
    );

    try {
      final response = await _dio.post(
        '/v1/messages',
        options: Options(headers: {'x-api-key': _apiKey}),
        data: {
          'model': _modelId,
          'max_tokens': 1024,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        },
      );

      final content = response.data['content'][0]['text'] as String;
      return ExtractionPrompts.parseActionItems(content);
    } on DioException catch (e) {
      throw _dioError(e);
    }
  }

  /// Generates a summary and extracts action items from a meeting transcript.
  @override
  Future<({String summary, List<ActionItem> actionItems})> summarizeTranscript(
    String transcript,
    NormalizedEvent event,
  ) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Claude API key not configured');
    }

    final prompt = ExtractionPrompts.buildSummarizePrompt(transcript, event);

    try {
      final response = await _dio.post(
        '/v1/messages',
        options: Options(headers: {'x-api-key': _apiKey}),
        data: {
          'model': _modelId,
          'max_tokens': 2048,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        },
      );

      final content = response.data['content'][0]['text'] as String;
      return ExtractionPrompts.parseSummary(content);
    } on DioException catch (e) {
      throw _dioError(e);
    }
  }

  Exception _dioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) return Exception('Model "$_modelId" not found (404). Please select a different model in Settings.');
    if (status == 401) return Exception('Invalid API key (401). Please check your Claude API key in Settings.');
    if (status == 429) return Exception('Rate limit exceeded (429). Please wait a moment and try again.');
    return Exception('API error $status: ${e.message}');
  }
}
