/// B 站各业务线基础域名。
///
/// 参考 https://github.com/SocialSisterYi/bilibili-API-collect 的域名划分，
/// 这里按 BiliFlex 自己的分层整理。
class BiliHosts {
  static const String www = 'https://www.bilibili.com';
  static const String api = 'https://api.bilibili.com';
  static const String app = 'https://app.bilibili.com';
  static const String live = 'https://api.live.bilibili.com';
  static const String passport = 'https://passport.bilibili.com';
  static const String vc = 'https://api.vc.bilibili.com';
  static const String search = 'https://s.search.bilibili.com';
  static const String message = 'https://message.bilibili.com';
  static const String space = 'https://space.bilibili.com';
  static const String account = 'https://account.bilibili.com';
  static const String mall = 'https://mall.bilibili.com';
}

/// 应用自身常量。
class AppConst {
  static const String appName = 'BiliFlex';
  static const String appVersion = '0.1.0';
  // 业务上报用的设备 UA（web 端）
  static const String webUa =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
}
