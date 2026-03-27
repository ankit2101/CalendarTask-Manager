import 'dart:convert';
import 'package:dio/dio.dart';
import '../../models/calendar_event.dart';

class ClaudeClient {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.anthropic.com',
    headers: {
      'Content-Type': 'application/json',
      'anthropic-version': '2023-06-01',
    },
  ));

  String? _apiKey;
  String _modelId = 'claude-sonnet-4-20250514';

  void setApiKey(String key) {
    _apiKey = key;
  }

  void setModel(String modelId) {
    _modelId = modelId;
  }

  Future<List<ActionItem>> extractActionItems(String note, NormalizedEvent event) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Claude API key not configured');
    }

    final prompt = '''You are an assistant that extracts action items from meeting notes.

Meeting: ${event.title}
Date: ${event.start}
Attendees: ${event.attendees.map((a) => a.name ?? a.email).join(', ')}

Notes:
$note

Extract action items from these notes. Return a JSON array where each item has:
- "text": the action item description
- "assignee": the person responsible (if mentioned), or null

Return ONLY the JSON array, no other text.''';

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
  }
}
