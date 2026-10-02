# BiliFlex Windows 桌面版构建指南

本文档说明如何将 BiliFlex Flutter 工程编译为 Windows `.exe` 可执行程序。

> ⚠️ **重要**：Flutter 官方不支持在 Linux/macOS 上交叉编译 Windows exe。
> 必须在 **Windows 10/11 主机**上执行以下步骤。本仓库已包含完整的
> `windows/` Runner 工程（CMake + C++），无需手动创建。

---

## 方案一：GitHub Actions 云端编译（推荐，本地无需装任何东西）

本仓库已内置 `.github/workflows/build-windows.yml`，推送到 GitHub 后自动在
云端 Windows 机器上编译，你直接下载 exe 即可。

### 步骤

1. **注册 GitHub 账号**（已有可跳过）：https://github.com
2. **创建新仓库**：https://github.com/new ，例如命名为 `biliflex`
3. **推送代码**（在工程根目录执行）：

   ```bash
   git init
   git add .
   git commit -m "init: BiliFlex"
   git branch -M main
   git remote add origin https://github.com/你的用户名/biliflex.git
   git push -u origin main
   ```

4. **查看编译进度**：打开仓库页面 → 顶部 **Actions** 标签 → 点击最新的
   "Build Windows Release" 工作流，等待约 5-10 分钟。
5. **下载 exe**：编译成功后，在工作流页面底部 **Artifacts** 区域点击
   `BiliFlex-Windows-x64` 下载压缩包，解压后双击 `biliflex.exe` 运行。

### 打 tag 自动发 Release

```bash
git tag v0.1.0
git push origin v0.1.0
```

推送 tag 后，Action 会自动创建 GitHub Release 并附带 exe 压缩包。

---

## 方案二：本地 Windows 编译（需要 Flutter SDK + Visual Studio）

如果你有 Windows 电脑并希望本地编译，按以下步骤操作。

---

## 一、环境准备

### 1. 安装 Flutter SDK（Windows）

1. 下载 Flutter stable：https://docs.flutter.dev/get-started/install/windows
2. 解压到 `C:\src\flutter`（路径不要含中文或空格）
3. 将 `C:\src\flutter\bin` 加入系统环境变量 `PATH`
4. 打开 PowerShell 验证：
   ```powershell
   flutter --version
   flutter doctor
   ```

### 2. 安装 Visual Studio 2022（必须）

Flutter Windows 构建依赖 Visual Studio 的 C++ 工具链。

1. 下载 Visual Studio 2022 Community（免费）：
   https://visualstudio.microsoft.com/zh-hans/downloads/
2. 安装时勾选 **"使用 C++ 的桌面开发"**（Desktop development with C++）
3. 确保勾选了 **Windows 10/11 SDK** 和 **MSVC v143 生成工具**
4. 安装完成后重启

### 3. 验证环境

```powershell
flutter doctor
```

输出中 `[√] Visual Studio - develop Windows apps (Visual Studio Community 2022)`
必须为对勾。

---

## 二、获取源码

将本工程复制到 Windows 电脑，例如 `D:\projects\biliflex\`。

> 如果你是从压缩包解压，确保解压后目录结构完整，包含 `lib/`、`windows/`、
> `pubspec.yaml` 等文件。

---

## 三、构建 Release 版 exe

### 方式 A：一键脚本（推荐）

工程根目录已提供 `build_windows.bat`，**双击即可**自动完成依赖拉取、
静态分析、编译，并在完成后自动打开输出目录。

### 方式 B：手动命令

在工程根目录打开 PowerShell：

```powershell
cd D:\projects\biliflex

# 1. 拉取依赖（国内用户建议先设置镜像）
$env:PUB_HOSTED_URL="https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
flutter pub get

