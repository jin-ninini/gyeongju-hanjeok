import 'package:dio/dio.dart';

import '../core/app_env.dart';

class ApiClient {
  ApiClient()
      : dio = Dio(
          BaseOptions(
            baseUrl: AppEnv.backendBaseUrl,

            // 서버에 연결되는 시간
            connectTimeout: const Duration(seconds: 15),

            // 코스 추천은 여러 API를 호출할 수 있어서
            // 충분히 기다리도록 설정
            receiveTimeout: const Duration(seconds: 60),

            sendTimeout: const Duration(seconds: 30),

            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          ),
        ) {
    dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (_) {},
      ),
    );
  }

  final Dio dio;

  String? _accessToken;

  String? get accessToken => _accessToken;

  void setAccessToken(String? token) {
    final normalized = token?.trim();
    _accessToken = (normalized == null || normalized.isEmpty) ? null : normalized;

    if (_accessToken == null) {
      dio.options.headers.remove('Authorization');
    } else {
      dio.options.headers['Authorization'] = 'Bearer $_accessToken';
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );

      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        path,
        data: data,
      );

      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.delete<dynamic>(
        path,
        data: data,
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.put<dynamic>(
        path,
        data: data,
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await dio.patch<dynamic>(
        path,
        data: data,
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

}

class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
  });

  final String message;
  final int? statusCode;

  factory ApiException.fromDio(
    DioException error,
  ) {
    final statusCode =
        error.response?.statusCode;

    final responseData =
        error.response?.data;

    String serverMessage = '';

    if (responseData is Map) {
      serverMessage =
          (responseData['detail'] ??
                  responseData['message'] ??
                  responseData['error'] ??
                  '')
              .toString();
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout =>
        '서비스 연결 시간이 초과됐어요. 잠시 후 다시 시도해주세요.',

      DioExceptionType.receiveTimeout =>
        '응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.',

      DioExceptionType.sendTimeout =>
        '요청 전송 시간이 초과됐어요.',

      DioExceptionType.connectionError =>
        '서비스에 연결할 수 없어요. 인터넷 연결을 확인한 후 다시 시도해주세요.',

      DioExceptionType.badResponse =>
        serverMessage.isNotEmpty
            ? serverMessage
            : '요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.',

      DioExceptionType.cancel =>
        '요청이 취소됐어요.',

      _ =>
        serverMessage.isNotEmpty
            ? serverMessage
            : '네트워크 요청 중 오류가 발생했어요.',
    };

    return ApiException(
      message,
      statusCode: statusCode,
    );
  }

  @override
  String toString() => message;
}