import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:dio/dio.dart';

/// Remove if kIsWeb or won't compile
import 'package:native_dio_adapter/native_dio_adapter.dart';

class DioSingleton {
  static final Dio _dio = Dio();

  static Dio get dioInstance {
    if (!kIsWeb) {
      _dio.httpClientAdapter = NativeAdapter();
    }
    return _dio;
  }
}
