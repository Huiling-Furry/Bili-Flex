# BiliFlex

独立架构的 B 站 Flutter 第三方客户端，参考 [bilibili-API-collect](https://github.com/pskdje/bilibili-API-collect) 的接口规范实现。

## 技术栈

| 层 | 选型 |
|---|---|
| 状态管理 | flutter_riverpod 2.6 |
| 路由 | 命名路由 + onGenerateRoute（保持轻量） |
| 网络 | dio 5.x（单例 + 拦截器 + WBI 签名） |
| 图片 | cached_network_image |
| 二维码 | qr_flutter |
| 加密 | crypto（WBI md5 签名） |
| 本地存储 | shared_preferences（Cookie/Session 持久化） |

## 目录结构

```
lib/
├── main.dart                     # 入口 + 路由表
├── app/theme.dart                # 自有蓝紫主题
├── core/
│   ├── constants/
│   │   ├── bili_hosts.dart       # 各业务域名
│   │   └── endpoints.dart        # 80+ 核心接口路径
│   ├── network/
│   │   ├── bili_dio.dart         # Dio 单例 + 拦截器 + get/postForm/postJson
│   │   ├── wbi_signer.dart       # WBI 签名（mixinKeyEncTab + md5，独立实现）
│   │   └── account_store.dart    # AccountSession + SharedPreferences 持久化
│   └── utils/formatters.dart     # 计数/时长/相对时间
├── data/
│   ├── models/                  # VideoItem / VideoDetail / PlayUrlItem / BiliUser
│   └── repositories/            # HomeRepo / VideoRepo / AccountRepo / SearchRepo / LiveRepo / UserRepo
├── features/
│   ├── splash/                  # 启动初始化
│   ├── login/                    # 二维码扫码登录 + Cookie 粘贴登录
│   ├── shell/                    # 底部导航主框架
│   ├── home/                     # 推荐（feedIndex）+ 热门（popular）双 Tab
│   ├── video/                    # 视频详情 + 播放流 + 相关推荐 + 点赞/投币/三连
│   ├── search/                   # 热搜 / 搜索建议 / 综合搜索
│   ├── live/                     # 直播推荐
│   └── profile/                  # 个人中心 + 退出登录
└── widgets/
    ├── net_image.dart            # 统一网络图（占位/失败兜底）
    └── video_card.dart           # 视频卡片
```

## 已实现功能

- 启动初始化（Dio + WBI 密钥刷新 + 路由跳转）
- TV 端二维码扫码登录（申请 → 轮询 → 从 Set-Cookie 提取 SESSDATA 等）
- Cookie 粘贴手动登录
- 首页推荐（App 端 feedIndex）+ 热门视频（popular）双 Tab、下拉刷新、上拉分页
- 视频详情（/x/web-interface/view）
- 播放流（DASH）解析（/x/player/wbi/playurl）
- 相关推荐列表
- 点赞 / 投币 / 一键三连
- 搜索：热搜榜、搜索建议（前缀提示）、综合视频搜索
- 直播推荐列表
- 个人中心（nav 信息、硬币数）+ 退出登录
- WBI 签名自动注入（mixinkey 重排 + md5）
- 登录态持久化（SESSDATA/bili_jct/DedeUserID 等自动注入 Cookie 头）


## 编译验证

```
$ flutter analyze
23 issues found.（全部为 info 级 lint，无 error / warning）

$ flutter build web
✓ Built build/web   （编译成功）
```

## 待扩展（接口常量已预留）

- 弹幕列表 / 发送
- 评论区
- 动态时间线
- 收藏夹 / 历史记录 / 稍后再看
- 用户空间完整页（动态/投稿/收藏）
- 番剧 / 课程
- 真实播放器（接入 media_kit / video_player）
- 多 P 切换
- 私信 / 消息

## 免责声明

本项目仅供学习 Flutter 与 B 站开放接口研究之用，不提供任何破解、抓包、绕过风控的能力。
登录态仅保存在用户本地。请勿用于商业用途或批量爬取。
