import 'dart:io';
import 'dart:async';

class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _TestHttpClientRequest();
  }
  
  @override
  bool autoUncompress = true;
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }

  @override
  Future<HttpClientResponse> close() async {
    return _TestHttpClientResponse();
  }
  
  @override
  HttpHeaders get headers => _TestHttpHeaders();
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
  
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  
  @override
  set contentType(ContentType? contentType) {}
}

class _TestHttpClientResponse implements HttpClientResponse {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }

  @override
  int get statusCode => 200;
  
  @override
  int get contentLength => 0;

  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([]).listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}
