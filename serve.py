#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""BiliFlex 本地代理服务器（仅用 Python 标准库，无需安装依赖）

作用：
  1. 静态托管当前目录（biliweb.html 等），保持和页面同源；
  2. /__api?url=...    代理 B 站接口：自动补 Referer / User-Agent，透传 Cookie，返回 JSON；
  3. /__media?url=...  代理视频流：自动补 Referer，支持 Range（可拖动进度条）；
  4. /__ping           健康检查，页面用它判断代理是否可用。

为什么必须要有它：
  B 站视频 CDN（*.bilivideo.com）强制校验 Referer 必须是 https://www.bilibili.com，
  否则返回 403；而浏览器的 JS 无法伪造 Referer（<video> 只会带自身页面地址），
  公共 CORS 代理也不会替你补 Referer。所以真实播放必须经过这个本地代理。

用法：  python3 serve.py        （默认端口 8765，可用 PORT 环境变量修改）
"""

import base64
import http.server
import json
import os
import socketserver
import sys
import urllib.error
import urllib.parse
import urllib.request

PORT = int(os.environ.get("PORT", "8765"))
ROOT = os.path.dirname(os.path.abspath(__file__))
UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
REFERER = "https://www.bilibili.com"
TIMEOUT = 30
CHUNK = 64 * 1024


class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def __init__(self, *a, **kw):
        super().__init__(*a, directory=ROOT, **kw)

    # 静音默认日志（只保留错误）
    def log_message(self, fmt, *args):
        sys.stderr.write("[serve] " + (fmt % args) + "\n")

    # ---------- 通用响应 ----------
    def _send(self, code, body=b"", ctype="text/plain; charset=utf-8", head=False):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        if body and not head:
            self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.end_headers()

    def do_HEAD(self):
        self._route(head=True)

    def do_GET(self):
        self._route()

    def do_POST(self):
        self._route(post=True)

    # ---------- 路由 ----------
    def _route(self, head=False, post=False):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        if path == "/__ping":
            return self._send(200, b"biliflex-proxy-ok", head=head)
        if path in ("/__api", "/__media"):
            qs = urllib.parse.parse_qs(parsed.query)
            target = self._decode_target((qs.get("url") or [""])[0])
            if not target:
                return self._send(
                    400, json.dumps({"code": -1, "message": "missing url"}).encode(),
                    "application/json", head,
                )
            return self._relay(target, is_media=(path == "/__media"), head=head, post=post)
        # 静态文件
        if head:
            return super().do_HEAD()
        if post:
            return self._send(405, b"method not allowed", head=head)
        return super().do_GET()

    # ---------- 目标地址解码 ----------
    @staticmethod
    def _decode_target(raw):
        """页面传来的目标地址。

        页面用 base64url 编码（只含 [A-Za-z0-9-_]，不含 & ? = %），
        这样即使中间网关把 %26 还原成 &，也不会截断 url 参数。
        这里同时兼容直接传明文 URL 的旧写法。
        """
        if not raw:
            return ""
        if raw.startswith("http://") or raw.startswith("https://"):
            return raw
        pad = "=" * (-len(raw) % 4)
        try:
            return base64.urlsafe_b64decode(raw + pad).decode("utf-8")
        except Exception:
            return raw

    # ---------- 代理转发 ----------
    def _relay(self, target, is_media, head=False, post=False):
        headers = {"Referer": REFERER, "User-Agent": UA, "Origin": REFERER}
        cookie = self.headers.get("X-Bili-Cookie")
        if cookie:
            headers["Cookie"] = cookie
        rng = self.headers.get("Range")
        if rng:
            headers["Range"] = rng

        data = None
        if post:
            n = int(self.headers.get("Content-Length") or 0)
            data = self.rfile.read(n) if n else b""
            ctype = self.headers.get("Content-Type")
            if ctype:
                headers["Content-Type"] = ctype

        if os.environ.get("BILIFLEX_DEBUG"):
            sys.stderr.write("[dbg] target=%s out=%s\n" % (target, headers))

        req = urllib.request.Request(
            target, data=data, headers=headers, method="POST" if post else "GET"
        )
        try:
            resp = urllib.request.urlopen(req, timeout=TIMEOUT)
        except urllib.error.HTTPError as e:
            resp = e
        except Exception as e:  # 网络错误
            return self._send(
                502, json.dumps({"code": -1, "message": str(e)}).encode(),
                "application/json", head,
            )

        status = getattr(resp, "status", 200)
        self.send_response(status)
        for h in ("Content-Type", "Content-Length", "Content-Range", "Accept-Ranges"):
            v = resp.headers.get(h)
            if v:
                self.send_header(h, v)
        if is_media:
            self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        # 没有 Content-Length 的流：关掉 keep-alive，靠连接关闭结束响应
        if not resp.headers.get("Content-Length"):
            self.send_header("Connection", "close")
            self.close_connection = True
        self.end_headers()

        if head:
            return
        try:
            while True:
                chunk = resp.read(CHUNK)
                if not chunk:
                    break
                self.wfile.write(chunk)
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            try:
                resp.close()
            except Exception:
                pass


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    if not os.path.exists(os.path.join(ROOT, "biliweb.html")):
        print("[serve] 警告：当前目录下没有 biliweb.html")
    httpd = ThreadingServer(("0.0.0.0", PORT), Handler)
    print("[serve] BiliFlex 已启动： http://localhost:%d/biliweb.html" % PORT)
    print("[serve] 代理端点： /__api?url=...   /__media?url=...   /__ping")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[serve] 已停止")


if __name__ == "__main__":
    main()
