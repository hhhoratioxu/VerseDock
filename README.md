# VerseDock

原创 Swift 原生 Spotify 歌词伴侣。macOS：菜单栏歌词、可拖动的悬浮歌词、完整歌词窗口。iPhone：完整歌词、灵动岛、锁屏实时活动。iPad：完整歌词、锁屏实时活动；iPad 没有灵动岛硬件。

这是独立伴侣 App，通过公开接口接入 Spotify。工程不修改 Spotify 安装目录，不注入其进程，也不依赖现成歌词插件。

## 立即运行 Mac 版

GitHub 仓库：[hhhoratioxu/VerseDock](https://github.com/hhhoratioxu/VerseDock)。打包的 Mac App 在 [Releases](https://github.com/hhhoratioxu/VerseDock/releases) 中提供；源码、Xcode 工程和安装说明直接保存在仓库内。

下载 `VerseDock-macOS-arm64.zip` 并解压，双击 `VerseDock.app`。本地自行构建的产物位于 `build/VerseDock.app`，也可以在项目目录执行：

```sh
open build/VerseDock.app
```

打开 Spotify 桌面客户端并播放歌曲。在 VerseDock 的设置里开启 LRCLIB 在线歌词，或者导入当前歌曲的 UTF-8 `.lrc` 文件。系统询问读取 Spotify 的自动化权限时，允许即可。菜单栏入口会一直保留，关闭主窗口后仍可使用悬浮窗。

Mac 本地读取无需 Spotify Client ID。当前包为 arm64、最低 macOS 14、临时本地签名；其他 Mac、Intel、开发者签名、公证尚未验收。

## 已实现

| 功能 | macOS | iPhone / iPad |
|---|---|---|
| Spotify 当前歌曲、进度、暂停、切歌 | 本地 AppleScript | 官方 Web API + PKCE |
| 同步 LRC、完整歌词、自动跟随 | 有 | 有 |
| 同时间戳双语行、重复时间戳 | 有 | 有 |
| 每首歌校准 ±10 秒 | 有 | 有 |
| 本地文件导入、缓存清除 | 有 | 有 |
| 在线歌词 | LRCLIB，用户开启 | LRCLIB，用户开启 |
| 状态栏当前歌词 | 有 | 不适用 |
| 可拖动、跨桌面的悬浮窗 | 有 | 不适用 |
| 灵动岛 / 锁屏实时活动 | 向推送桥发送数据 | ActivityKit + WidgetKit |
| 后台更新桥 | Mac 作为来源 | 注册 APNs 实时活动令牌 |

在线歌词使用严格的歌名、歌手、专辑和时长查询，不会自动拿不同版本的歌词代替。第三方库不保证收录每首歌；未匹配会明确提示，可使用本地 LRC。纯文本歌词没有同步时间轴，也不会伪造高亮进度。

## iPhone/iPad 构建与灵动岛

已经提供 [iPhone/iPad 待签名 IPA](https://github.com/hhhoratioxu/VerseDock/releases/tag/v0.1.0-unsigned-ipa)。下载 `VerseDock-iOS-unsigned.ipa`，使用自己的 Apple 签名身份重新签名安装。包内保留灵动岛/锁屏扩展，最低 iOS/iPadOS 17；本次已完成标准 Xcode 设备构建，但尚未签名或真机验收。详细说明见 [docs/IPA.zh-CN.md](docs/IPA.zh-CN.md)。

打开 `VerseDock.xcodeproj`，选择 `VerseDock` scheme。选择你的 Apple 开发者 Team 和设备。部署目标 iOS/iPadOS 17；灵动岛要求具备相应硬件的 iPhone。开启 App 中的实时活动按钮后，系统管理灵动岛和锁屏显示。

前台可以更新歌词；App 进入后台后，普通计时器不再可靠运行。因此工程提供 `relay/` 后台推送桥：

```text
Mac Spotify → VerseDock Mac → 你的 HTTPS 推送桥 → Apple APNs → iPhone/iPad 实时活动
```

此路径要求 Mac 保持运行，并以 Mac 当前歌曲为歌词来源。不配置推送桥时，后台保留最近一条歌词，过期后标记等待更新。推送桥每次至少间隔 5 秒，使用 APNs 低优先级，过期时间 30 秒；Apple 的调度、网络和用户设置会影响到达时间，不能保证每句准时更新。App 不播放静音音频、不滥用后台音频模式。

完整配置、回调部署、签名和推送服务说明见 [docs/SETUP.zh-CN.md](docs/SETUP.zh-CN.md)。

## 原创与依赖说明

本项目的歌词解析、同步算法、两端 UI、Spotify 接入、PKCE 流程、推送桥、回调页、工程生成脚本与测试均为本次从零编写。未复制、改名包装或下载任何开源 Spotify 歌词插件、Spicetify 扩展或相似项目源码。接口行为依据 Spotify、Apple 与 LRCLIB 的文档/公开服务协议实现。

Apple App 没有第三方包依赖，使用 SwiftUI、AppKit、Foundation、CryptoKit、Security、AuthenticationServices、ActivityKit、WidgetKit。可选推送服务使用通用 `httpx`（HTTP/2）和 `cryptography`（ES256）依赖；这些是网络/密码库，不是歌词插件。它们保留各自的许可证，未声称这些库由本项目原创。Spotify 与歌词内容的权利也不属于本项目。

本地数据：歌词缓存在 Application Support；Spotify 令牌与配对密钥存 Keychain；APNs 私钥只保留在你配置的服务端。不使用 Spotify Cookie、内部歌词接口、Spotify 密码或 Client Secret。只有开启在线歌词或推送桥后才向对应服务发送所需数据。

## 构建、检查与测试

```sh
# 本机可直接构建 Mac App
zsh scripts/build-mac.sh

# 检查 iOS 主 App 和实时活动扩展的源码类型
zsh scripts/check-ios.sh

# 完整构建 iPhone/iPad 设备版本，打包待签名 IPA
zsh scripts/build-ios-unsigned.sh

# 运行原创核心的 XCTest 测试
zsh scripts/test-core.sh

# 重新生成确定性的 Xcode 工程
python3 scripts/generate-project.py

# 可选推送桥测试（先按照 SETUP 安装它的依赖）
cd relay
.venv/bin/python -m unittest -v test_server.py
```

2026-10-13 的首次交付完成了 Mac 构建和 iOS 类型检查，当时标准 Xcode 构建受环境限制。2026-10-15 重新检查后，Xcode 许可检查通过，iOS 主 App 与实时活动扩展已使用标准 `xcodebuild` 完整编译，并打包为待签名 IPA。本机没有可用的 Apple 签名证书，尚未安装到 iPhone/iPad，也未验证真机灵动岛和 APNs 送达。

详见 [docs/VERIFICATION.zh-CN.md](docs/VERIFICATION.zh-CN.md)，其中明确记录当前证据与未完成的真机验收。
