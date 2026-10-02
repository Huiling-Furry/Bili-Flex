import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

import '../../core/network/bili_dio.dart';
import '../../core/network/account_store.dart';
import '../../core/constants/endpoints.dart';

/// 当前登录用户信息。
class NavInfo {
  final int isLogin;
  final int mid;
  final String uname;
  final String face;
  final int coins;
  final String vipStatus;
  final Map<String, dynamic> wbiImg;

  const NavInfo({
    this.isLogin = 0,
    this.mid = 0,
    this.uname = '',
    this.face = '',
    this.coins = 0,
    this.vipStatus = '',
    this.wbiImg = const {},
  });

  bool get isLoggedIn => isLogin == 1;

  factory NavInfo.fromJson(Map<String, dynamic> j) => NavInfo(
        isLogin: (j['isLogin'] ?? 0) as int,
        mid: (j['mid'] ?? 0) as int,
        uname: (j['uname'] ?? '') as String,
        face: (j['face'] ?? '') as String,
        coins: (j['money'] ?? 0) is int
            ? (j['money'] as int)
            : int.tryParse('${j['money']}') ?? 0,
        vipStatus: (j['vipStatus'] ?? j['vip']['status'] ?? 0).toString(),
        wbiImg: (j['wbi_img'] ?? {}) as Map<String, dynamic>,
      );
}

/// 登录 / 账号相关。
class AccountRepo {
  final BiliDio _dio = BiliDio.instance;

  /// 拉取 nav，同时刷新 WBI 密钥。
  Future<NavInfo> nav() async {
    final resp = await _dio.get(Endpoints.nav);
    final info = NavInfo.fromJson(resp.data as Map<String, dynamic>);
    if (info.wbiImg.isNotEmpty) {
      _dio.wbi.refreshFromWbiImg(info.wbiImg);
    }
    return info;
  }

  /// 申请 TV 端二维码。
  /// 返回 (authCode, qrcodeKey, url)。
  Future<({String authCode, String qrcodeKey, String url})>
  generateQrcode() async {
    final resp = await _dio.get(Endpoints.qrcodeGen, query: {
      'app_id': 85,
      'local_id': 0,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    final data = resp.data as Map<String, dynamic>;
    return (
      authCode: data['auth_code'] as String,
      qrcodeKey: (data['qrcode_key'] ?? '') as String,
      url: data['url'] as String,
    );
  }

  /// 轮询二维码状态。
  /// 返回 data.code 语义：0=登录成功 86038=二维码过期 86039=未确认，
  /// 同时带回本次响应的 Set-Cookie（登录成功时携带 SESSDATA 等）。
  Future<({int code, String message, Map<String, List<String>> setCookie})>
      pollQrcode(String authCode) async {
    final resp = await _dio.raw.get<dynamic>(
      Endpoints.qrcodePoll,
      queryParameters: {
        'auth_code': authCode,
        'local_id': 0,
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
    );
    final body = resp.data is String ? jsonDecode(resp.data as String) : resp.data;
    final data = (body is Map ? body['data'] : null) as Map<String, dynamic>? ??
        const <String, dynamic>{};
    final headers = <String, List<String>>{};
    resp.headers.map.forEach((k, v) => headers[k.toLowerCase()] = v);
    return (
      code: (data['code'] ?? -1) as int,
      message: (data['message'] ?? data['msg'] ?? '') as String,
      setCookie: headers,
    );
  }

  /// 从扫码成功的 Set-Cookie 里提取 SESSDATA。
  /// dio 把 cookies 放在 response.headers.map['set-cookie']。
  Future<void> afterQrcodeLogin(Map<String, List<String>> setCookie) async {
    final cookies = setCookie.values.expand((e) => e).toList();
    // 从 Set-Cookie 提取 kv
    final kv = <String, String>{};
    for (final c in cookies) {
      final first = c.split(';').first;
      final idx = first.indexOf('=');
      if (idx > 0) {
        kv[first.substring(0, idx).trim()] = first.substring(idx + 1).trim();
      }
    }
    final cookieStr = kv.entries
        .where((e) => [
              'SESSDATA',
              'bili_jct',
              'DedeUserID',
              'buvid3',
              'buvid4',
              'b_nut',
              'browser_resolution',
              'fingerprint',
            ].contains(e.key))
        .map((e) => '${e.key}=${e.value}')
        .join('; ');

    // 用新 cookie 拉一次 nav 拿用户信息
    final prevCookie = _dio.account.session.cookies;
    await _dio.account.saveSession(AccountSession(
      mid: int.tryParse(kv['DedeUserID'] ?? '0') ?? 0,
      uname: '',
      face: '',
      cookies: cookieStr,
    ));
    try {
      final info = await nav();
      await _dio.account.saveSession(AccountSession(
        mid: info.mid,
        uname: info.uname,
        face: info.face,
        cookies: cookieStr,
      ));
    } catch (_) {
      // nav 失败保留已存 session
    }
    // ignore: unused_local_variable
    final _ = prevCookie;
  }

  /// 直接通过 Cookie 串登录（手动粘贴）。
  Future<NavInfo> loginByCookie(String cookieStr) async {
    await _dio.account.saveSession(AccountSession(
      mid: 0,
      uname: '',
      face: '',
      cookies: cookieStr,
    ));
    final info = await nav();
    await _dio.account.saveSession(AccountSession(
      mid: info.mid,
      uname: info.uname,
      face: info.face,
      cookies: cookieStr,
    ));
    return info;
  }

  Future<void> logout() async {
    try {
      await _dio.postForm(Endpoints.logout, data: {
        'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (_) {}
    await _dio.account.clear();
  }

  /// 密码加密用的 hash 盐。
  Future<({String hash, String key})> webKey() async {
    final resp = await _dio.get(Endpoints.webKey);
    final data = resp.data as Map<String, dynamic>;
    return (
      hash: data['hash'] as String,
      key: data['key'] as String,
    );
  }

  /// web 端密码登录。
  Future<void> webPwdLogin({
    required String username,
    required String password,
    String? captcha,
    String? checkKey,
  }) async {
    final k = await webKey();
    // 先把 password 做 md5，再拼接 hash，再做 RSA-like 加密（简化：md5(md5(pwd)+hash)）
    final pwdMd5 = md5.convert(utf8.encode(password)).toString();
    final hashPwd = md5.convert(utf8.encode('$pwdMd5${k.hash}')).toString();
    final resp = await _dio.postForm(Endpoints.webLogin, data: {
      'username': username,
      'password': hashPwd,
      'keep': 0,
      'goback': 'https://www.bilibili.com/',
      'gaptcha': ?captcha,
      'checkKey': ?checkKey,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'deviceFingerprint': Random().nextInt(1 << 32).toRadixString(16),
    });
    // 成功后从 set-cookie 注入
    final raw = resp.data;
    if (raw is Map && raw['status'] == true) {
      // 简化处理：依赖 dio cookie jar
    }
  }
}
