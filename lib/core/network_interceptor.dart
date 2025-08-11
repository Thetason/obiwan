import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/debug_logger.dart';

class NetworkInterceptor extends Interceptor {
  static final NetworkInterceptor _instance = NetworkInterceptor._internal();
  factory NetworkInterceptor() => _instance;
  NetworkInterceptor._internal();

  final List<NetworkRequest> _requests = [];
  final List<Function(NetworkRequest)> _listeners = [];
  
  int _requestIdCounter = 0;
  
  // Statistics
  int _totalRequests = 0;
  int _successfulRequests = 0;
  int _failedRequests = 0;
  double _averageResponseTime = 0.0;
  double _totalDataTransferred = 0.0; // bytes
  
  // Getters
  List<NetworkRequest> get requests => List.unmodifiable(_requests);
  int get totalRequests => _totalRequests;
  int get successfulRequests => _successfulRequests;
  int get failedRequests => _failedRequests;
  double get averageResponseTime => _averageResponseTime;
  double get totalDataTransferred => _totalDataTransferred;
  double get successRate => _totalRequests > 0 ? _successfulRequests / _totalRequests : 0.0;
  
  void addListener(Function(NetworkRequest) listener) {
    _listeners.add(listener);
  }
  
  void removeListener(Function(NetworkRequest) listener) {
    _listeners.remove(listener);
  }
  
  void _notifyListeners(NetworkRequest request) {
    for (final listener in _listeners) {
      try {
        listener(request);
      } catch (e) {
        logger.error('네트워크 리스너 오류: $e');
      }
    }
  }
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final request = NetworkRequest(
      id: _requestIdCounter++,
      method: options.method,
      url: options.uri.toString(),
      headers: options.headers,
      data: options.data,
      startTime: DateTime.now(),
    );
    
    _requests.add(request);
    _totalRequests++;
    
    // Keep only last 100 requests
    if (_requests.length > 100) {
      _requests.removeAt(0);
    }
    
    _notifyListeners(request);
    
    if (kDebugMode) {
      logger.info('🌐 Request: ${options.method} ${options.uri}', tag: 'NETWORK');
    }
    
    handler.next(options);
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final request = _findRequestById(response.requestOptions);
    if (request != null) {
      request._completeSuccess(
        response.statusCode ?? 0,
        response.headers.map,
        response.data,
        response.extra,
      );
      
      _successfulRequests++;
      _updateStatistics(request);
      _notifyListeners(request);
      
      if (kDebugMode) {
        logger.info('✅ Response: ${response.statusCode} in ${request.duration}ms', tag: 'NETWORK');
      }
    }
    
    handler.next(response);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final request = _findRequestById(err.requestOptions);
    if (request != null) {
      request._completeError(err);
      
      _failedRequests++;
      _updateStatistics(request);
      _notifyListeners(request);
      
      if (kDebugMode) {
        logger.error('❌ Request failed: ${err.message} in ${request.duration}ms', tag: 'NETWORK');
      }
    }
    
    handler.next(err);
  }
  
  NetworkRequest? _findRequestById(RequestOptions options) {
    try {
      return _requests.lastWhere(
        (req) => req.url == options.uri.toString() && req.method == options.method,
      );
    } catch (e) {
      return null;
    }
  }
  
  void _updateStatistics(NetworkRequest request) {
    // Update average response time
    final totalTime = _requests.where((r) => r.isCompleted).fold<double>(
      0.0, (sum, r) => sum + r.duration,
    );
    final completedRequests = _requests.where((r) => r.isCompleted).length;
    
    if (completedRequests > 0) {
      _averageResponseTime = totalTime / completedRequests;
    }
    
    // Update data transferred
    if (request.responseData != null) {
      try {
        final dataSize = _calculateDataSize(request.responseData);
        _totalDataTransferred += dataSize;
      } catch (e) {
        // Ignore data size calculation errors
      }
    }
  }
  
  double _calculateDataSize(dynamic data) {
    if (data == null) return 0.0;
    
    try {
      if (data is String) {
        return data.length.toDouble();
      } else if (data is List<int>) {
        return data.length.toDouble();
      } else {
        // Try to serialize to JSON to estimate size
        final jsonString = jsonEncode(data);
        return jsonString.length.toDouble();
      }
    } catch (e) {
      return 0.0;
    }
  }
  
  void clearHistory() {
    _requests.clear();
    _totalRequests = 0;
    _successfulRequests = 0;
    _failedRequests = 0;
    _averageResponseTime = 0.0;
    _totalDataTransferred = 0.0;
    _requestIdCounter = 0;
  }
  
  String exportToCurl(NetworkRequest request) {
    final buffer = StringBuffer();
    buffer.write('curl -X ${request.method}');
    
    // Add headers
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() != 'content-length') {
        buffer.write(' -H "${entry.key}: ${entry.value}"');
      }
    }
    
    // Add data
    if (request.data != null) {
      String dataString;
      if (request.data is String) {
        dataString = request.data as String;
      } else {
        try {
          dataString = jsonEncode(request.data);
        } catch (e) {
          dataString = request.data.toString();
        }
      }
      buffer.write(' -d \'$dataString\'');
    }
    
    // Add URL
    buffer.write(' "${request.url}"');
    
    return buffer.toString();
  }
  
  List<NetworkRequest> getFilteredRequests({
    String? method,
    String? urlPattern,
    bool? successful,
    Duration? minDuration,
    Duration? maxDuration,
  }) {
    return _requests.where((request) {
      if (method != null && request.method != method) return false;
      if (urlPattern != null && !request.url.contains(urlPattern)) return false;
      if (successful != null && request.isSuccessful != successful) return false;
      if (minDuration != null && request.duration < minDuration.inMilliseconds) return false;
      if (maxDuration != null && request.duration > maxDuration.inMilliseconds) return false;
      return true;
    }).toList();
  }
}

