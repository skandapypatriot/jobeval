import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

class MockResponse {
  const MockResponse(this.statusCode, this.data);

  final int statusCode;
  final Object? data;
}

typedef MockHandler = FutureOr<MockResponse> Function(RequestOptions options);

class MockApiAdapter implements HttpClientAdapter {
  MockApiAdapter(this.handler);

  final MockHandler handler;
  final List<RequestOptions> requests = [];

  List<String> get paths => requests.map((request) => request.path).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    final response = await handler(options);
    final body = response.data == null
        ? ''
        : response.data is String
            ? response.data as String
            : jsonEncode(response.data);
    return ResponseBody.fromString(
      body,
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio mockDio(MockApiAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://mock.local/api/v1',
      connectTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}