# 2. 构建 Release 版（x64）
flutter build windows --release
```

构建成功后，可执行文件位于：

```
build\windows\x64\runner\Release\
├── biliflex.exe          ← 主程序
├── flutter_windows.dll
├── data\
│   ├── flutter_assets\    ← 应用资源（图片、字体、编译后的 Dart 代码）
│   └── icudtl.dat
└── ...（其他依赖 dll）
```

**整个 `Release` 文件夹就是绿色版程序**，可以直接复制到其他 Windows 电脑运行，
无需安装。双击 `biliflex.exe` 即可启动。

---

## 四、构建 Debug 版（开发调试用）

```powershell
flutter build windows --debug
# 输出：build\windows\x64\runner\Debug\
```

或直接运行（带热重载）：

```powershell
flutter run -d windows
```

---

## 五、打包成安装包（可选）

绿色版已经可以分发，但如果你希望做成标准的 `.exe` 安装程序或 `.msix`，
有以下两种常见方案：

### 方案 A：Inno Setup（经典安装包）

1. 下载 Inno Setup：https://jrsoftware.org/isinfo.php
2. 新建 `.iss` 脚本，将 `build\windows\x64\runner\Release\` 整个目录打包
3. 编译生成 `BiliFlex-Setup.exe`

最小脚本示例：

```iss
[Setup]
AppName=BiliFlex
AppVersion=0.1.0
DefaultDirName={autopf}\BiliFlex
DefaultGroupName=BiliFlex
OutputDir=output
OutputBaseFilename=BiliFlex-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\BiliFlex"; Filename: "{app}\biliflex.exe"
Name: "{commondesktop}\BiliFlex"; Filename: "{app}\biliflex.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标:"
```

### 方案 B：MSIX（微软商店格式）

```powershell
flutter pub global activate msix
flutter pub run msix:create
```

输出 `build\windows\x64\runner\Release\biliflex.msix`。

---

## 六、常见问题

### Q1：`flutter build windows` 报错 "Unable to find suitable Visual Studio toolchain"

**原因**：没装 Visual Studio，或没勾选 C++ 工作负载。
**解决**：打开 Visual Studio Installer → 修改 → 勾选"使用 C++ 的桌面开发"→ 安装。

### Q2：构建成功但双击 exe 闪退 / 缺少 dll

**原因**：只复制了 `biliflex.exe` 单个文件，没带 `data/` 目录和依赖 dll。
**解决**：必须复制**整个 `Release` 文件夹**，不能只拷 exe。

### Q3：程序启动后白屏 / 网络请求失败

**原因**：B 站接口需要正确的 UA 和 Referer，本工程已内置。如果仍失败，
可能是网络环境（代理 / 防火墙）拦截。
**解决**：检查系统代理设置，或在代码 `lib/core/network/bili_dio.dart` 中
调整 Dio 配置。

### Q4：如何修改应用图标？

替换 `windows\runner\resources\app_icon.ico` 为你自己的 `.ico` 文件
（建议包含 16/32/48/256 多种尺寸），然后重新构建。

### Q5：如何修改版本号？

编辑 `pubspec.yaml` 中的 `version: 0.1.0+1`，然后重新构建。
Windows exe 的文件版本会自动同步。

---

## 七、构建产物验证清单

- [ ] `build\windows\x64\runner\Release\biliflex.exe` 存在
- [ ] 同目录下有 `flutter_windows.dll`
- [ ] `data\flutter_assets\` 目录非空
- [ ] 双击 exe 能正常启动，显示启动页
- [ ] 首页推荐 / 热门能加载数据
- [ ] 视频详情页能打开
- [ ] 搜索功能正常
- [ ] 登录页二维码能生成

---

## 八、技术说明

- **构建系统**：CMake（由 Flutter 自动管理，无需手动调用 cmake）
- **渲染引擎**：Flutter Windows 引擎（ANGLE → DirectX 11）
- **架构**：默认 x64（Flutter 3.x 不再支持 x86 Windows 桌面）
- **运行时依赖**：Windows 10 1809+ / Windows 11，Visual C++ Redistributable
  （通常系统已自带，若缺失会提示安装）

---

如有构建问题，先运行 `flutter doctor -v` 查看完整诊断信息。
