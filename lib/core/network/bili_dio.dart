import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../constants/bili_hosts.dart';
import 'account_store.dart';
import 'wbi_signer.dart';

/// B 站统一返回结构：`{code, message, ttl, data}`。
class BiliResp {
  final int code;
  final String message;
  final dynamic data;

  const BiliResp({required this.code, required this.message, this.data});

  bool get isSuccess => code == 0;

  factory BiliResp.fromJson(Map<String, dynamic> j) => BiliResp(
        code: (j['code'] ?? 0) as int,
        message: (j['message'] ?? j['msg'] ?? '') as String,
        data: j['data'],
      );
}

/// 业务异常。
class BiliException implements Exception {
  final int code;
  final String message;
  BiliException(this.code, this.message);
  @override
  String toString() => '[$code] $message';
}

/// 全局 Dio 单例 + 拦截器链。
///
/// 拦截器顺序：
/// 1. 默认头（UA、Referer）
/// 2. 自动注入 Cookie / access_key
/// 3. WBI 签名（仅对标记为 wbi 的请求）
/// 4. 统一错误处理（code != 0 抛 BiliException）
class BiliDio {
  BiliDio._() {
    _dio = Dio(BaseOptions(
      baseUrl: BiliHosts.api,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': appUa,
        'Referer': 'https://www.bilibili.com',
      },
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ));
    _dio.httpClientAdapter = IOHttpClientAdapter();
    _dio.interceptors.add(_authInterceptor);
  }

  static const String appUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  static final BiliDio instance = BiliDio._();

  late final Dio _dio;
  Dio get raw => _dio;

  final WbiSigner wbi = WbiSigner();
  final AccountStore account = AccountStore();

  Future<void> init() async {
    await account.init();
  }

  Interceptor get _authInterceptor => InterceptorsWrapper(
        onRequest: (options, handler) {
          final cookies = account.session.cookies;
          if (cookies.isNotEmpty) {
            options.headers['Cookie'] = cookies;
          }
          // 同源 Referer
          final host = Uri.tryParse(options.uri.toString())?.host ?? '';
          if (host.contains('live.bilibili.com')) {
            options.headers['Referer'] = 'https://live.bilibili.com/';
          } else if (host.contains('space.bilibili.com')) {
            options.headers['Referer'] = 'https://space.bilibili.com/';
          } else {
            options.headers['Referer'] = 'https://www.bilibili.com';
          }
          handler.next(options);
        },
      );

  /// GET 请求，自动解包 BiliResp。
  Future<BiliResp> get(
    String path, {
    Map<String, dynamic>? query,
    bool wbi = false,
    Options? options,
  }) async {
    var q = Map<String, dynamic>.from(query ?? {});
    if (wbi) q = this.wbi.sign(q);
    final resp = await _dio.get<dynamic>(
      path,
      queryParameters: q.isEmpty ? null : q,
      options: options,
    );
    return _unwrap(resp.data);
  }

  /// GET 二进制响应（如弹幕 seg.so 的 protobuf）。
  Future<Uint8List> getBytes(
    String path, {
    Map<String, dynamic>? query,
    bool wbi = false,
  }) async {
    var q = Map<String, dynamic>.from(query ?? {});
    if (wbi) q = this.wbi.sign(q);
    final resp = await _dio.get<List<int>>(
      path,
      queryParameters: q.isEmpty ? null : q,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(resp.data ?? const []);
  }

  /// POST 请求，表单形式（application/x-www-form-urlencoded）。
  Future<BiliResp> postForm(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    final resp = await _dio.post<dynamic>(
      path,
      data: data ?? {},
      queryParameters: query,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    return _unwrap(resp.data);
  }

  /// POST JSON。
  Future<BiliResp> postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) async {
    final resp = await _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: query,
      options: Options(contentType: Headers.jsonContentType),
    );
    return _unwrap(resp.data);
  }

  BiliResp _unwrap(dynamic body) {
    if (body is String) {
      body = jsonDecode(body);
    }
    if (body is Map<String, dynamic>) {
      final r = BiliResp.fromJson(body);
      if (!r.isSuccess) {
        throw BiliException(r.code, r.message.isEmpty ? '请求失败' : r.message);
      }
      return r;
    }
    // 非标准返回（如弹幕 seg.so 二进制），原样包一层
    return BiliResp(code: 0, message: '', data: body);
  }
}
