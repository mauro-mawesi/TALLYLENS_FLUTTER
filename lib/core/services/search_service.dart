import 'dart:async';
import 'package:dio/dio.dart';
import 'package:recibos_flutter/core/services/api_service.dart';

class SearchService {
  final ApiService _api;
  late final Dio _dio;

  // Debounce timer for search
  Timer? _debounce;

  SearchService({required ApiService api}) : _api = api {
    // Access Dio instance from ApiService
    _dio = api.dio;
  }

  /// Search receipts with full-text search
  /// Returns paginated results with search ranking
  Future<Map<String, dynamic>> searchReceipts({
    required String query,
    String? category,
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minAmount,
    double? maxAmount,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'q': query,
      if (category != null) 'category': category,
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
      if (minAmount != null) 'minAmount': minAmount.toString(),
      if (maxAmount != null) 'maxAmount': maxAmount.toString(),
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final response = await _dio.get('/receipts/search', queryParameters: params);

    if (response.statusCode == 200) {
      return response.data['data'] as Map<String, dynamic>;
    }

    throw Exception('Search failed: ${response.statusMessage}');
  }

  /// Get search suggestions as user types
  Future<List<Map<String, dynamic>>> getSearchSuggestions({
    required String query,
    int limit = 10,
  }) async {
    if (query.length < 2) {
      return [];
    }

    final params = {
      'q': query,
      'limit': limit.toString(),
    };

    final response = await _dio.get('/receipts/search/suggestions', queryParameters: params);

    if (response.statusCode == 200) {
      final data = response.data['data'] as Map<String, dynamic>;
      return (data['suggestions'] as List).cast<Map<String, dynamic>>();
    }

    return [];
  }

  /// Get search history (recent or popular)
  Future<List<Map<String, dynamic>>> getSearchHistory({
    int limit = 20,
    String type = 'recent', // 'recent' or 'popular'
  }) async {
    final params = {
      'limit': limit.toString(),
      'type': type,
    };

    final response = await _dio.get('/receipts/search/history', queryParameters: params);

    if (response.statusCode == 200) {
      final data = response.data['data'] as Map<String, dynamic>;
      return (data['history'] as List).cast<Map<String, dynamic>>();
    }

    return [];
  }

  /// Clear all search history
  Future<void> clearSearchHistory() async {
    await _dio.delete('/receipts/search/history');
  }

  /// Get saved filters
  Future<List<Map<String, dynamic>>> getSavedFilters({
    bool activeOnly = true,
  }) async {
    final params = {
      'activeOnly': activeOnly.toString(),
    };

    final response = await _dio.get('/receipts/filters', queryParameters: params);

    if (response.statusCode == 200) {
      final data = response.data['data'] as Map<String, dynamic>;
      return (data['filters'] as List).cast<Map<String, dynamic>>();
    }

    return [];
  }

  /// Create a saved filter
  Future<Map<String, dynamic>> createSavedFilter({
    required String name,
    String? description,
    required Map<String, dynamic> filters,
  }) async {
    final body = {
      'name': name,
      if (description != null) 'description': description,
      'filters': filters,
    };

    final response = await _dio.post('/receipts/filters', data: body);

    if (response.statusCode == 201) {
      final data = response.data['data'] as Map<String, dynamic>;
      return data['filter'] as Map<String, dynamic>;
    }

    throw Exception('Failed to create filter');
  }

  /// Update a saved filter
  Future<Map<String, dynamic>> updateSavedFilter({
    required String id,
    String? name,
    String? description,
    Map<String, dynamic>? filters,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (filters != null) 'filters': filters,
      if (isActive != null) 'isActive': isActive,
    };

    final response = await _dio.patch('/receipts/filters/$id', data: body);

    if (response.statusCode == 200) {
      final data = response.data['data'] as Map<String, dynamic>;
      return data['filter'] as Map<String, dynamic>;
    }

    throw Exception('Failed to update filter');
  }

  /// Delete a saved filter
  Future<void> deleteSavedFilter(String id) async {
    await _dio.delete('/receipts/filters/$id');
  }

  /// Use a saved filter (increment usage count)
  Future<Map<String, dynamic>> useSavedFilter(String id) async {
    final response = await _dio.post('/receipts/filters/$id/use', data: {});

    if (response.statusCode == 200) {
      final data = response.data['data'] as Map<String, dynamic>;
      return data['filter'] as Map<String, dynamic>;
    }

    throw Exception('Failed to use filter');
  }

  /// Debounced search - prevents excessive API calls while typing
  void searchWithDebounce({
    required String query,
    required Function(String) onSearch,
    Duration delay = const Duration(milliseconds: 500),
  }) {
    _debounce?.cancel();
    _debounce = Timer(delay, () {
      if (query.length >= 2) {
        onSearch(query);
      }
    });
  }

  /// Cancel any pending debounced search
  void cancelDebounce() {
    _debounce?.cancel();
  }

  void dispose() {
    _debounce?.cancel();
  }
}
