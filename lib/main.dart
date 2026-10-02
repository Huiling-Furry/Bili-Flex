import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'app/theme.dart';
import 'features/splash/splash_page.dart';
import 'features/login/login_page.dart';
import 'features/shell/shell_page.dart';
import 'features/video/video_detail_page.dart';
import 'features/space/space_page.dart';
import 'features/library/fav_page.dart';
import 'features/library/history_page.dart';
import 'features/library/watch_later_page.dart';
import 'features/message/session_list_page.dart';
import 'features/message/chat_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化 media_kit（libmpv）运行时。
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: BiliFlexApp()));
}

class BiliFlexApp extends StatelessWidget {
  const BiliFlexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiliFlex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routes: {
        '/': (_) => const SplashPage(),
        '/login': (_) => const LoginPage(),
        '/home': (_) => const ShellPage(),
        '/fav': (_) => const FavPage(),
        '/history': (_) => const HistoryPage(),
        '/watchlater': (_) => const WatchLaterPage(),
        '/message': (_) => const SessionListPage(),
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/video':
            final args = settings.arguments;
            if (args is VideoRouteArgs) {
              return MaterialPageRoute(
                builder: (_) => VideoDetailPage(
                  bvid: args.bvid,
                  aid: args.aid,
                  initialCid: args.cid,
                ),
              );
            }
            if (args is String && args.isNotEmpty) {
              return MaterialPageRoute(
                builder: (_) => VideoDetailPage(bvid: args),
              );
            }
            return null;
          case '/space':
            final mid = settings.arguments is int
                ? settings.arguments as int
                : 0;
            if (mid > 0) {
              return MaterialPageRoute(
                builder: (_) => SpacePage(mid: mid),
              );
            }
            return null;
          case '/chat':
            final args = settings.arguments;
            if (args is ChatArgs) {
              return MaterialPageRoute(
                builder: (_) => ChatPage(
                  talkerId: args.talkerId,
                  name: args.name,
                  face: args.face,
                ),
              );
            }
            return null;
        }
        return null;
      },
    );
  }
}