class NetworkRequest {
  final int id;
  final String method;
  final String url;
  final Map<String, dynamic> headers;
  final dynamic data;
  final DateTime startTime;
  
  DateTime? _endTime;
  int? _statusCode;
  Map<String, List<String>>? _responseHeaders;
  dynamic _responseData;
  Map<String, dynamic>? _extras;
  DioException? _error;
  
  NetworkRequest({
    required this.id,
    required this.method,
    required this.url,
    required this.headers,
    this.data,
    required this.startTime,
  });
  
  // Getters
  bool get isCompleted => _endTime != null;
  bool get isSuccessful => _statusCode != null && _statusCode! >= 200 && _statusCode! < 300;
  bool get hasError => _error != null;
  
  int get duration => _endTime?.difference(startTime).inMilliseconds ?? 0;
  int? get statusCode => _statusCode;
  Map<String, List<String>>? get responseHeaders => _responseHeaders;
  dynamic get responseData => _responseData;
  Map<String, dynamic>? get extras => _extras;
  DioException? get error => _error;
  
  String get statusText {
    if (_error != null) return 'Error';
    if (_statusCode == null) return 'Pending';
    
    switch (_statusCode!) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 204: return 'No Content';
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 500: return 'Internal Server Error';
      default: return 'HTTP $_statusCode';
    }
  }
  
  String get shortUrl {
    final uri = Uri.parse(url);
    return uri.path.length > 30 
        ? '...${uri.path.substring(uri.path.length - 27)}'
        : uri.path.isEmpty ? '/' : uri.path;
  }
  
  // Internal methods
  void _completeSuccess(
    int statusCode,
    Map<String, List<String>> responseHeaders,
    dynamic responseData,
    Map<String, dynamic>? extras,
  ) {
    _endTime = DateTime.now();
    _statusCode = statusCode;
    _responseHeaders = responseHeaders;
    _responseData = responseData;
    _extras = extras;
  }
  
  void _completeError(DioException error) {
    _endTime = DateTime.now();
    _error = error;
    _statusCode = error.response?.statusCode;
    _responseHeaders = error.response?.headers.map;
    _responseData = error.response?.data;
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'url': url,
      'headers': headers,
      'data': data?.toString(),
      'startTime': startTime.toIso8601String(),
      'endTime': _endTime?.toIso8601String(),
      'duration': duration,
      'statusCode': _statusCode,
      'statusText': statusText,
      'isSuccessful': isSuccessful,
      'hasError': hasError,
      'error': _error?.toString(),
      'responseSize': _calculateResponseSize(),
    };
  }
  
  double _calculateResponseSize() {
    if (_responseData == null) return 0.0;
    
    try {
      if (_responseData is String) {
        return (_responseData as String).length.toDouble();
      } else if (_responseData is List<int>) {
        return (_responseData as List<int>).length.toDouble();
      } else {
        final jsonString = jsonEncode(_responseData);
        return jsonString.length.toDouble();
      }
    } catch (e) {
      return 0.0;
    }
  }
}

// Network statistics summary
class NetworkStatistics {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final double successRate;
  final double averageResponseTime;
  final double totalDataTransferred;
  final DateTime generatedAt;
  
  const NetworkStatistics({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.successRate,
    required this.averageResponseTime,
    required this.totalDataTransferred,
    required this.generatedAt,
  });
  
  factory NetworkStatistics.fromInterceptor(NetworkInterceptor interceptor) {
    return NetworkStatistics(
      totalRequests: interceptor.totalRequests,
      successfulRequests: interceptor.successfulRequests,
      failedRequests: interceptor.failedRequests,
      successRate: interceptor.successRate,
      averageResponseTime: interceptor.averageResponseTime,
      totalDataTransferred: interceptor.totalDataTransferred,
      generatedAt: DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'totalRequests': totalRequests,
      'successfulRequests': successfulRequests,
      'failedRequests': failedRequests,
      'successRate': successRate,
      'averageResponseTime': averageResponseTime,
      'totalDataTransferred': totalDataTransferred,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }
}