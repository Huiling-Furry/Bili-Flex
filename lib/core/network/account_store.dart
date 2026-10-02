import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// 登录态：当前登录用户的 Cookie 与基本信息。
class AccountSession {
  final int mid;
  final String uname;
  final String face;
  final String cookies; // 完整 Cookie 串

  const AccountSession({
    required this.mid,
    required this.uname,
    required this.face,
    required this.cookies,
  });

  bool get isLoggedIn => mid > 0;

  Map<String, dynamic> toJson() => {
        'mid': mid,
        'uname': uname,
        'face': face,
        'cookies': cookies,
      };

  factory AccountSession.fromJson(Map<String, dynamic> j) => AccountSession(
        mid: (j['mid'] ?? 0) as int,
        uname: (j['uname'] ?? '') as String,
        face: (j['face'] ?? '') as String,
        cookies: (j['cookies'] ?? '') as String,
      );

  static const empty = AccountSession(
    mid: 0,
    uname: '',
    face: '',
    cookies: '',
  );
}

/// 账号存储：用 SharedPreferences 持久化当前登录态。
///
/// 多账号预留接口（list 字段），首版只启用单账号。
class AccountStore {
  static const _kSession = 'biliflex.session.v1';
  static const _kAccessKey = 'biliflex.access_key.v1';

  SharedPreferences? _prefs;
  AccountSession _session = AccountSession.empty;
  String? _accessKey;

  AccountSession get session => _session;
  String? get accessKey => _accessKey;
  bool get isLoggedIn => _session.isLoggedIn;

  /// 把 Cookie 串解析成键值表（忽略属性部分）。
  static Map<String, String> parseCookies(String raw) {
    final map = <String, String>{};
    for (final part in raw.split(';')) {
      final seg = part.trim();
      if (seg.isEmpty) continue;
      final idx = seg.indexOf('=');
      if (idx <= 0) continue;
      map[seg.substring(0, idx).trim()] = seg.substring(idx + 1).trim();
    }
    return map;
  }

  /// 取单个 Cookie 值，例如 SESSDATA / bili_jct。
  String? cookieValue(String name) =>
      parseCookies(_session.cookies)[name];

  /// CSRF token（即 bili_jct），写操作接口都需要带上。
  String get csrf => cookieValue('bili_jct') ?? '';

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_kSession);
    if (raw != null && raw.isNotEmpty) {
      try {
        _session = AccountSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    _accessKey = _prefs!.getString(_kAccessKey);
  }

  Future<void> saveSession(AccountSession s) async {
    _session = s;
    await _prefs?.setString(_kSession, jsonEncode(s.toJson()));
  }

  Future<void> saveAccessKey(String? key) async {
    _accessKey = key;
    if (key == null) {
      await _prefs?.remove(_kAccessKey);
    } else {
      await _prefs?.setString(_kAccessKey, key);
    }
  }

  Future<void> clear() async {
    _session = AccountSession.empty;
    _accessKey = null;
    await _prefs?.remove(_kSession);
    await _prefs?.remove(_kAccessKey);
  }
}
