import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/settings.dart';

const _kLastCheckKey   = 'modelSync_lastCheckMs';
const _kCachedModelsKey = 'modelSync_cachedModels';
const _kSyncIntervalMs  = 7 * 24 * 60 * 60 * 1000; // 7 days in ms

class ModelSyncService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.anthropic.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      'anthropic-version': '2023-06-01',
      'Content-Type': 'application/json',
    },
  ));

  /// Returns the model list, refreshing from the API if 7+ days have elapsed.
  /// Falls back to [kClaudeModels] on any error or missing API key.
  static Future<List<ClaudeModel>> getModels(String? apiKey) async {
    if (apiKey == null || apiKey.isEmpty) return kClaudeModels.toList();

    try {
      final prefs    = await SharedPreferences.getInstance();
      final lastMs   = prefs.getInt(_kLastCheckKey) ?? 0;
      final nowMs    = DateTime.now().millisecondsSinceEpoch;
      final stale    = (nowMs - lastMs) >= _kSyncIntervalMs;

      if (!stale) {
        final cached = prefs.getString(_kCachedModelsKey);
        if (cached != null) return _decodeModels(cached);
      }

      return await _fetchAndCache(apiKey, prefs);
    } catch (e) {
      debugPrint('[ModelSync] getModels failed: $e');
      return kClaudeModels.toList();
    }
  }

  /// Forces a fresh fetch regardless of the last-check timestamp.
  static Future<List<ClaudeModel>> forceRefresh(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    return _fetchAndCache(apiKey, prefs);
  }

  static Future<List<ClaudeModel>> _fetchAndCache(
    String apiKey,
    SharedPreferences prefs,
  ) async {
    final resp = await _dio.get<Map<String, dynamic>>(
      '/v1/models',
      options: Options(headers: {'x-api-key': apiKey}),
    );

    final data = resp.data?['data'] as List<dynamic>? ?? [];
    final models = data
        .whereType<Map<String, dynamic>>()
        .where((m) => (m['id'] as String? ?? '').startsWith('claude-'))
        .map((m) {
          final id   = m['id']           as String;
          final name = m['display_name'] as String? ?? id;
          return ClaudeModel(
            id:    id,
            label: name,
            tier:  ClaudeModel.tierFromId(id),
          );
        })
        .toList();

    if (models.isEmpty) return kClaudeModels.toList();

    final json = jsonEncode(models.map((m) => m.toJson()).toList());
    await prefs.setString(_kCachedModelsKey, json);
    await prefs.setInt(_kLastCheckKey, DateTime.now().millisecondsSinceEpoch);

    debugPrint('[ModelSync] Fetched ${models.length} models from API');
    return models;
  }

  static List<ClaudeModel> _decodeModels(String json) {
    try {
      final list = jsonDecode(json) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ClaudeModel.fromJson)
          .toList();
    } catch (_) {
      return kClaudeModels.toList();
    }
  }
}
