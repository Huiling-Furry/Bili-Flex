import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/bili_dio.dart';

/// 启动页：初始化 Dio、拉 nav，决定跳登录还是主页。
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await BiliDio.instance.init();
    // 拉一次 nav 刷新 WBI 密钥（即使未登录也会返回默认密钥）
    try {
      await BiliDio.instance.raw.get('/x/web-interface/nav');
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        BiliDio.instance.account.isLoggedIn ? '/home' : '/login',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 48),
            ),
            const SizedBox(height: 16),
            const Text('BiliFlex',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
