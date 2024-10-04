import 'dart:io'; // Platform.is
import 'package:flutter/foundation.dart'; // kIsWeb
import 'package:dio/dio.dart';

/// Remove if kIsWeb or won't compile
import 'package:native_dio_adapter/native_dio_adapter.dart';

class GetPlatform {
  static const bool isWeb = kIsWeb;
  static final bool isIOS = !kIsWeb && (Platform.isIOS || Platform.isMacOS);
  static final bool isAndroid = !kIsWeb && Platform.isAndroid;
  static final bool isWindows = !kIsWeb && Platform.isWindows;
}

class DioSingleton {
  static final Dio _dio = Dio();

  static Dio get dioInstance {
    if (GetPlatform.isIOS) {
      _dio.httpClientAdapter = NativeAdapter();
    }
    return _dio;
  }
}
