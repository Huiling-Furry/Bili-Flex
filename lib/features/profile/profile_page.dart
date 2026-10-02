import 'package:flutter/material.dart';
import '../../core/network/bili_dio.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/account_repo.dart';
import '../../widgets/net_image.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _repo = AccountRepo();
  NavInfo? _nav;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!BiliDio.instance.account.isLoggedIn) {
      setState(() => _busy = false);
      return;
    }
    setState(() => _busy = true);
    try {
      final n = await _repo.nav();
      if (mounted) setState(() => _nav = n);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(String route) async {
    if (!BiliDio.instance.account.isLoggedIn) {
      _toast('请先登录');
      return;
    }
    await Navigator.of(context).pushNamed(route);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final s = BiliDio.instance.account.session;
    final loggedIn = s.isLoggedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 24),
            Center(
              child: s.face.isNotEmpty
                  ? ClipOval(
                      child: NetImage(url: s.face, width: 80, height: 80),
                    )
                  : const CircleAvatar(
                      radius: 40, child: Icon(Icons.person, size: 40)),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                loggedIn ? s.uname : '未登录',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                loggedIn
                    ? 'UID: ${s.mid}'
                    : '登录后可同步收藏 / 历史',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            if (_nav != null) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '硬币: ${Formatters.count(_nav!.coins)}'
                  '${_nav!.vipStatus == '1' ? ' · 大会员' : ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!loggedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FilledButton(
                  onPressed: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (r) => false),
                  child: const Text('去登录'),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('我的消息'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('/message'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('观看历史'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('/history'),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border),
              title: const Text('我的收藏'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('/fav'),
            ),
            ListTile(
              leading: const Icon(Icons.watch_later_outlined),
              title: const Text('稍后再看'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open('/watchlater'),
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: const Text('我的追番'),
              subtitle: const Text('番剧模块开发中', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _toast('番剧 / PGC 模块尚在开发中'),
            ),
            const Divider(height: 1),
            if (loggedIn)
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text('退出登录', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  final nav = Navigator.of(context);
                  await _repo.logout();
                  nav.pushNamedAndRemoveUntil('/login', (r) => false);
                },
              ),
            const AboutListTile(
              icon: Icon(Icons.info_outline),
              applicationName: 'BiliFlex',
              applicationVersion: '0.1.0',
              aboutBoxChildren: [
                Text('独立架构的 B 站 Flutter 客户端，仅供学习研究。'),
              ],
              child: Text('关于 BiliFlex'),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}