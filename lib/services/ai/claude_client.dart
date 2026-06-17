import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/calendar_event.dart';
import '../../models/settings.dart';

class ClaudeClient {
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

  Future<List<ActionItem>> extractActionItems(
    NormalizedEvent event, {
    String? transcript,
    String? summary,
    String? notes,
  }) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Claude API key not configured');
    }

    // Attendee emails are PII — send display names only. If no name is
    // available, substitute a generic placeholder to avoid leaking addresses.
    final attendeeNames = event.attendees
        .map((a) => a.name?.isNotEmpty == true ? a.name! : '[attendee]')
        .join(', ');

    final sections = StringBuffer();
    if (transcript?.isNotEmpty == true) {
      sections.writeln('## Transcript\n$transcript\n');
    }
    if (summary?.isNotEmpty == true) {
      sections.writeln('## Summary\n$summary\n');
    }
    if (notes?.isNotEmpty == true) {
      sections.writeln('## Meeting Notes\n$notes\n');
    }

    final prompt = '''You are an assistant that extracts action items from meeting content.

Meeting: ${event.title}
Date: ${event.start}
Attendees: $attendeeNames

${sections.toString().trimRight()}

Extract all action items from the above content. Return a JSON array where each item has:
- "text": the action item description
- "assignee": the person responsible (if mentioned), or null

Return ONLY the JSON array, no other text.''';

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
      // Strip markdown fences if present
      final cleaned = content.replaceAll(RegExp(r'```json?\n?'), '').replaceAll('```', '').trim();
      final items = jsonDecode(cleaned) as List<dynamic>;

      return items.asMap().entries.map((entry) {
        final item = entry.value as Map<String, dynamic>;
        return ActionItem(
          id: 'ai-${entry.key}',
          text: item['text'] as String,
          assignee: item['assignee'] as String?,
        );
      }).toList();
    } on DioException catch (e) {
      throw _dioError(e);
    }
  }

  /// Generates a summary and extracts action items from a meeting transcript.
  Future<({String summary, List<ActionItem> actionItems})> summarizeTranscript(
    String transcript,
    NormalizedEvent event,
  ) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Claude API key not configured');
    }

    final attendeeNames = event.attendees
        .map((a) => a.name?.isNotEmpty == true ? a.name! : '[attendee]')
        .join(', ');

    final prompt = '''You are an assistant that summarizes meeting transcripts.

Meeting: ${event.title}
Date: ${event.start}
Attendees: $attendeeNames

Transcript:
$transcript

Return a JSON object with exactly these two fields:
- "summary": a concise 2–4 sentence paragraph summarizing the meeting (decisions, key topics, outcomes)
- "actionItems": an array of objects, each with "text" (the action) and "assignee" (person responsible, or null)

Return ONLY the JSON object, no markdown fences, no other text.''';

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
      final cleaned = content.replaceAll(RegExp(r'```json?\n?'), '').replaceAll('```', '').trim();
      final json = jsonDecode(cleaned) as Map<String, dynamic>;

      final summary = json['summary'] as String? ?? '';
      final items = (json['actionItems'] as List<dynamic>? ?? []).asMap().entries.map((entry) {
        final item = entry.value as Map<String, dynamic>;
        return ActionItem(
          id: 'ai-t-${entry.key}',
          text: item['text'] as String? ?? '',
          assignee: item['assignee'] as String?,
        );
      }).where((a) => a.text.isNotEmpty).toList();

      return (summary: summary, actionItems: items);
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
