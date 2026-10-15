# VerseDock

<img src="Artwork/VerseDock-Icon-1024.png" alt="VerseDock 图标" width="128">

原创 Swift 原生 Spotify 歌词伴侣。macOS：菜单栏歌词、可拖动的悬浮歌词、完整歌词窗口。iPhone：完整歌词、灵动岛、锁屏实时活动。iPad：完整歌词、锁屏实时活动；iPad 没有灵动岛硬件。

这是独立伴侣 App，通过公开接口接入 Spotify。工程不修改 Spotify 安装目录，不注入其进程，也不依赖现成歌词插件。

## 立即运行 Mac 版

GitHub 仓库：[hhhoratioxu/VerseDock](https://github.com/hhhoratioxu/VerseDock)。打包的 Mac App 在 [Releases](https://github.com/hhhoratioxu/VerseDock/releases) 中提供；源码、Xcode 工程和安装说明直接保存在仓库内。

当前版本为 [v0.1.2-lyrics](https://github.com/hhhoratioxu/VerseDock/releases/tag/v0.1.2-lyrics)：可选歌词提供商、自动换源、可拖动悬浮窗、可调宽度状态栏与可选双语翻译。原创 V 图标与素材说明仍在 [Artwork](Artwork/README.md)。

下载 `VerseDock-macOS-arm64.zip` 并解压，双击 `VerseDock.app`。本地自行构建的产物位于 `build/VerseDock.app`，也可以在项目目录执行：

```sh
open build/VerseDock.app
```

打开 Spotify 桌面客户端并播放歌曲。首次使用默认自动查找在线歌词；已明确关闭联网的旧设置会保留，也可以导入当前歌曲的 UTF-8 `.lrc` 文件。系统询问读取 Spotify 的自动化权限时，允许即可。点击「悬浮歌词」后，拖动歌词或空白处即可移动窗口，位置自动保存；顶部状态栏直接显示歌词，默认 18 个字符、静态显示；宽度与滚动开关由用户独立设置并自动保存。关闭主窗口后仍可使用菜单栏和悬浮窗。

Mac 本地读取无需 Spotify Client ID。当前包为 arm64、最低 macOS 14、临时本地签名；其他 Mac、Intel、开发者签名、公证尚未验收。

## 已实现

| 功能 | macOS | iPhone / iPad |
|---|---|---|
| Spotify 当前歌曲、进度、暂停、切歌 | 本地 AppleScript | 官方 Web API + PKCE |
| 同步 LRC、完整歌词、自动跟随 | 有 | 有 |
| 同时间戳双语行、重复时间戳 | 有 | 有 |
| 每首歌校准 ±10 秒 | 有 | 有 |
| 本地文件导入、缓存清除 | 有 | 有 |
| 在线歌词 | 默认自动：LRCLIB → QQ 音乐 → 网易云音乐 → lyrics.ovh；可指定来源 | 同左 |
| 状态栏当前歌词 | 默认静态，可加宽或开启长句循环滚动 | 不适用 |
| 可选歌词翻译 | 原词上、译文下；macOS 15+ | iOS/iPadOS 18+，实时活动也包含可选译文 |
| 可拖动、跨桌面的悬浮窗 | 歌词/空白处均可拖动，位置保存 | 不适用 |
| 灵动岛 / 锁屏实时活动 | 向推送桥发送数据 | ActivityKit + WidgetKit |
| 后台更新桥 | Mac 作为来源 | 注册 APNs 实时活动令牌 |

歌词跟随 Spotify 当前歌曲，独立向外部服务查找，不需要 Spotify Cookie。LRCLIB 搜索无结果、超时、返回错误或只有纯文本时，继续尝试 QQ 音乐、网易云，再以 lyrics.ovh 的纯文本作为补充。手动指定来源后只访问该提供商，默认仍为自动方案。重试按钮跳过缓存；设置中可查看每个已尝试来源的结果。服务限流会遵守 Retry-After，不在切歌时立即重打同一来源。

匹配统一繁简体、标点和多歌手分隔符，移除曲名末尾的电影/剧集说明；歌手中英文名由 QQ 音乐歌手资料或网易云返回的别名核对。优先相同专辑和接近时长，保留 Live、Remix、伴奏等版本区别，不匹配其他歌手或明显不同长度的版本。允许的小幅时长差超过 3 秒时会显示并提供校准，自动匹配容差最多 8 秒。第三方服务仍可能缺歌或不可用；纯文本不会生成虚假时间轴。详见 [歌词来源](docs/LYRICS.zh-CN.md)。

## 歌词原词与翻译

Spotify 官方目前没有向第三方开放歌词读取 API，VerseDock 无法据此判断“Spotify 有歌词就优先使用”。当前实际读取的是上面列出的备用来源，窗口明确显示真实提供商；没有把外部歌词标成 Spotify 原词。YouTube Music 与 Apple Music 的歌词尚未接通，不提供虚假的可用选项。详见 [歌词能力与来源说明](docs/LYRICS.zh-CN.md)。

歌词翻译默认关闭，在「设置 → 歌词翻译」自行开启并选择目标语言。原词在上，机器译文在下；主窗口、可拖动悬浮窗、Mac 状态栏与实时活动均提供对应布局。状态栏高度有限，译文字号较小；收起的灵动岛只显示原词片段，展开或锁屏显示双语。翻译不改变原歌词的时间戳。

使用 Apple 系统翻译，不需要翻译服务密钥；需要 macOS 15 或 iOS/iPadOS 18 及以上。语言列表实时取自本机系统，本次 Mac 返回 21 个语言/地区选项，包括中、英、日、韩、法、德、西、葡、俄、阿拉伯、印地语等。不是每个语言组合都可互译；首次需按系统提示下载语言包，未支持或失败会明确显示，仍保留原词。识别不准确时可指定原词语言。首次开启和下载语言包时请打开歌词主窗口；关闭翻译后隐藏并清空本次译文。

后台推送译文要求 Mac 与手机均开启翻译并选择相同目标语言。iOS 更改翻译偏好会结束旧实时活动，需重新开启，使后台推送不恢复已关闭的译文。Mac 未保持运行或推送桥未配置时，后台仍只保留最近状态。本机已经验证系统实际翻译与 Mac 双语窗口，iPhone/iPad 的实际排版和 APNs 送达仍待签名后的真机检查。

## iPhone/iPad 构建与灵动岛

已经提供 [iPhone/iPad 待签名 IPA](https://github.com/hhhoratioxu/VerseDock/releases/tag/v0.1.2-lyrics)。下载 `VerseDock-iOS-unsigned.ipa`，使用自己的 Apple 签名身份重新签名安装。包内保留灵动岛/锁屏扩展，最低 iOS/iPadOS 17；本次已完成标准 Xcode 设备构建，但尚未签名或真机验收。详细说明见 [docs/IPA.zh-CN.md](docs/IPA.zh-CN.md)。

打开 `VerseDock.xcodeproj`，选择 `VerseDock` scheme。选择你的 Apple 开发者 Team 和设备。部署目标 iOS/iPadOS 17；灵动岛要求具备相应硬件的 iPhone。开启 App 中的实时活动按钮后，系统管理灵动岛和锁屏显示。

前台可以更新歌词；App 进入后台后，普通计时器不再可靠运行。因此工程提供 `relay/` 后台推送桥：

```text
Mac Spotify → VerseDock Mac → 你的 HTTPS 推送桥 → Apple APNs → iPhone/iPad 实时活动
```

此路径要求 Mac 保持运行，并以 Mac 当前歌曲为歌词来源。不配置推送桥时，后台保留最近一条歌词，过期后标记等待更新。推送桥每次至少间隔 5 秒，使用 APNs 低优先级，过期时间 30 秒；Apple 的调度、网络和用户设置会影响到达时间，不能保证每句准时更新。App 不播放静音音频、不滥用后台音频模式。

完整配置、回调部署、签名和推送服务说明见 [docs/SETUP.zh-CN.md](docs/SETUP.zh-CN.md)。

## 原创与依赖说明

本项目的歌词解析、同步算法、两端 UI、Spotify 接入、PKCE 流程、推送桥、回调页、工程生成脚本与测试均为本次从零编写。未复制、改名包装或下载任何开源 Spotify 歌词插件、Spicetify 扩展或相似项目源码。接口行为依据 Spotify、Apple 与 LRCLIB 的文档/公开服务协议实现。

Apple App 没有第三方包依赖，使用 SwiftUI、AppKit、Foundation、CryptoKit、Security、AuthenticationServices、ActivityKit、WidgetKit、Translation 与 NaturalLanguage。可选推送服务使用通用 `httpx`（HTTP/2）和 `cryptography`（ES256）依赖；这些是网络/密码库，不是歌词插件。它们保留各自的许可证，未声称这些库由本项目原创。Spotify 与歌词内容的权利也不属于本项目。

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
