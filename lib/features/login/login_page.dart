import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/repositories/account_repo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _repo = AccountRepo();
  String? _qrUrl;
  String? _authCode;
  Timer? _pollTimer;
  String _status = '生成二维码中…';
  bool _loading = false;
  final _cookieCtrl = TextEditingController();
  bool _showCookie = false;

  @override
  void initState() {
    super.initState();
    _genQrcode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cookieCtrl.dispose();
    super.dispose();
  }

  Future<void> _genQrcode() async {
    setState(() => _loading = true);
    try {
      final qr = await _repo.generateQrcode();
      _authCode = qr.authCode;
      setState(() {
        _qrUrl = qr.url;
        _status = '请用 B 站 App 扫码';
      });
      _startPoll();
    } catch (e) {
      setState(() => _status = '生成失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_authCode == null) return;
    try {
      final r = await _repo.pollQrcode(_authCode!);
      if (!mounted) return;
      switch (r.code) {
        case 0:
          // 登录成功：本次轮询响应即携带 Set-Cookie，直接复用。
          _pollTimer?.cancel();
          await _repo.afterQrcodeLogin(r.setCookie);
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/home');
          }
          break;
        case 86038:
          _pollTimer?.cancel();
          setState(() {
            _status = '二维码已过期，点击刷新';
            _qrUrl = null;
          });
          break;
        case 86039:
          setState(() => _status = '已扫码，请在手机上确认');
          break;
        default:
          setState(() =>
              _status = r.message.isEmpty ? '等待扫码…' : r.message);
      }
    } catch (_) {}
  }

  Future<void> _loginByCookie() async {
    final c = _cookieCtrl.text.trim();
    if (c.isEmpty) return;
    setState(() => _loading = true);
    try {
      await _repo.loginByCookie(c);
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cookie 登录失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('登录 BiliFlex')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '扫码登录',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: _qrUrl == null
                  ? SizedBox(
                      width: 220,
                      height: 220,
                      child: Center(
                        child: TextButton(
                          onPressed: _loading ? null : _genQrcode,
                          child: Text(_status),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(data: _qrUrl!, size: 200),
                        ),
                        const SizedBox(height: 12),
                        Text(_status, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
            ),
            const SizedBox(height: 32),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('或', style: TextStyle(color: Colors.grey.shade500)),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('使用 Cookie 登录'),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _showCookie = !_showCookie),
                  child: Text(_showCookie ? '收起' : '展开'),
                ),
              ],
            ),
            if (_showCookie) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _cookieCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '粘贴从浏览器复制的 Cookie 串（含 SESSDATA 等）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _loginByCookie,
                child: const Text('登录'),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              '提示：BiliFlex 仅用于学习研究，不提供任何破解/抓包能力。'
              '登录态仅保存在本地。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
